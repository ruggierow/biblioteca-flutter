import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'livro.dart';

class BibliotecaStore extends ChangeNotifier {
  List<Livro> livros = [];
  String? arquivoPath;
  String? erroMensagem;
  DateTime? ultimaGravacao;
  DateTime? ultimaRecarga;

  static const _sep = ';';
  static const _prefKey = 'bibliotecaFilePath';

  BibliotecaStore() {
    _restaurarArquivo();
  }

  // MARK: - Vínculo com arquivo

  Future<void> vincularArquivo(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, path);
    arquivoPath = path;
    await carregarDoArquivo(path);
  }

  Future<void> _restaurarArquivo() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefKey);
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) {
      await prefs.remove(_prefKey);
      return;
    }
    arquivoPath = path;
    await carregarDoArquivo(path);
  }

  Future<void> carregarDoArquivo(String path) async {
    try {
      final texto = await File(path).readAsString();
      livros = parsear(texto);
      ultimaRecarga = DateTime.now();
      erroMensagem = null;
    } catch (e) {
      erroMensagem = 'Erro ao carregar: $e';
    }
    notifyListeners();
  }

  Future<void> recarregarArquivo() async {
    if (arquivoPath == null) return;
    await carregarDoArquivo(arquivoPath!);
  }

  Future<void> salvar() async {
    if (arquivoPath == null) return;
    try {
      await File(arquivoPath!).writeAsString(serializar());
      ultimaGravacao = DateTime.now();
      erroMensagem = null;
    } catch (e) {
      erroMensagem = 'Erro ao salvar: $e';
    }
    notifyListeners();
  }

  // MARK: - CRUD

  Future<void> adicionar(Livro livro) async {
    livros = [...livros, livro];
    await salvar();
  }

  Future<void> atualizar(Livro livro) async {
    livros = [
      for (final l in livros) l.id == livro.id ? livro : l,
    ];
    await salvar();
  }

  Future<void> remover(String id) async {
    livros = livros.where((l) => l.id != id).toList();
    await salvar();
  }

  // MARK: - TSV

  List<Livro> parsear(String texto) {
    return texto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((linha) {
          final c = linha.split('\t');
          if (c.isEmpty || c[0].isEmpty) return null;
          return Livro(
            id: DateTime.now().microsecondsSinceEpoch.toString() +
                linha.hashCode.toString(),
            titulo: c[0],
            autores: c.length > 1 ? _split(c[1]) : [],
            temas: c.length > 2 ? _split(c[2]) : [],
            ano: c.length > 3 ? c[3] : '',
            emprestado: c.length > 4 && c[4] == '1',
            comentarios: c.length > 5 ? c[5] : '',
            local: c.length > 6 ? c[6] : '',
            grupoLiteratura: c.length > 7 && c[7].trim() == '1',
          );
        })
        .whereType<Livro>()
        .toList();
  }

  List<String> _split(String campo) {
    return campo
        .split(_sep)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String serializar() {
    return livros.map((l) {
      return [
        l.titulo,
        l.autores.join('; '),
        l.temas.join('; '),
        l.ano,
        l.emprestado ? '1' : '0',
        l.comentarios,
        l.local,
        l.grupoLiteratura ? '1' : '0',
      ].join('\t');
    }).join('\n');
  }
}
