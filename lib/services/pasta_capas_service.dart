import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'foto_service.dart';

/// Sincroniza fotos de capa a partir de uma pasta no Google Drive (ou qualquer
/// armazenamento acessível pelo SAF) para o armazenamento local do app.
///
/// O Mac/iOS salva as capas no iCloud Drive como `{fotoId}.dat`. O Android
/// salva as suas localmente como `{fotoId}.jpg`. Como ambos usam o mesmo
/// hash FNV-1a para nomear o arquivo, basta copiar os bytes — a extensão
/// não importa, o conteúdo é JPEG em ambos os casos.
class PastaCapasService {
  PastaCapasService._();
  static final PastaCapasService shared = PastaCapasService._();

  static const _canal = MethodChannel('biblioteca/saf');

  /// Prazos para as chamadas que vao a rede. Um content:// do Drive baixa de
  /// verdade; sem prazo, uma rede ruim deixa a sincronizacao pendurada sem fim.
  /// Listar uma pasta cheia demora mais que ler um arquivo, por isso os dois
  /// valores.
  static const _prazoListar = Duration(seconds: 60);
  static const _prazoLer = Duration(seconds: 30);
  static const _prefUri  = 'bibliotecaCapasUri';
  static const _prefNome = 'bibliotecaCapasNome';

  Future<String?> get uri async =>
      (await SharedPreferences.getInstance()).getString(_prefUri);

  Future<String?> get nome async =>
      (await SharedPreferences.getInstance()).getString(_prefNome);

  Future<bool> temAcesso() async {
    final u = await uri;
    if (u == null) return false;
    return await _canal.invokeMethod<bool>('temAcessoPasta', {'uri': u}) ?? false;
  }

  /// Abre o seletor de pasta do sistema. Retorna o nome da pasta vinculada,
  /// ou null se o usuário cancelou.
  Future<String?> escolher() async {
    final r = await _canal.invokeMapMethod<String, dynamic>('escolherPasta');
    if (r == null) return null;
    final u = r['uri'] as String?;
    final n = r['nome'] as String?;
    if (u == null) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUri, u);
    await prefs.setString(_prefNome, n ?? 'capas');
    return n ?? 'capas';
  }

  Future<void> desvincular() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefUri);
    await prefs.remove(_prefNome);
  }

  /// Copia da pasta remota para o armazenamento local as fotos que ainda não
  /// existem localmente e cujo fotoId aparece na [fotoIds] da biblioteca atual.
  ///
  /// Retorna o número de fotos copiadas.
  Future<int> sincronizar(Set<String> fotoIds, {void Function(int atual, int total)? progresso}) async {
    final u = await uri;
    if (u == null) return 0;

    final lista = await _canal
            .invokeListMethod<dynamic>('listarPasta', {'uri': u})
            .timeout(_prazoListar) ??
        [];

    // Filtra apenas arquivos cujo nome (sem extensão) está na biblioteca
    final candidatos = <({String documentId, String fotoId})>[];
    for (final item in lista) {
      final nome   = (item as Map)['nome'] as String? ?? '';
      final docId  = item['documentId'] as String? ?? '';
      final fotoId = nome.replaceAll(RegExp(r'\.(dat|jpg|jpeg|png)$', caseSensitive: false), '');
      if (fotoIds.contains(fotoId)) candidatos.add((documentId: docId, fotoId: fotoId));
    }

    int copiados = 0;
    for (var i = 0; i < candidatos.length; i++) {
      final c = candidatos[i];
      progresso?.call(i, candidatos.length);

      // Não sobrescreve foto que o usuário tirou localmente
      if (await FotoService.shared.existe(livroId: c.fotoId)) continue;

      try {
        final bytes = await _canal
            .invokeMethod<Uint8List>(
              'lerArquivoDaPasta',
              {'pastaUri': u, 'documentId': c.documentId},
            )
            .timeout(_prazoLer);
        if (bytes != null && bytes.isNotEmpty) {
          await FotoService.shared.salvar(bytes, livroId: c.fotoId);
          copiados++;
        }
      } catch (_) {
        // Arquivo inacessível, corrompido, ou que estourou o prazo — pula e
        // continua. Uma foto que não veio não pode interromper as outras.
      }
    }
    return copiados;
  }
}
