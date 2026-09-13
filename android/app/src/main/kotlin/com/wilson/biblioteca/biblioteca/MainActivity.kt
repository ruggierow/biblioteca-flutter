package com.wilson.biblioteca.biblioteca

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.util.concurrent.Executors

/**
 * Ponte para o Storage Access Framework (SAF).
 *
 * POR QUE ISTO EXISTE: o pacote `file_picker` não devolve o arquivo escolhido —
 * ele COPIA o conteúdo para o cache do app e devolve o caminho da cópia
 * (/data/user/0/<pacote>/cache/file_picker/<ts>/biblioteca.txt). Consequências:
 * o que o usuário editava nunca voltava para o arquivo original (nem para o
 * Google Drive), e o vínculo sumia sozinho quando o Android limpava o cache.
 *
 * Aqui pedimos ACTION_OPEN_DOCUMENT e guardamos a permissão com
 * takePersistableUriPermission, o que mantém o acesso ao content:// entre
 * reinícios. Leitura e gravação vão pelo ContentResolver, direto no documento
 * de verdade — o equivalente Android do security-scoped bookmark que o app do
 * iPhone já usa.
 */
class MainActivity : FlutterActivity() {

    private val canal = "biblioteca/saf"
    private val pedidoAbrirDocumento = 4711
    private val pedidoAbrirPasta = 4712
    private var resultadoPendente: MethodChannel.Result? = null
    private var resultadoPendentePasta: MethodChannel.Result? = null

    // POR QUE HA UMA THREAD AQUI: o SAF pode falar com a REDE. Num content://
    // do Google Drive, o ContentResolver precisa BAIXAR o arquivo antes de
    // devolver os bytes. O Flutter entrega as chamadas de canal na thread
    // principal, entao fazer isso aqui congela a interface e o Android mata o
    // app por ANR — sem exceção nenhuma, o que torna o defeito invisivel no log
    // e imune a try/catch do lado Dart.
    //
    // Com arquivo local nao aparece, porque a leitura e instantanea. So quebra
    // com o Drive, e so quando o arquivo ainda NAO esta no cache dele: depois
    // que entra em cache, volta a funcionar e parece que nunca houve defeito.
    // Foi exatamente o que se viu em 13/09/2026.
    private val tarefas = Executors.newSingleThreadExecutor()
    private val principal = Handler(Looper.getMainLooper())

    /** Erro que o canal devolve ao Dart, com codigo. */
    private class ErroDoCanal(val codigo: String, mensagem: String) : Exception(mensagem)

    /**
     * Roda [trabalho] fora da thread principal e responde NELA — o
     * MethodChannel.Result exige ser chamado na thread principal.
     */
    private fun emSegundoPlano(resultado: MethodChannel.Result, trabalho: () -> Any?) {
        tarefas.execute {
            try {
                val valor = trabalho()
                principal.post { resultado.success(valor) }
            } catch (e: ErroDoCanal) {
                principal.post { resultado.error(e.codigo, e.message, null) }
            } catch (e: Exception) {
                principal.post { resultado.error("erro", e.message, null) }
            }
        }
    }

    override fun onDestroy() {
        tarefas.shutdown()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal)
            .setMethodCallHandler { chamada, resultado -> tratar(chamada, resultado) }

