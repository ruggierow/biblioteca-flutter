import 'dart:convert';
import 'package:http/http.dart' as http;

class LivroISBN {
  final String titulo;
  final List<String> autores;
  final List<String> temas;
  final String ano;
  final String comentarios;

  const LivroISBN({
    required this.titulo,
    this.autores = const [],
    this.temas = const [],
    this.ano = '',
    this.comentarios = '',
  });
}

class ISBNInvalidoException implements Exception {}

class ISBNService {
  static Future<LivroISBN?> buscar(String isbn) async {
    final limpo = isbn.replaceAll('-', '').replaceAll(' ', '');
    if ((limpo.length != 10 && limpo.length != 13) ||
        !RegExp(r'^\d+$').hasMatch(limpo)) {
      throw ISBNInvalidoException();
    }

    final resultado = await _brasilAPI(limpo) ??
        await _googleBooks(limpo) ??
        await _openLibrary(limpo);
    return resultado;
  }

  static String _extrairAno(String str) {
    final match = RegExp(r'\d{4}').firstMatch(str);
    return match?.group(0) ?? '';
  }

  static Future<LivroISBN?> _brasilAPI(String isbn) async {
    try {
      final uri = Uri.parse('https://brasilapi.com.br/api/isbn/v1/$isbn');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final titulo = json['title'] as String? ?? '';
      if (titulo.isEmpty) return null;
      final autores = (json['authors'] as List?)?.cast<String>() ?? [];
      final temas =
          ((json['subjects'] as List?)?.cast<String>() ?? []).take(3).toList();
      final ano = _stringify(json['year']);
      final extras = <String>[];
      final subtitulo = json['subtitle'] as String? ?? '';
      if (subtitulo.isNotEmpty) extras.add(subtitulo);
      final editora = json['publisher'] as String? ?? '';
      if (editora.isNotEmpty) extras.add('Editora: $editora');
      return LivroISBN(
        titulo: titulo,
        autores: autores,
        temas: temas,
        ano: ano,
        comentarios: extras.join(' | '),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<LivroISBN?> _googleBooks(String isbn) async {
    try {
      final uri = Uri.parse(
          'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (json['items'] as List?)?.cast<Map<String, dynamic>>();
      if (items == null || items.isEmpty) return null;
      final info = items.first['volumeInfo'] as Map<String, dynamic>? ?? {};
      final titulo = info['title'] as String? ?? '';
      if (titulo.isEmpty) return null;
      final autores = (info['authors'] as List?)?.cast<String>() ?? [];
      final temas =
          ((info['categories'] as List?)?.cast<String>() ?? []).take(3).toList();
      final ano = _extrairAno(info['publishedDate'] as String? ?? '');
      final editora = info['publisher'] as String? ?? '';
      return LivroISBN(
        titulo: titulo,
        autores: autores,
        temas: temas,
        ano: ano,
        comentarios: editora.isNotEmpty ? 'Editora: $editora' : '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<LivroISBN?> _openLibrary(String isbn) async {
    try {
      final uri = Uri.parse(
          'https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final livro = json['ISBN:$isbn'] as Map<String, dynamic>?;
      if (livro == null) return null;
      final titulo = livro['title'] as String? ?? '';
      if (titulo.isEmpty) return null;
      final autores = ((livro['authors'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map((a) => a['name'] as String? ?? '')
              .where((n) => n.isNotEmpty)
              .toList()) ??
          [];
      final temas = ((livro['subjects'] as List?)
              ?.cast<Map<String, dynamic>>()
              .take(3)
              .map((s) => s['name'] as String? ?? '')
              .where((n) => n.isNotEmpty)
              .toList()) ??
          [];
      final ano = _extrairAno(livro['publish_date'] as String? ?? '');
      final editoras = ((livro['publishers'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map((p) => p['name'] as String? ?? '')
              .where((n) => n.isNotEmpty)
              .toList()) ??
          [];
      return LivroISBN(
        titulo: titulo,
        autores: autores,
        temas: temas,
        ano: ano,
        comentarios: editoras.isNotEmpty ? 'Editora: ${editoras.join(', ')}' : '',
      );
    } catch (_) {
      return null;
    }
  }

  static String _stringify(dynamic value) {
    if (value is String) return value;
    if (value is int) return value.toString();
    if (value is double) return value.toInt().toString();
    return '';
  }
}
