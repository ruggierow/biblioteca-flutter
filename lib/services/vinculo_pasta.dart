import 'package:shared_preferences/shared_preferences.dart';

import 'pasta_saf.dart';

/// O vínculo único do Android: uma pasta, de onde saem os três arquivos.
///
/// Até a 1.9.0 cada arquivo tinha o seu "vincular" e o seu par de chaves no
/// SharedPreferences — um para o `biblioteca.txt`, outro para o
/// `biblioteca.dat` — e o `grupos.json` não tinha como ser alcançado. Agora é
/// uma escolha só, como no Mac e no iPhone.
class VinculoPasta {
  VinculoPasta._();

  static const _prefUri = 'bibliotecaPastaUri';
  static const _prefNome = 'bibliotecaPastaNome';

  static String? uri;
  static String? nome;

  static bool get vinculada => uri != null;

  /// Lê o vínculo guardado e confere se a permissão ainda vale.
  /// Devolve false quando não há pasta, ou quando o acesso se perdeu.
  static Future<bool> restaurar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardada = prefs.getString(_prefUri);
    if (guardada == null) return false;
    if (!await PastaSaf.temAcesso(guardada)) {
      await esquecer();
      return false;
    }
    uri = guardada;
    nome = prefs.getString(_prefNome);
    return true;
  }

  /// Abre o seletor. Devolve false se o usuário cancelar.
  static Future<bool> escolher() async {
    final p = await PastaSaf.escolher();
    if (p == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUri, p.uri);
    if (p.nome != null) await prefs.setString(_prefNome, p.nome!);
    uri = p.uri;
    nome = p.nome;
    return true;
  }

  static Future<void> esquecer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefUri);
    await prefs.remove(_prefNome);
    uri = null;
    nome = null;
  }

  /// O `content://` de um arquivo da pasta, ou null se ele não existir ali.
  static Future<String?> arquivo(String nomeDoArquivo) async {
    final p = uri;
    if (p == null) return null;
    return PastaSaf.arquivo(p, nomeDoArquivo);
  }
}
