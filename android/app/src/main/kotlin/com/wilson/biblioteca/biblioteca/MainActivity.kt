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
            "escolherPasta" -> escolherPasta(resultado)
            "arquivoNaPasta" -> {
                val pasta = chamada.argument<String>("pasta")
                val nome = chamada.argument<String>("nome")
                emSegundoPlano(resultado) { arquivoNaPasta(pasta, nome) }
            }
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
            "temAcessoPasta" -> resultado.success(temAcesso(chamada.argument<String>("uri")))
            "nome" -> {
                val uri = chamada.argument<String>("uri")
                emSegundoPlano(resultado) { nomeVisivel(uri) }
            }

            else -> resultado.notImplemented()
        }
    }

    // -----------------------------------------------------------------------
    // Escolher o documento
    // -----------------------------------------------------------------------

    private fun escolherDocumento(resultado: MethodChannel.Result) {
        if (resultadoPendente != null) {
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

    /**
     * Escolher a PASTA inteira, em vez de um documento por vez.
     *
     * Com a arvore vinculada, biblioteca.txt, biblioteca.dat e grupos.json saem
     * de um unico "vincular" — como ja acontece no Mac e no iPhone, que
     * vinculam pasta desde sempre.
     *
     * O Android recusa RAIZES: "Meu Drive" e o armazenamento interno voltam com
     * o botao "Usar esta pasta" apagado. So subpasta serve. Medido no A57 em
     * 14/09/2026; nao e limitacao do Google Drive, que funciona normalmente.
     */
    private fun escolherPasta(resultado: MethodChannel.Result) {
        if (resultadoPendente != null) {
            resultado.error("ocupado", "Já há um seletor aberto.", null)
            return
        }
        resultadoPendente = resultado
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        startActivityForResult(intent, pedidoAbrirPasta)
    }

    @Deprecated("onActivityResult segue sendo o caminho para FlutterActivity")
    override fun onActivityResult(requisicao: Int, codigo: Int, dados: Intent?) {
        super.onActivityResult(requisicao, codigo, dados)
        if (requisicao == pedidoAbrirDocumento || requisicao == pedidoAbrirPasta) {
            tratarResultadoDocumento(codigo, dados)
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

    /**
     * Resolve um filho da pasta pelo nome visivel e devolve o content:// dele.
     *
     * O URI que sai daqui herda a permissao da ARVORE, entao `ler` e `gravar`
     * funcionam nele sem nenhuma mudanca. Devolve null quando nao ha arquivo
     * com esse nome — o chamador decide se isso e erro (biblioteca.txt) ou
     * normal (grupos.json, que so o Mac escreve).
     *
     * Roda FORA da thread principal: a consulta vai ao provedor, que pode ser
     * o Drive.
     */
    private fun arquivoNaPasta(pastaTexto: String?, nome: String?): String? {
        val pasta = pastaTexto?.let(Uri::parse)
            ?: throw ErroDoCanal("uri-invalida", "URI da pasta ausente.")
        val alvo = nome ?: throw ErroDoCanal("nome-invalido", "Nome do arquivo ausente.")
        val filhos = try {
            DocumentsContract.buildChildDocumentsUriUsingTree(
                pasta, DocumentsContract.getTreeDocumentId(pasta)
            )
        } catch (e: Exception) {
            throw ErroDoCanal("pasta-invalida", "A pasta vinculada não vale mais.")
        }
        try {
            contentResolver.query(
                filhos,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME
                ),
                null, null, null
            )?.use { c ->
                while (c.moveToNext()) {
                    if (c.getString(1) == alvo) {
                        return DocumentsContract
                            .buildDocumentUriUsingTree(pasta, c.getString(0))
                            .toString()
                    }
                }
            }
        } catch (e: SecurityException) {
            throw ErroDoCanal("sem-permissao", "O acesso à pasta foi perdido.")
        }
        return null
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

    /** Nome que o provedor mostra (ex.: "biblioteca.txt"), para exibir na tela. */
    private fun nomeVisivel(uriTexto: String?): String? {
        val bruto = uriTexto?.let(Uri::parse) ?: return null
        // Um URI de ARVORE nao responde a consulta direta: e preciso pedir o
        // documento que ela representa. Sem isto o nome da pasta vinculada sai
        // nulo e a tela fica sem rotulo.
        val uri = try {
            if (DocumentsContract.isTreeUri(bruto)) {
                DocumentsContract.buildDocumentUriUsingTree(
                    bruto, DocumentsContract.getTreeDocumentId(bruto)
                )
            } else bruto
        } catch (e: Exception) {
            bruto
        }
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        } catch (e: Exception) {
            null
        }
    }
}
