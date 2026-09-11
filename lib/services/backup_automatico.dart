import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'documento_saf.dart';

/// Cópia de segurança automática do `biblioteca.txt` no aparelho.
///
/// Mesmas regras dos apps de desktop e do iPhone:
///
/// - **Antes da primeira gravação da sessão**, não no fim. Se o app for
///   encerrado pelo sistema, não há "fim de sessão" — e um backup do que se
///   está deixando é o que já está no arquivo. Copiando antes, preserva-se o
///   último estado bom.
/// - **Só copia se o conteúdo mudou** em relação ao backup mais recente.
/// - **Rotação de 30 gerações.**
///
/// ONDE FICAM, E POR QUÊ AQUI: na área de arquivos do próprio app
/// (`Android/data/com.wilson.biblioteca.biblioteca/files/Backups/`), e não ao
/// lado do `biblioteca.txt`. O motivo é do Android: o vínculo é um URI de
/// DOCUMENTO (`ACTION_OPEN_DOCUMENT`), que não dá acesso à pasta que o contém —
/// não há como criar um `Backups/` ali. Usar `OPEN_DOCUMENT_TREE` resolveria,
/// mas o provedor do Google Drive costuma não aceitar seleção de pasta, e isso
/// quebraria justamente o fluxo de sincronização em uso.
///
/// Consequências honestas desta escolha:
/// - os backups NÃO sobem para o Drive;
/// - somem se o app for desinstalado.
///
/// Servem como desfazer local ("apaguei um livro sem querer"). A proteção
/// contra perda de verdade continua sendo a do desktop, que grava em
/// `Backups/` no iCloud a cada mudança da base.
class BackupAutomatico {
  BackupAutomatico._();

  static const maximo = 30;
  static bool _jaFeito = false;

  /// Carimbo do início da sessão — o backup guarda o estado em que ela começou.
  static final String _sufixoSessao = _carimbo(DateTime.now());

  static String _carimbo(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}_${p(d.hour)}h${p(d.minute)}';
  }

  /// Pasta dos backups, visível por qualquer gerenciador de arquivos.
  static Future<Directory?> pasta() async {
    final base = await getExternalStorageDirectory();
    if (base == null) return null;
    final dir = Directory('${base.path}/Backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copia o conteúdo atual do documento vinculado, se ainda não houve backup
  /// nesta sessão e se ele difere do backup mais recente.
  ///
  /// Silencioso de propósito: uma falha de backup não pode impedir o usuário de
  /// salvar o trabalho dele.
  static Future<void> executar(String uri) async {
    if (_jaFeito) return;
    _jaFeito = true; // marca antes: se falhar, não insiste a cada gravação

    try {
      final atual = await DocumentoSaf.ler(uri);
      if (atual.isEmpty) return; // nada a preservar

      final dir = await pasta();
      if (dir == null) return;

      final anteriores = (await dir.list().toList())
          .whereType<File>()
          .where((f) => f.path.split('/').last.startsWith('biblioteca_'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      if (anteriores.isNotEmpty) {
        final ultimo = await anteriores.last.readAsString();
        if (ultimo == atual) return; // nada mudou desde o último backup
      }

      await File('${dir.path}/biblioteca_$_sufixoSessao.txt').writeAsString(atual);

      // Rotação: mantém os `maximo` mais recentes. Os nomes trazem a data em
      // AAAA-MM-DD_HHhMM, que ordena igual cronologicamente.
      final todos = (await dir.list().toList())
          .whereType<File>()
          .where((f) => f.path.split('/').last.startsWith('biblioteca_'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      if (todos.length > maximo) {
        for (final antigo in todos.take(todos.length - maximo)) {
          await antigo.delete();
        }
      }
    } catch (_) {
      // Backup é melhor-esforço; nunca atrapalha o salvar.
    }
  }
}
