import 'dart:async';

import 'package:flutter/services.dart';

/// Referência à pasta escolhida pelo usuário via SAF.
class PastaEscolhida {
  final String uri;
  final String? nome;
  const PastaEscolhida({required this.uri, this.nome});
}

/// Vínculo com a PASTA, não com um arquivo por vez.
///
/// O Mac e o iPhone sempre vincularam a pasta; o Android e o Windows vinculavam
/// documento a documento, e por isso precisavam de um "vincular" para o
/// `biblioteca.txt`, outro para o `biblioteca.dat`, e não alcançavam o
/// `grupos.json` de jeito nenhum.
///
/// ATENÇÃO, medido no A57 em 14/09/2026: o Android **recusa raízes**. "Meu
/// Drive" e o armazenamento interno voltam com o botão "Usar esta pasta"
/// apagado e o aviso "Para proteger sua privacidade, escolha outra pasta".
/// É preciso escolher uma SUBPASTA. Não é limitação do Google Drive — dentro
/// de uma subpasta dele funciona normalmente.
class PastaSaf {
  PastaSaf._();
  static const _canal = MethodChannel('biblioteca/saf');
  static const _prazo = Duration(seconds: 30);

  /// Abre o seletor de pastas. Devolve `null` se o usuário cancelar.
  static Future<PastaEscolhida?> escolher() async {
    final r = await _canal.invokeMapMethod<String, dynamic>('escolherPasta');
    if (r == null) return null;
    final uri = r['uri'] as String?;
    if (uri == null) return null;
    return PastaEscolhida(uri: uri, nome: r['nome'] as String?);
  }

  /// O `content://` de um arquivo dentro da pasta, ou `null` se ele não existir.
  ///
  /// O URI devolvido herda a permissão da árvore, então serve direto para
  /// [DocumentoSaf.ler] e [DocumentoSaf.gravar].
  static Future<String?> arquivo(String pasta, String nome) async {
    return _canal.invokeMethod<String>(
      'arquivoNaPasta',
      {'pasta': pasta, 'nome': nome},
    ).timeout(_prazo);
  }

  /// O app ainda tem permissão persistente sobre a pasta?
  static Future<bool> temAcesso(String uri) async {
    return await _canal.invokeMethod<bool>('temAcessoPasta', {'uri': uri}) ??
        false;
  }
}
