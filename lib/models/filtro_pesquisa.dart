import 'livro.dart';

enum FiltroStatus {
  todos('Todos'),
  disponiveis('Disponíveis'),
  emprestados('Emprestados');

  const FiltroStatus(this.rotulo);
  final String rotulo;
}

/// O grupo escolhido no filtro: todos os livros, qualquer grupo, ou um
/// identificador especifico. `id` so tem valor no terceiro caso.
class FiltroGrupo {
  final int? id;
  final bool qualquer;
  const FiltroGrupo._(this.id, this.qualquer);

  static const todos = FiltroGrupo._(null, false);
  static const qualquerUm = FiltroGrupo._(null, true);
  const FiltroGrupo.especifico(int this.id) : qualquer = false;

  bool get semFiltro => id == null && !qualquer;

  @override
  bool operator ==(Object other) =>
      other is FiltroGrupo && other.id == id && other.qualquer == qualquer;

  @override
  int get hashCode => Object.hash(id, qualquer);
}

/// Os filtros da pesquisa, espelhando os do Mac e do Windows.
///
/// A diferenca deliberada: la sao quatro caixas de texto (titulo, autor, tema,
/// local); aqui e uma caixa so, que procura nos quatro mais o ano. Quatro
/// caixas lado a lado e idioma de tela grande.
class FiltroPesquisa {
  String texto;
  FiltroStatus status;
  FiltroGrupo grupo;
  bool comFoto;

  FiltroPesquisa({
    this.texto = '',
    this.status = FiltroStatus.todos,
    this.grupo = FiltroGrupo.todos,
    this.comFoto = false,
  });

  bool get ativo =>
      texto.trim().isNotEmpty ||
      status != FiltroStatus.todos ||
      grupo != FiltroGrupo.todos ||
      comFoto;

  /// Quantos filtros estao ligados — vira o numerinho ao lado do botao.
  int get quantosLigados {
    var n = 0;
    if (status != FiltroStatus.todos) n++;
    if (grupo != FiltroGrupo.todos) n++;
    if (comFoto) n++;
    return n;
  }

  void limpar() {
    texto = '';
    status = FiltroStatus.todos;
    grupo = FiltroGrupo.todos;
    comFoto = false;
  }

  FiltroPesquisa copia() => FiltroPesquisa(
      texto: texto, status: status, grupo: grupo, comFoto: comFoto);

  /// A descricao dos filtros ligados, para a linha de resumo.
  String resumo(String Function(int) nomeDoGrupo) {
    final partes = <String>[];
    if (status != FiltroStatus.todos) partes.add(status.rotulo);
    if (grupo.qualquer) {
      partes.add('Qualquer grupo');
    } else if (grupo.id != null) {
      partes.add(nomeDoGrupo(grupo.id!));
    }
    if (comFoto) partes.add('Com foto');
    return partes.join(' · ');
  }

  bool aceita(Livro l) {
    switch (status) {
      case FiltroStatus.todos:
        break;
      case FiltroStatus.disponiveis:
        if (l.emprestado) return false;
      case FiltroStatus.emprestados:
        if (!l.emprestado) return false;
    }
    if (grupo.qualquer && !l.grupoLiteratura) return false;
    if (grupo.id != null && !l.listaGrupos.contains(grupo.id)) return false;
    return true;
  }
}
