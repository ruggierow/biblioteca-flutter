import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/documento_saf.dart';
import 'livro.dart';

class BibliotecaStore extends ChangeNotifier {
  List<Livro> livros = [];

  /// Nome visível do arquivo vinculado (ex.: "biblioteca.txt").
  /// Null quando não há vínculo.
  String? arquivoNome;

  /// `content://` do documento, com permissão persistente do SAF.
  String? arquivoUri;

  String? erroMensagem;
  DateTime? ultimaGravacao;
  DateTime? ultimaRecarga;

  static const _sep = ';';
  static const _prefUri = 'bibliotecaDocUri';
  static const _prefNome = 'bibliotecaDocNome';

  /// Chave das versões até a 1.8.3, que guardava o caminho de uma CÓPIA no
  /// cache do app. Não dá para converter num URI — só serve para detectar o
  /// vínculo antigo, descartá-lo e pedir que o usuário escolha o arquivo de novo.
  static const _prefLegado = 'bibliotecaFilePath';

  BibliotecaStore() {
    _restaurarArquivo();
  }

  // MARK: - Vínculo com arquivo
  //
  // O vínculo é um content:// com permissão persistente, não um caminho de
  // arquivo. Antes usávamos o `file_picker`, que devolve o caminho de uma cópia
  // no cache: o que se editava nunca voltava para o arquivo original — nem para
  // o Google Drive — e o vínculo sumia quando o Android limpava o cache.

  /// Abre o seletor do sistema e vincula o documento escolhido.
  /// Retorna false se o usuário cancelar.
  Future<bool> escolherEVincular() async {
    try {
      final doc = await DocumentoSaf.escolher();
      if (doc == null) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUri, doc.uri);
      await prefs.setString(_prefNome, doc.nome ?? 'biblioteca.txt');
      await prefs.remove(_prefLegado);

      arquivoUri = doc.uri;
      arquivoNome = doc.nome ?? 'biblioteca.txt';
      await carregarDoArquivo();
      return true;
    } catch (e) {
      erroMensagem = 'Erro ao vincular: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _restaurarArquivo() async {
    final prefs = await SharedPreferences.getInstance();

    // Vínculo antigo (caminho de cache): descarta e avisa.
    if (prefs.getString(_prefUri) == null &&
        prefs.getString(_prefLegado) != null) {
      await prefs.remove(_prefLegado);
      erroMensagem = 'O vínculo anterior não valia mais. '
          'Toque em Selecionar arquivo e escolha o biblioteca.txt de novo.';
      notifyListeners();
      return;
    }

    final uri = prefs.getString(_prefUri);
    if (uri == null) return;

    // A permissão pode ter sido revogada (o usuário limpou os dados do app,
    // ou o provedor perdeu o documento).
    if (!await DocumentoSaf.temAcesso(uri)) {
      await prefs.remove(_prefUri);
      await prefs.remove(_prefNome);
      erroMensagem = 'O acesso ao arquivo foi perdido. '
          'Toque em Selecionar arquivo para vinculá-lo de novo.';
      notifyListeners();
      return;
    }

    arquivoUri = uri;
    arquivoNome = prefs.getString(_prefNome) ?? await DocumentoSaf.nome(uri);
    await carregarDoArquivo();
  }

  Future<void> carregarDoArquivo() async {
    final uri = arquivoUri;
    if (uri == null) return;
    try {
      livros = parsear(await DocumentoSaf.ler(uri));
      ultimaRecarga = DateTime.now();
      erroMensagem = null;
    } catch (e) {
      erroMensagem = 'Erro ao carregar: $e';
    }
    notifyListeners();
  }

  Future<void> recarregarArquivo() async => carregarDoArquivo();

  Future<void> salvar() async {
    final uri = arquivoUri;
    if (uri == null) return;
    try {
      await DocumentoSaf.gravar(uri, serializar());
      ultimaGravacao = DateTime.now();
      erroMensagem = null;
    } catch (e) {
      erroMensagem = 'Erro ao salvar: $e';
    }
    notifyListeners();
  }

  // MARK: - CRUD

  Future<void> adicionar(Livro livro) async {
    livros = [...livros, livro];
    await salvar();
  }

  Future<void> atualizar(Livro livro) async {
    livros = [
      for (final l in livros) l.id == livro.id ? livro : l,
    ];
    await salvar();
  }

  Future<void> remover(String id) async {
    livros = livros.where((l) => l.id != id).toList();
    await salvar();
  }

  // MARK: - TSV

  List<Livro> parsear(String texto) {
    return texto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((linha) {
          final c = linha.split('\t');
          if (c.isEmpty || c[0].isEmpty) return null;
          return Livro(
            id: DateTime.now().microsecondsSinceEpoch.toString() +
                linha.hashCode.toString(),
            titulo: c[0],
            autores: c.length > 1 ? _split(c[1]) : [],
            temas: c.length > 2 ? _split(c[2]) : [],
            ano: c.length > 3 ? c[3] : '',
            emprestado: c.length > 4 && c[4] == '1',
            comentarios: c.length > 5 ? c[5] : '',
            local: c.length > 6 ? c[6] : '',
            grupoLiteratura: c.length > 7 && c[7].trim() == '1',
          );
        })
        .whereType<Livro>()
        .toList();
  }

  List<String> _split(String campo) {
    return campo
        .split(_sep)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String serializar() {
    return livros.map((l) {
      return [
        l.titulo,
        l.autores.join('; '),
        l.temas.join('; '),
        l.ano,
        l.emprestado ? '1' : '0',
        l.comentarios,
        l.local,
        l.grupoLiteratura ? '1' : '0',
      ].join('\t');
    }).join('\n');
  }
}
