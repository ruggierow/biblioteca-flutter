class Livro {
  final String id;
  final String titulo;
  final List<String> autores;
  final List<String> temas;
  final String ano;
  final bool emprestado;
  final String comentarios;
  final String local;
  final bool grupoLiteratura;

  const Livro({
    required this.id,
    required this.titulo,
    this.autores = const [],
    this.temas = const [],
    this.ano = '',
    this.emprestado = false,
    this.comentarios = '',
    this.local = '',
    this.grupoLiteratura = false,
  });

  Livro copyWith({
    String? titulo,
    List<String>? autores,
    List<String>? temas,
    String? ano,
    bool? emprestado,
    String? comentarios,
    String? local,
    bool? grupoLiteratura,
  }) {
    return Livro(
      id: id,
      titulo: titulo ?? this.titulo,
      autores: autores ?? this.autores,
      temas: temas ?? this.temas,
      ano: ano ?? this.ano,
      emprestado: emprestado ?? this.emprestado,
      comentarios: comentarios ?? this.comentarios,
      local: local ?? this.local,
      grupoLiteratura: grupoLiteratura ?? this.grupoLiteratura,
    );
  }
}
