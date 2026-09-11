package com.wilson.biblioteca.biblioteca

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException

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
    private var resultadoPendente: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal)
            .setMethodCallHandler { chamada, resultado -> tratar(chamada, resultado) }
    }

    private fun tratar(chamada: MethodCall, resultado: MethodChannel.Result) {
        when (chamada.method) {
            "escolherDocumento" -> escolherDocumento(resultado)
            "ler" -> ler(chamada.argument<String>("uri"), resultado)
            "gravar" -> gravar(
                chamada.argument<String>("uri"),
                chamada.argument<String>("conteudo"),
                resultado
            )
            "temAcesso" -> resultado.success(temAcesso(chamada.argument<String>("uri")))
            "nome" -> resultado.success(nomeVisivel(chamada.argument<String>("uri")))
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

    @Deprecated("onActivityResult segue sendo o caminho para FlutterActivity")
    override fun onActivityResult(requisicao: Int, codigo: Int, dados: Intent?) {
        super.onActivityResult(requisicao, codigo, dados)
        if (requisicao != pedidoAbrirDocumento) return

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
        resultado.success(mapOf("uri" to uri.toString(), "nome" to nomeVisivel(uri.toString())))
    }

    // -----------------------------------------------------------------------
    // Ler e gravar no documento de verdade
    // -----------------------------------------------------------------------

    private fun ler(uriTexto: String?, resultado: MethodChannel.Result) {
        val uri = uriTexto?.let(Uri::parse)
        if (uri == null) {
            resultado.error("uri-invalida", "URI ausente.", null); return
        }
        try {
            val texto = contentResolver.openInputStream(uri)?.use {
                it.readBytes().toString(Charsets.UTF_8)
            }
            if (texto == null) {
                resultado.error("sem-fluxo", "Não foi possível abrir o documento.", null)
            } else {
                resultado.success(texto)
            }
        } catch (e: FileNotFoundException) {
            resultado.error("nao-encontrado", "O arquivo vinculado não existe mais.", null)
        } catch (e: SecurityException) {
            resultado.error("sem-permissao", "O acesso ao arquivo foi revogado.", null)
        } catch (e: Exception) {
            resultado.error("erro-leitura", e.message, null)
        }
    }

    private fun gravar(uriTexto: String?, conteudo: String?, resultado: MethodChannel.Result) {
        val uri = uriTexto?.let(Uri::parse)
        if (uri == null || conteudo == null) {
            resultado.error("uri-invalida", "URI ou conteúdo ausente.", null); return
        }
        try {
            // "wt" = write + truncate. Sem o "t", um arquivo novo menor que o
            // anterior deixaria a cauda do conteúdo antigo no fim — defeito
            // silencioso e chato de achar.
            contentResolver.openOutputStream(uri, "wt")?.use {
                it.write(conteudo.toByteArray(Charsets.UTF_8))
                it.flush()
            } ?: run {
                resultado.error("sem-fluxo", "Não foi possível abrir para escrita.", null); return
            }
            resultado.success(true)
        } catch (e: SecurityException) {
            resultado.error("sem-permissao", "O acesso de escrita foi revogado.", null)
        } catch (e: Exception) {
            resultado.error("erro-escrita", e.message, null)
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
