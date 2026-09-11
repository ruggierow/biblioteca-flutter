import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class FotoService {
  FotoService._();
  static final FotoService shared = FotoService._();

  Future<Directory> get _capasDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/capas');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _path(String livroId) async {
    final dir = await _capasDir;
    return '${dir.path}/$livroId.jpg';
  }

  Future<void> salvar(Uint8List bytes, {required String livroId}) async {
    if (livroId.isEmpty) return;
    await File(await _path(livroId)).writeAsBytes(bytes, flush: true);
  }

  Future<Uint8List?> carregar({required String livroId}) async {
    if (livroId.isEmpty) return null;
    final file = File(await _path(livroId));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> remover({required String livroId}) async {
    if (livroId.isEmpty) return;
    final file = File(await _path(livroId));
    if (await file.exists()) await file.delete();
  }

  Future<bool> existe({required String livroId}) async {
    if (livroId.isEmpty) return false;
    return File(await _path(livroId)).exists();
  }

  Future<void> migrar({required String idAntigo, required String idNovo}) async {
    if (idAntigo == idNovo) return;
    final bytes = await carregar(livroId: idAntigo);
    if (bytes == null) return;
    await File(await _path(idNovo)).writeAsBytes(bytes, flush: true);
    await remover(livroId: idAntigo);
  }
}
