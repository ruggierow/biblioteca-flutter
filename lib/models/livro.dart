class Livro {
  final String id;
  final String titulo;
  final List<String> autores;
  final List<String> temas;
  final String ano;
  final bool emprestado;
  final String comentarios;
  final String local;

  /// Coluna 8 do arquivo, guardada exatamente como veio.
  ///
  /// A interface web escreve ali uma lista de grupos separada por ponto e
  /// vírgula ("1;3"); o celular só distingue participar de não participar.
  /// Guardar o texto original impede que uma gravação feita aqui apague a
  /// participação em grupos que este motor ainda não sabe representar.
  final String grupos;

  const Livro({
    required this.id,
    required this.titulo,
    this.autores = const [],
    this.temas = const [],
    this.ano = '',
    this.emprestado = false,
    this.comentarios = '',
    this.local = '',
    this.grupos = '0',
  });

  bool get grupoLiteratura => participaDeGrupo(grupos);

  static bool participaDeGrupo(String bruto) =>
      bruto.split(';').any((p) => (int.tryParse(p.trim()) ?? 0) > 0);

  /// Liga ou desliga a participação preservando a lista quando ela já existe:
  /// um livro em "1;3" que continua no grupo permanece "1;3".
  static String comParticipacao(String bruto, bool participa) {
    if (participa == participaDeGrupo(bruto)) return bruto;
    return participa ? '1' : '0';
  }

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
    String? grupos,
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
      grupos: grupos ??
          (grupoLiteratura == null
              ? this.grupos
              : comParticipacao(this.grupos, grupoLiteratura)),
    );
  }
}
