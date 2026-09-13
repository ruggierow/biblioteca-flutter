import 'dart:async';

import 'package:flutter/services.dart';

/// Referência a um documento escolhido pelo usuário via SAF.
class DocumentoEscolhido {
  final String uri;
  final String? nome;
  const DocumentoEscolhido({required this.uri, this.nome});
}

/// Acesso ao arquivo pelo Storage Access Framework do Android.
///
/// Substitui o `file_picker`, que devolvia o caminho de uma CÓPIA no cache do
/// app: o que se editava nunca voltava para o arquivo original (nem para o
/// Google Drive), e o vínculo sumia quando o Android limpava o cache.
///
/// Aqui o que se guarda é o `content://` com permissão persistente — o
/// equivalente Android do security-scoped bookmark usado no app do iPhone.
/// A implementação está em `MainActivity.kt`.
class DocumentoSaf {
  DocumentoSaf._();
  static const _canal = MethodChannel('biblioteca/saf');

  /// Abre o seletor do sistema. Devolve `null` se o usuário cancelar.
  static Future<DocumentoEscolhido?> escolher() async {
    final r = await _canal.invokeMapMethod<String, dynamic>('escolherDocumento');
    if (r == null) return null;
    final uri = r['uri'] as String?;
    if (uri == null) return null;
    return DocumentoEscolhido(uri: uri, nome: r['nome'] as String?);
  }

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

  /// O app ainda tem permissão persistente de leitura e escrita?
  static Future<bool> temAcesso(String uri) async {
    return await _canal.invokeMethod<bool>('temAcesso', {'uri': uri}) ?? false;
  }

  /// Nome visível do documento, para mostrar na tela.
  static Future<String?> nome(String uri) async {
    return _canal.invokeMethod<String>('nome', {'uri': uri}).timeout(
      _prazo,
      onTimeout: () => null, // é só rótulo de tela; não vale travar por isso
    );
  }
}