        // Canal separado: versao nao tem nada a ver com SAF.
        //
        // O numero vem do PROPRIO pacote instalado, nao de uma constante no
        // codigo: assim ele nunca mente sobre qual APK esta rodando. Em
        // 13/09/2026 passamos meia tarde sem saber se o aparelho tinha a b4, a
        // b6 ou a b7 — e a tela nao ajudava, porque nao dizia nada.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "biblioteca/app")
            .setMethodCallHandler { chamada, resultado ->
                if (chamada.method == "versao") resultado.success(versaoDoPacote())
                else resultado.notImplemented()
            }
    }

    /** "1.9.0 (7)" — nome da versao e numero do build, como o sistema os ve. */
    private fun versaoDoPacote(): String = try {
        val info = packageManager.getPackageInfo(packageName, 0)
        val build = if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode
                    else @Suppress("DEPRECATION") info.versionCode.toLong()
        "${info.versionName} ($build)"
    } catch (e: Exception) {
        ""
    }

    private fun tratar(chamada: MethodCall, resultado: MethodChannel.Result) {
        when (chamada.method) {
            "escolherDocumento" -> escolherDocumento(resultado)
            "ler" -> {
                val uri = chamada.argument<String>("uri")
                emSegundoPlano(resultado) { ler(uri) }
            }
            "gravar" -> {
                val uri = chamada.argument<String>("uri")
                val conteudo = chamada.argument<String>("conteudo")
                emSegundoPlano(resultado) { gravar(uri, conteudo) }
            }
            // Consulta local a lista de permissoes do proprio sistema: nao toca
            // no provedor, nao vai a rede. Pode ficar na thread principal.
            "temAcesso" -> resultado.success(temAcesso(chamada.argument<String>("uri")))
            "nome" -> {
                val uri = chamada.argument<String>("uri")
                emSegundoPlano(resultado) { nomeVisivel(uri) }
            }

            // Pasta de capas (leitura de arvore de documentos)
            "escolherPasta" -> escolherPasta(resultado)
            "listarPasta" -> {
                val uri = chamada.argument<String>("uri")
                emSegundoPlano(resultado) { listarPasta(uri) }
            }
            "lerArquivoDaPasta" -> {
                val pastaUri   = chamada.argument<String>("pastaUri")
                val documentId = chamada.argument<String>("documentId")
                emSegundoPlano(resultado) { lerArquivoDaPasta(pastaUri, documentId) }
            }
            "temAcessoPasta" -> resultado.success(temAcessoPasta(chamada.argument<String>("uri")))

            else -> resultado.notImplemented()
        }
    }

    // -----------------------------------------------------------------------
    // Escolher o documento
    // -----------------------------------------------------------------------

    private fun escolherDocumento(resultado: MethodChannel.Result) {
        if (resultadoPendente != null || resultadoPendentePasta != null) {
            resultado.error("ocupado", "Já há um seletor aberto.", null)
            return
        }
        resultadoPendente = resultado
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // text/plain deixaria de fora o que o Drive marca como
            // application/octet-stream; */* garante que o biblioteca.txt apareça.
            type = "*/*"
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        startActivityForResult(intent, pedidoAbrirDocumento)
    }

    @Deprecated("onActivityResult segue sendo o caminho para FlutterActivity")
    override fun onActivityResult(requisicao: Int, codigo: Int, dados: Intent?) {
        super.onActivityResult(requisicao, codigo, dados)
        when (requisicao) {
            pedidoAbrirDocumento -> tratarResultadoDocumento(codigo, dados)
            pedidoAbrirPasta     -> tratarResultadoPasta(codigo, dados)
        }
    }

    private fun tratarResultadoDocumento(codigo: Int, dados: Intent?) {
        val resultado = resultadoPendente ?: return
        resultadoPendente = null

        val uri = dados?.data
        if (codigo != Activity.RESULT_OK || uri == null) {
            resultado.success(null) // usuário cancelou — não é erro
            return
        }
        try {
            // ESTA linha é o ponto do exercício: sem ela o acesso morre ao
            // reiniciar o app e o vínculo se perde.
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (e: SecurityException) {
            resultado.error("sem-permissao", "Não foi possível manter o acesso: ${e.message}", null)
            return
        }
        // nomeVisivel consulta o provedor, que pode ser o Drive: sai da thread
        // principal como as demais.
        val texto = uri.toString()
        tarefas.execute {
            val nome = nomeVisivel(texto)
            principal.post { resultado.success(mapOf("uri" to texto, "nome" to nome)) }
        }
    }

    // -----------------------------------------------------------------------
    // Escolher pasta de capas
    // -----------------------------------------------------------------------

    private fun escolherPasta(resultado: MethodChannel.Result) {
        if (resultadoPendente != null || resultadoPendentePasta != null) {
            resultado.error("ocupado", "Já há um seletor aberto.", null)
            return
        }
        resultadoPendentePasta = resultado
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        startActivityForResult(intent, pedidoAbrirPasta)
    }

    private fun tratarResultadoPasta(codigo: Int, dados: Intent?) {
        val resultado = resultadoPendentePasta ?: return
        resultadoPendentePasta = null

        val uri = dados?.data
        if (codigo != Activity.RESULT_OK || uri == null) {
            resultado.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (e: SecurityException) {
            resultado.error("sem-permissao", "Não foi possível manter o acesso: ${e.message}", null)
            return
        }
        // lastPathSegment do tree URI tem formato "primary:Pasta/Subpasta"
        val nome = uri.lastPathSegment?.substringAfterLast(':') ?: uri.toString()
        resultado.success(mapOf("uri" to uri.toString(), "nome" to nome))
    }

    // -----------------------------------------------------------------------
    // Ler e gravar no documento de verdade
    // -----------------------------------------------------------------------

    /** Roda FORA da thread principal — pode baixar o arquivo do Drive. */
    private fun ler(uriTexto: String?): String {
        val uri = uriTexto?.let(Uri::parse)
            ?: throw ErroDoCanal("uri-invalida", "URI ausente.")
        try {
            return contentResolver.openInputStream(uri)?.use {
                it.readBytes().toString(Charsets.UTF_8)
            } ?: throw ErroDoCanal("sem-fluxo", "Não foi possível abrir o documento.")
        } catch (e: FileNotFoundException) {
            throw ErroDoCanal("nao-encontrado", "O arquivo vinculado não existe mais.")
        } catch (e: SecurityException) {
            throw ErroDoCanal("sem-permissao", "O acesso ao arquivo foi revogado.")
        }
    }

    /** Roda FORA da thread principal — pode enviar o arquivo ao Drive. */
    private fun gravar(uriTexto: String?, conteudo: String?): Boolean {
        val uri = uriTexto?.let(Uri::parse)
            ?: throw ErroDoCanal("uri-invalida", "URI ausente.")
        if (conteudo == null) throw ErroDoCanal("uri-invalida", "Conteúdo ausente.")
        val bytes = conteudo.toByteArray(Charsets.UTF_8)

        // "wt" = write + truncate. Sem o truncar, um arquivo novo menor que o
        // anterior deixaria a cauda do conteúdo antigo no fim — defeito
        // silencioso e chato de achar.
        //
        // Nem todo provedor aceita "wt"; alguns só aceitam "rwt". Tentamos os
        // dois e, se nenhum truncar, PARAMOS: gravar em "w" puro escreveria por
        // cima deixando o rabo do arquivo antigo, que é pior que não gravar.
        for (modo in listOf("wt", "rwt")) {
            try {
                contentResolver.openOutputStream(uri, modo)?.use {
                    it.write(bytes)
                    it.flush()
                } ?: continue
                return true
            } catch (e: SecurityException) {
                throw ErroDoCanal("sem-permissao", "O acesso de escrita foi revogado.")
            } catch (e: IllegalArgumentException) {
                continue          // este provedor não conhece o modo; tenta o próximo
            } catch (e: UnsupportedOperationException) {
                continue
            }
        }
        throw ErroDoCanal(
            "sem-fluxo",
            "Este armazenamento não permite regravar o arquivo com segurança."
        )
    }

    // -----------------------------------------------------------------------
    // Listar e ler arquivos de uma pasta (sincronização de capas)
    // -----------------------------------------------------------------------

    /** Roda FORA da thread principal — pode consultar o Drive. */
    private fun listarPasta(uriTexto: String?): List<Map<String, String>> {
        val uri = uriTexto?.let(Uri::parse)
            ?: throw ErroDoCanal("uri-invalida", "URI ausente.")
        val treeDocId  = DocumentsContract.getTreeDocumentId(uri)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(uri, treeDocId)
        val arquivos = mutableListOf<Map<String, String>>()
        contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
            ),
            null, null, null
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val docId = cursor.getString(0) ?: continue
                val nome  = cursor.getString(1) ?: continue
                arquivos.add(mapOf("documentId" to docId, "nome" to nome))
            }
        }
        return arquivos
    }

    /** Roda FORA da thread principal — pode baixar o arquivo do Drive. */
    private fun lerArquivoDaPasta(pastaUri: String?, documentId: String?): ByteArray {
        if (pastaUri == null || documentId == null)
            throw ErroDoCanal("uri-invalida", "URI ou documentId ausente.")
        val uri     = Uri.parse(pastaUri)
        val fileUri = DocumentsContract.buildDocumentUriUsingTree(uri, documentId)
        try {
            return contentResolver.openInputStream(fileUri)?.use { it.readBytes() }
                ?: throw ErroDoCanal("sem-fluxo", "Não foi possível ler o arquivo.")
        } catch (e: FileNotFoundException) {
            throw ErroDoCanal("nao-encontrado", "Arquivo não encontrado na pasta.")
        } catch (e: SecurityException) {
            throw ErroDoCanal("sem-permissao", "Acesso à pasta foi revogado.")
        }
    }

    // -----------------------------------------------------------------------
    // Consultas
    // -----------------------------------------------------------------------

    /** O app ainda tem permissão persistente de leitura e escrita neste URI? */
    private fun temAcesso(uriTexto: String?): Boolean {
        val uri = uriTexto?.let(Uri::parse) ?: return false
        return contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
    }

    /** O app ainda tem permissão persistente de leitura nesta pasta? */
    private fun temAcessoPasta(uriTexto: String?): Boolean {
        val uri = uriTexto?.let(Uri::parse) ?: return false
        return contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission
        }
    }

    /** Nome que o provedor mostra (ex.: "biblioteca.txt"), para exibir na tela. */
    private fun nomeVisivel(uriTexto: String?): String? {
        val uri = uriTexto?.let(Uri::parse) ?: return null
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        } catch (e: Exception) {
            null
        }
    }
}
