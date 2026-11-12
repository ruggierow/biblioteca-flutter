import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backup_automatico.dart';
import '../services/documento_saf.dart';
import '../services/grupos_json.dart';
import '../services/vinculo_pasta.dart';
import 'livro.dart';
import 'idioma.dart';

/// O que há na pasta recém-escolhida, ANTES de vincular qualquer arquivo.
///
/// Olhar antes de agir é o que permite perguntar algo que o usuário consegue
/// responder — "achei 757 livros aqui, uso esta biblioteca?" em vez de "quer
/// usar o arquivo?" sem ele saber o que há dentro.
class ConteudoDaPasta {
  /// Nome da pasta, para aparecer na pergunta.
  final String pasta;

  /// Há um `biblioteca.txt` ali?
  final bool temArquivo;

  /// Quantos livros ele tem. Só vale quando [temArquivo] e [erroDeLeitura]
  /// é nulo.
  final int livros;

  /// Há arquivo, mas não deu para lê-lo. Nunca criar por cima neste caso:
  /// pode ser a biblioteca de alguém, ilegível por permissão ou por estar
  /// ainda baixando da nuvem.
  final String? erroDeLeitura;

  const ConteudoDaPasta({
    required this.pasta,
    required this.temArquivo,
    this.livros = 0,
    this.erroDeLeitura,
  });
}

class BibliotecaStore extends ChangeNotifier {
  List<Livro> livros = [];

  /// Nome visível do arquivo vinculado (ex.: "biblioteca.txt").
  /// Null quando não há vínculo.
  String? arquivoNome;

  /// `content://` do documento, com permissão persistente do SAF.
  String? arquivoUri;

  String? erroMensagem;

  /// Verdadeiro desde o nascimento do store ate a primeira carga terminar,
  /// com ou sem sucesso.
  ///
  /// Sem isto a lista mostrava "Nenhum livro cadastrado" enquanto o arquivo
  /// ainda vinha da nuvem — afirmando que a biblioteca esta vazia quando ela
  /// so nao chegou. A tela parecia pronta e nao estava.
  bool carregando = true;

