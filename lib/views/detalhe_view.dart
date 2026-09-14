import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/grupos_store.dart';
import '../models/livro.dart';
import '../services/foto_service.dart';
import '../theme.dart';
import 'cadastro_view.dart';

class DetalheView extends StatefulWidget {
  final Livro livro;
  const DetalheView({super.key, required this.livro});

  @override
  State<DetalheView> createState() => _DetalheViewState();
}

class _DetalheViewState extends State<DetalheView> {
  Uint8List? _capa;

  @override
  void initState() {
    super.initState();
    _carregarCapa();
  }

  Future<void> _carregarCapa() async {
    final bytes = await FotoService.shared
        .carregar(livroId: widget.livro.fotoId);
    if (bytes != null && mounted) setState(() => _capa = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final livro = widget.livro;
    return Scaffold(
      appBar: AppBar(
        title: Text(livro.titulo, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => CadastroView(livroEditando: livro)),
            ),
            child: const Text('Editar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Foto da capa
          _CapaSection(capa: _capa),
          const SizedBox(height: 12),

          _Secao(
            titulo: 'Identificação',
            child: Column(
              children: [
                _InfoRow(label: 'Título', valor: livro.titulo),
                if (livro.ano.isNotEmpty)
                  _InfoRow(label: 'Ano', valor: livro.ano),
                if (livro.local.isNotEmpty)
                  _InfoRow(label: 'Local', valor: livro.local),
              ],
            ),
          ),

          if (livro.autores.where((a) => a.isNotEmpty).isNotEmpty) ...[
            const SizedBox(height: 12),
            _Secao(
              titulo: 'Autor(es)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: livro.autores
                    .where((a) => a.isNotEmpty)
                    .map((a) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(a,
                              style: const TextStyle(color: bibText)),
                        ))
                    .toList(),
              ),
            ),
          ],

          if (livro.temas.where((t) => t.isNotEmpty).isNotEmpty) ...[
            const SizedBox(height: 12),
            _Secao(
              titulo: 'Tema(s)',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: livro.temas
                    .where((t) => t.isNotEmpty)
                    .map((t) => Chip(label: Text(t)))
                    .toList(),
              ),
            ),
          ],

          const SizedBox(height: 12),
          _Secao(
            titulo: 'Status',
            child: Column(
              children: [
                _InfoRow(
                    label: 'Emprestado',
                    valor: livro.emprestado ? 'Sim' : 'Não',
                    valorCor: livro.emprestado ? bibDanger : bibAccent),
                _InfoRow(
                    label: 'Grupo de literatura',
                    valor: livro.listaGrupos.isEmpty
                        ? 'Não'
                        : livro.listaGrupos
                            .map(GruposStore.shared.nome)
                            .join(', ')),
              ],
            ),
          ),

          if (livro.comentarios.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Secao(
              titulo: 'Comentários',
              child: _ComentariosView(texto: livro.comentarios),
            ),
          ],
        ],
      ),
    );
  }
}

class _CapaSection extends StatelessWidget {
  final Uint8List? capa;
  const _CapaSection({required this.capa});

  @override
  Widget build(BuildContext context) {
    if (capa != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(capa!,
            width: double.infinity,
            fit: BoxFit.contain),
      );
    }
    // Placeholder para livros sem foto
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 52, color: Color(0xFF2B5FB3)),
          SizedBox(height: 8),
          Text('Sem foto da capa',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _Secao({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: bibMuted,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: bibBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String valor;
  final Color? valorCor;
  const _InfoRow({required this.label, required this.valor, this.valorCor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(color: bibMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(valor,
                style: TextStyle(
                    color: valorCor ?? bibText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _ComentariosView extends StatelessWidget {
  final String texto;
  const _ComentariosView({required this.texto});

  @override
  Widget build(BuildContext context) {
    // Detecta URLs simples para tornar clicáveis
    final urlRegex = RegExp(
        r'https?://[^\s]+|www\.[^\s]+',
        caseSensitive: false);
    final matches = urlRegex.allMatches(texto);

    if (matches.isEmpty) {
      return SelectableText(texto,
          style: const TextStyle(color: bibText, fontSize: 14));
    }

    final spans = <InlineSpan>[];
    int ultimo = 0;
    for (final m in matches) {
      if (m.start > ultimo) {
        spans.add(TextSpan(text: texto.substring(ultimo, m.start)));
      }
      final url = m.group(0)!;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => launchUrl(
              Uri.parse(url.startsWith('http') ? url : 'https://$url')),
          child: Text(url,
              style: const TextStyle(
                  color: bibPrimary, decoration: TextDecoration.underline)),
        ),
      ));
      ultimo = m.end;
    }
    if (ultimo < texto.length) {
      spans.add(TextSpan(text: texto.substring(ultimo)));
    }

    return Text.rich(
      TextSpan(
          children: spans,
          style: const TextStyle(color: bibText, fontSize: 14)),
    );
  }
}
