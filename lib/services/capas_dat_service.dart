import 'dart:convert';
import 'dart:typed_data';

import 'documento_saf.dart';
import 'foto_service.dart';
import 'vinculo_pasta.dart';

/// Traz as capas para o Android a partir do `biblioteca.dat`.
///
/// POR QUE O `.dat`, E NÃO UMA PASTA DE FOTOS: porque é o que as outras
/// plataformas realmente produzem. O Mac e o iPhone guardam TODAS as capas
/// dentro de um único arquivo — um JSON de `fotoId` para `data:image/jpeg;
/// base64,...` — e é esse arquivo que já viaja pelo iCloud e pelo Drive.
/// Não existe, em lugar nenhum, uma pasta com um arquivo por capa.
///
/// A primeira versão deste recurso supunha essa pasta e por isso não teria
/// achado foto nenhuma: teria listado a pasta, visto um `biblioteca.dat`,
/// procurado um livro de `fotoId` "biblioteca" e respondido "nenhuma foto
/// nova" — sem erro e sem pista. Descoberto em 13/09/2026, antes do teste.
///
/// O Android só LÊ. Quem grava capa no `.dat` é o desktop e o iPhone; aqui as
/// fotos tiradas no aparelho ficam locais, como sempre foram.
class CapasDatService {
  CapasDatService._();
  static final CapasDatService shared = CapasDatService._();

  /// Nome fixo dentro da pasta vinculada — o mesmo nas quatro plataformas.
  static const arquivoPadrao = 'biblioteca.dat';

  /// O `.dat` chega a dezenas de MB e vem pela rede: o prazo normal de 30 s
  /// não dá conta numa conexão ruim.
  static const _prazo = Duration(minutes: 5);

  /// O `.dat` sai da MESMA pasta do `biblioteca.txt`: não há mais um
  /// "vincular" só para ele. Devolve null quando a pasta não tem o arquivo.
  Future<String?> get uri => VinculoPasta.arquivo(arquivoPadrao);

  Future<String?> get nome async =>
      await uri == null ? null : arquivoPadrao;

  Future<bool> temAcesso() async => await uri != null;

  /// Copia para o armazenamento local as capas que ainda não existem aqui e
  /// cujo `fotoId` pertence a algum livro da biblioteca atual.
  ///
  /// Devolve quantas foram copiadas. Não sobrescreve foto tirada no aparelho.
  Future<int> sincronizar(Set<String> fotoIds) async {
    final u = await uri;
    if (u == null) return 0;

    final bruto = await DocumentoSaf.ler(u, prazo: _prazo);
    if (bruto.trim().isEmpty) return 0;

    final Map<String, dynamic> mapa;
    try {
      mapa = jsonDecode(bruto) as Map<String, dynamic>;
    } on FormatException {
      throw const FormatoInesperado();
    }

    var copiados = 0;
    for (final entrada in mapa.entries) {
      final fotoId = entrada.key;
      if (!fotoIds.contains(fotoId)) continue;
      if (await FotoService.shared.existe(livroId: fotoId)) continue;

      final bytes = _bytesDe(entrada.value);
      if (bytes == null || bytes.isEmpty) continue;
      await FotoService.shared.salvar(bytes, livroId: fotoId);
      copiados++;
    }
    return copiados;
  }

  /// Aceita `data:image/jpeg;base64,XXXX` e também base64 puro, porque versões
  /// antigas do arquivo gravavam sem o prefixo.
  static Uint8List? _bytesDe(dynamic valor) {
    if (valor is! String || valor.isEmpty) return null;
    final virgula = valor.indexOf(',');
    final base = valor.startsWith('data:') && virgula > 0
        ? valor.substring(virgula + 1)
        : valor;
    try {
      return base64Decode(base);
    } catch (_) {
      return null;
    }
  }
}

/// O arquivo escolhido não é um `biblioteca.dat`.
class FormatoInesperado implements Exception {
  const FormatoInesperado();
  @override
  String toString() =>
      'O arquivo escolhido não parece ser o biblioteca.dat.';
}
