/// Os nomes dos países, a partir do código ISO de duas letras da coluna 9.
///
/// A coluna guarda o código, não o nome: acento e grafia divergem entre as
/// quatro plataformas, e o mapa do Mac precisa casar região com valor. O nome
/// só existe na hora de mostrar.
///
/// A tabela é a mesma do `bin/semear-pais.py` e do motor-web. Um código que não
/// esteja aqui aparece como ele mesmo — nunca some.
class Paises {
  Paises._();

  static const _nomes = <String, String>{
    'BR': 'Brasil', 'AR': 'Argentina', 'CL': 'Chile', 'CO': 'Colômbia',
    'PE': 'Peru', 'UY': 'Uruguai', 'US': 'Estados Unidos', 'CA': 'Canadá',
    'MX': 'México', 'CU': 'Cuba', 'PT': 'Portugal', 'ES': 'Espanha',
    'FR': 'França', 'GB': 'Reino Unido', 'IE': 'Irlanda', 'DE': 'Alemanha',
    'IT': 'Itália', 'CH': 'Suíça', 'AT': 'Áustria', 'BE': 'Bélgica',
    'NL': 'Holanda', 'DK': 'Dinamarca', 'SE': 'Suécia', 'NO': 'Noruega',
    'PL': 'Polônia', 'CZ': 'Tchéquia', 'HU': 'Hungria', 'GR': 'Grécia',
    'BY': 'Bielorrússia', 'RU': 'Rússia', 'TR': 'Turquia', 'IL': 'Israel',
    'PS': 'Palestina', 'LB': 'Líbano', 'IR': 'Irã', 'IN': 'Índia',
    'CN': 'China', 'KR': 'Coreia do Sul', 'JP': 'Japão', 'EG': 'Egito',
    'SN': 'Senegal', 'NG': 'Nigéria', 'AO': 'Angola', 'RW': 'Ruanda',
    'MZ': 'Moçambique', 'ZA': 'África do Sul', 'AU': 'Austrália',
  };

  /// O nome do país, ou o próprio código quando ele não está na tabela.
  ///
  /// Devolver o código em vez de vazio é de propósito: um país desconhecido
  /// tem de APARECER, para alguém notar e acrescentá-lo. Sumir calado seria
  /// esconder um livro.
  static String nome(String iso) {
    final c = iso.trim().toUpperCase();
    return _nomes[c] ?? (c.isEmpty ? '' : c);
  }

  static bool conhecido(String iso) => _nomes.containsKey(iso.trim().toUpperCase());

  /// Os países em ordem alfabética pelo NOME mostrado.
  ///
  /// É a lista do seletor do formulário, e sai da MESMA tabela que dá nome ao
  /// país na tela: só se pode escolher um país que o app sabe nomear.
  ///
  /// A ordem IGNORA acento, e isso não é detalhe: `compareTo` compara código
  /// de caractere, e por ele "África do Sul", "Áustria" e "Índia" iriam para
  /// DEPOIS de Vietnã, no fim da lista, longe de onde alguém as procura.
  static final List<MapEntry<String, String>> ordenados = _nomes.entries.toList()
    ..sort((a, b) => _chaveDeOrdem(a.value).compareTo(_chaveDeOrdem(b.value)));

  static const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  static const _semAcento = 'aaaaaeeeeiiiiooooouuuucn';

  static String _chaveDeOrdem(String nome) {
    final b = StringBuffer();
    for (final c in nome.toLowerCase().split('')) {
      final i = _comAcento.indexOf(c);
      b.write(i < 0 ? c : _semAcento[i]);
    }
    return b.toString();
  }
}
