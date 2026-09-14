import 'dart:convert';

import '../models/grupos_store.dart';
import 'documento_saf.dart';
import 'vinculo_pasta.dart';

/// Lê os NOMES dos grupos de literatura do `grupos.json` da pasta vinculada.
///
/// O `biblioteca.txt` guarda só os números na coluna 8 ("1;3"). Quem escreve os
/// nomes é o app do Mac, num arquivo ao lado. A ausência do arquivo é o caso
/// normal de quem nunca renomeou nada: aí os grupos aparecem como "Grupo 1",
/// "Grupo 2" e o filtro funciona igual.
class GruposJson {
  GruposJson._();

  static const arquivo = 'grupos.json';

  static Future<void> carregar() async {
    final uri = await VinculoPasta.arquivo(arquivo);
    if (uri == null) return;
    try {
      final bruto = await DocumentoSaf.ler(uri);
      if (bruto.trim().isEmpty) return;
      final raiz = jsonDecode(bruto);
      if (raiz is! Map) return;
      final itens = raiz['grupos'];
      if (itens is! List) return;

      final lidos = <Grupo>[];
      for (final item in itens) {
        if (item is! Map) continue;
        final id = item['id'];
        final nome = item['nome'];
        if (id is! int || id <= 0) continue;
        if (nome is! String || nome.trim().isEmpty) continue;
        lidos.add(Grupo(id, nome.trim()));
      }
      if (lidos.isEmpty) return;
      lidos.sort((a, b) => a.id.compareTo(b.id));
      GruposStore.shared.grupos = lidos;
    } catch (_) {
      // Arquivo ilegível não pode impedir o app de abrir: os nomes são
      // enfeite, o filtro trabalha com os números.
    }
  }
}
