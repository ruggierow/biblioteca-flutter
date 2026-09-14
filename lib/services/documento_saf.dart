import 'dart:async';

import 'package:flutter/services.dart';

/// Acesso ao arquivo pelo Storage Access Framework do Android.
///
/// Substitui o `file_picker`, que devolvia o caminho de uma CÓPIA no cache do
/// app: o que se editava nunca voltava para o arquivo original (nem para o
/// Google Drive), e o vínculo sumia quando o Android limpava o cache.
///
/// Aqui o que se guarda é o `content://` com permissão persistente — o
/// equivalente Android do security-scoped bookmark usado no app do iPhone.
/// A implementação está em `MainActivity.kt`.
///
/// Desde a 1.9.1 o URI não vem mais de um seletor próprio: vem de
/// [PastaSaf.arquivo], que resolve o arquivo dentro da PASTA vinculada. Por
/// isso aqui só sobraram ler e gravar — escolher, nome e temAcesso viraram
/// responsabilidade do vínculo com a pasta.
class DocumentoSaf {
  DocumentoSaf._();
  static const _canal = MethodChannel('biblioteca/saf');

  /// Prazo para as operações que podem falar com a rede.
  ///
  /// Um `content://` do Google Drive baixa o arquivo antes de entregar os
  /// bytes. Sem prazo, uma rede ruim deixaria a tela esperando para sempre —
  /// e o usuário sem nenhuma pista do que houve.
  static const _prazo = Duration(seconds: 30);

  /// Lê o documento inteiro. Lança [PlatformException] se o acesso caiu,
  /// ou [TimeoutException] se o armazenamento não respondeu a tempo.
  static Future<String> ler(String uri, {Duration? prazo}) async {
    final texto = await _canal
        .invokeMethod<String>('ler', {'uri': uri})
        .timeout(prazo ?? _prazo);
    return texto ?? '';
  }

  /// Grava por cima do documento original, truncando o que havia antes.
  static Future<void> gravar(String uri, String conteudo) async {
    await _canal
        .invokeMethod<bool>('gravar', {'uri': uri, 'conteudo': conteudo})
        .timeout(_prazo);
  }

}