  void _terminouDeCarregar() {
    if (!carregando) return;
    carregando = false;
    notifyListeners();
  }
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
    // `_restaurarArquivo` nao lanca: ele mesmo trata as falhas e escreve em
    // erroMensagem. O `whenComplete` fecha o aviso em TODOS os desfechos —
    // inclusive aquele em que nao ha pasta vinculada e nada e lido.
    _restaurarArquivo().whenComplete(_terminouDeCarregar);
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
      erroMensagem = t('erroAoVincular', [e]);
      notifyListeners();
      return false;
    }
  }

  /// Abre o seletor de pastas e diz o que há na pasta escolhida, SEM
  /// vincular nada. `null` quer dizer que o usuário cancelou.
  ///
  /// A pasta em si JÁ fica guardada: se o usuário desistir na pergunta
  /// seguinte, ele cai no estado "pasta vinculada, sem arquivo", de onde a
  /// própria tela oferece escolher outra.
  Future<ConteudoDaPasta?> escolherPastaEOlhar() async {
    if (!await VinculoPasta.escolher()) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefLegado);
    await prefs.remove(_prefUri);
    await prefs.remove(_prefNome);

    final pasta = VinculoPasta.nome ?? t('pastaEscolhida');
    final uri = await VinculoPasta.arquivo(arquivoPadrao);
    if (uri == null) {
      return ConteudoDaPasta(pasta: pasta, temArquivo: false);
    }
    try {
      final quantos = parsear(await DocumentoSaf.ler(uri)).length;
      return ConteudoDaPasta(pasta: pasta, temArquivo: true, livros: quantos);
    } catch (e) {
      return ConteudoDaPasta(
          pasta: pasta, temArquivo: true, erroDeLeitura: '$e');
    }
  }

  /// Passa a usar o `biblioteca.txt` que JÁ existe na pasta escolhida.
  Future<bool> usarArquivoDaPasta() => _abrirNaPasta();

  /// Resolve o `biblioteca.txt` dentro da pasta vinculada e carrega.
  Future<bool> _abrirNaPasta() async {
    final uri = await VinculoPasta.arquivo(arquivoPadrao);
    if (uri == null) {
      arquivoUri = null;
      arquivoNome = null;
      erroMensagem = t('semArquivoNaPasta',
          [arquivoPadrao, VinculoPasta.nome ?? t('pastaEscolhida')]);
      notifyListeners();
      return false;
    }
    arquivoUri = uri;
    arquivoNome = arquivoPadrao;
    await GruposJson.carregar();
    await carregarDoArquivo();
    return true;
  }

  /// Cria um `biblioteca.txt` na pasta vinculada e passa a usá-lo.
  ///
  /// Sem isto, vincular uma pasta que ainda não tem o arquivo era um beco sem
  /// saída: [_abrirNaPasta] acusava a falta, zerava o [arquivoUri], e
  /// [salvar] desiste quando ele é nulo.
  ///
  /// Grava sempre um TSV válido — que para uma biblioteca vazia tem zero
  /// byte mesmo, e isso é correto: o formato é uma linha por livro, e sem
  /// livros não há linha. (Medido em 12/11: a pasta vazia sai com um
  /// `biblioteca.txt` de 0 byte, e o app o relê como 0 livros.)
  ///
  /// O que vai dentro depende de [levarLivros], e quem decide é o usuário:
  ///
  ///  - `false` — começa uma biblioteca nova e vazia. A lista aberta é
  ///    esquecida AQUI, não no disco: o arquivo de onde ela veio continua
  ///    intacto na pasta dele.
  ///  - `true` — leva a lista aberta para a pasta nova.
  ///
  /// No primeiro uso a lista está vazia e os dois dão no mesmo, então a tela
  /// não pergunta nada. A pergunta só aparece na TROCA de pasta, que é o
  /// único caso em que há o que perder.
  Future<bool> criarArquivoNaPasta({bool levarLivros = false}) async {
    if (!VinculoPasta.vinculada) return false;
    try {
      final uri = await VinculoPasta.criarArquivo(arquivoPadrao);
      if (uri == null) {
        erroMensagem = t('erroAoCriarArquivo', [arquivoPadrao]);
        notifyListeners();
        return false;
      }
      arquivoUri = uri;
      arquivoNome = arquivoPadrao;
      erroMensagem = null;
      if (!levarLivros) livros = [];
      await GruposJson.carregar();
      await salvar();
      notifyListeners();
      return true;
    } catch (e) {
      erroMensagem = t('erroAoCriarArquivo', [e]);
      notifyListeners();
      return false;
    }
  }

  Future<void> _restaurarArquivo() async {
    try {
      await _restaurarArquivoInterno();
    } catch (e) {
      // Garante que qualquer falha de plataforma (ex.: Google Drive offline,
      // permissão revogada de forma inesperada) não impeça o app de abrir.
      erroMensagem = t('naoFoiPossivelCarregar');
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
      erroMensagem = t('agoraVinculaPasta');
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
      erroMensagem = t('erroAoCarregar', [e]);
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
      erroMensagem = t('erroAoSalvar', [e]);
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
            pais: c.length > 8 ? c[8].trim().toUpperCase() : '',
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
      final campos = [
        l.titulo,
        l.autores.join('; '),
        l.temas.join('; '),
        l.ano,
        l.emprestado ? '1' : '0',
        l.comentarios,
        l.local,
        l.grupos,
      ];
      // A 9a coluna so e escrita quando ha pais. Escrever sempre deixaria um
      // tabulador no fim de toda linha e faria o arquivo inteiro aparecer como
      // alterado a cada gravacao.
      if (l.pais.trim().isNotEmpty) campos.add(l.pais.trim());
      return campos.join('\t');
    }).join('\n');
  }
}
