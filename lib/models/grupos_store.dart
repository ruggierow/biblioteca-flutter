import 'livro.dart';

/// Um grupo de literatura: o numero que aparece na coluna 8 do arquivo e o
/// nome que o usuario deu a ele.
class Grupo {
  final int id;
  final String nome;
  const Grupo(this.id, this.nome);
}

/// Os NOMES dos grupos nao cabem no `biblioteca.txt`, que guarda so os numeros
/// ("1;3"). No Mac e no iPhone eles vem de um `grupos.json` ao lado do arquivo.
///
/// O Android vincula DOCUMENTOS avulsos pelo SAF, nao uma pasta, entao ainda
/// nao alcanca esse vizinho: aqui os grupos aparecem como "Grupo 1", "Grupo 2".
/// O filtro funciona igual — so o rotulo muda. Quando a vinculacao por pasta
/// chegar, e so alimentar `grupos` daqui.
class GruposStore {
  GruposStore._();
  static final GruposStore shared = GruposStore._();

  static const padrao = Grupo(1, 'Grupo de Literatura');

  List<Grupo> grupos = const [padrao];

  /// O nome do grupo, ou "Grupo N" quando nao se sabe o nome.
  String nome(int id) {
    for (final g in grupos) {
      if (g.id == id) return g.nome;
    }
    return 'Grupo $id';
  }

  /// Os grupos que o seletor deve oferecer: os conhecidos, mais os que
  /// aparecem nos livros sem estar na lista.
  List<Grupo> oferecidos(List<Livro> livros) {
    final ids = grupos.map((g) => g.id).toSet();
    final extras = <int>{};
    for (final l in livros) {
      for (final id in l.listaGrupos) {
        if (!ids.contains(id)) extras.add(id);
      }
    }
    final todos = [...grupos, ...extras.map((id) => Grupo(id, 'Grupo $id'))];
    todos.sort((a, b) => a.id.compareTo(b.id));
    return todos;
  }
}
