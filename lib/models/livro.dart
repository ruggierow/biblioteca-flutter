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

  // Hash FNV-1a duplo — mesmo algoritmo do iOS e da web, para que fotos
  // salvas em qualquer plataforma sejam encontradas pelas demais.
  String get fotoId {
    final tNorm = titulo.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final aNorm = autores
        .map((a) => a.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();
    final chave = ([tNorm] + aNorm).join('\x00');

    final runes = chave.runes.toList();
    var h1 = 2166136261;
    var h2 = 2246822519;

    for (var i = 0; i < runes.length; i++) {
      final c = runes[i];
      h1 = ((h1 ^ c) * 16777619) & 0xFFFFFFFF;
      h2 = ((h2 ^ ((c + i + 1) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF;
    }

    return h1.toRadixString(36) + h2.toRadixString(36);
  }

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
