import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backup_automatico.dart';
import '../services/documento_saf.dart';
import '../services/grupos_json.dart';
import '../services/vinculo_pasta.dart';
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
  /// Nome do arquivo dentro da pasta vinculada. Fixo: as quatro plataformas
  /// usam o mesmo nome, e era o `biblioteca (1).txt` solto no Drive que fazia
  /// a base do Android divergir da do iCloud.
  static const arquivoPadrao = 'biblioteca.txt';

  /// Chaves do vínculo por DOCUMENTO, das versões até a 1.9.0. Agora o vínculo
  /// é com a pasta; estas só servem para detectar o modelo antigo e descartá-lo.
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

  /// Abre o seletor de PASTAS e vincula a pasta escolhida.
  /// Retorna false se o usuário cancelar.
  Future<bool> escolherEVincular() async {
    try {
      if (!await VinculoPasta.escolher()) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefLegado);
      await prefs.remove(_prefUri);
      await prefs.remove(_prefNome);

      return await _abrirNaPasta();
    } catch (e) {
      erroMensagem = 'Erro ao vincular: $e';
      notifyListeners();
      return false;
    }
  }

  /// Resolve o `biblioteca.txt` dentro da pasta vinculada e carrega.
  Future<bool> _abrirNaPasta() async {
    final uri = await VinculoPasta.arquivo(arquivoPadrao);
    if (uri == null) {
      arquivoUri = null;
      arquivoNome = null;
      erroMensagem = 'Não há um $arquivoPadrao na pasta '
          '"${VinculoPasta.nome ?? 'escolhida'}". '
          'Escolha a pasta onde o arquivo está.';
      notifyListeners();
      return false;
    }
    arquivoUri = uri;
    arquivoNome = arquivoPadrao;
    await GruposJson.carregar();
    await carregarDoArquivo();
    return true;
  }

  Future<void> _restaurarArquivo() async {
    try {
      await _restaurarArquivoInterno();
    } catch (e) {
      // Garante que qualquer falha de plataforma (ex.: Google Drive offline,
      // permissão revogada de forma inesperada) não impeça o app de abrir.
      erroMensagem = 'Não foi possível carregar o arquivo vinculado. '
          'Toque em Selecionar arquivo para vinculá-lo de novo.';
      notifyListeners();
    }
  }

  Future<void> _restaurarArquivoInterno() async {
    final prefs = await SharedPreferences.getInstance();

    if (await VinculoPasta.restaurar()) {
      await _abrirNaPasta();
      return;
    }

    // Modelos antigos: o caminho de cache (até a 1.8.3) e o vínculo por
    // DOCUMENTO (1.9.0). Nenhum dos dois vira uma pasta — só dá para descartar
    // e pedir que o usuário escolha a pasta uma vez.
    final tinhaVinculoAntigo = prefs.getString(_prefUri) != null ||
        prefs.getString(_prefLegado) != null;
    if (tinhaVinculoAntigo) {
      await prefs.remove(_prefLegado);
      await prefs.remove(_prefUri);
      await prefs.remove(_prefNome);
      erroMensagem = 'Agora a Biblioteca vincula a PASTA inteira, e não cada '
          'arquivo. Toque em Selecionar pasta e escolha a pasta onde está o '
          'biblioteca.txt — o biblioteca.dat vem junto.';
      notifyListeners();
    }
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
    // Preserva o último estado bom antes da primeira gravação da sessão.
    await BackupAutomatico.executar(uri);
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
            grupos: c.length > 7 ? c[7].trim() : '0',
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
        l.grupos,
      ].join('\t');
    }).join('\n');
  }
}
