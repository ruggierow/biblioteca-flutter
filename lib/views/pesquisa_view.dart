import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/biblioteca_store.dart';
import '../models/filtro_pesquisa.dart';
import '../models/grupos_store.dart';
import '../models/livro.dart';
import '../services/foto_service.dart';
import '../theme.dart';
import 'detalhe_view.dart';
import 'filtros_sheet.dart';

class PesquisaView extends StatefulWidget {
  const PesquisaView({super.key});

  @override
  State<PesquisaView> createState() => _PesquisaViewState();
}

class _PesquisaViewState extends State<PesquisaView> {
  final _buscaCtrl = TextEditingController();
  final _filtro = FiltroPesquisa();
  Set<String> _fotosExistentes = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _carregarFotos();
  }

  Future<void> _carregarFotos() async {
    final livros = context.read<BibliotecaStore>().livros;
    final existentes = <String>{};
    for (final l in livros) {
      if (await FotoService.shared.existe(livroId: l.fotoId)) {
        existentes.add(l.fotoId);
      }
    }
    if (mounted) setState(() => _fotosExistentes = existentes);
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BibliotecaStore>();
    final filtrados = _filtrar(store.livros);
    final resumo = _filtro.resumo(GruposStore.shared.nome);
    final contagem = !_filtro.ativo
        ? '${filtrados.length} ${filtrados.length == 1 ? 'livro' : 'livros'}'
        : '${filtrados.length} ${filtrados.length == 1 ? 'livro encontrado' : 'livros encontrados'}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesquisa'),
        actions: [
          IconButton(
            tooltip: 'Filtros',
            icon: Icon(
              _filtro.quantosLigados > 0
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
              color: _filtro.quantosLigados > 0 ? bibPrimary : null,
            ),
            onPressed: () => _abrirFiltros(store.livros),
          ),
        ],
      ),
      body: Column(
        children: [
          // Campo de busca no corpo — teclado funciona corretamente
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _buscaCtrl,
              autofocus: false,
              onChanged: (v) => setState(() => _filtro.texto = v),
              decoration: InputDecoration(
                hintText: 'Buscar por título, autor, tema, local ou ano…',
                prefixIcon: const Icon(Icons.search, color: bibPrimary),
                suffixIcon: _filtro.texto.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _buscaCtrl.clear();
                          _filtro.texto = '';
                        }),
                      )
                    : null,
              ),
            ),
          ),
          // Resumo dos filtros ligados na folha
          if (resumo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(resumo,
                        style: const TextStyle(color: bibMuted, fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      final t = _filtro.texto;
                      _filtro.limpar();
                      _filtro.texto = t;
                    }),
                    child: const Text('Limpar'),
                  ),
                ],
              ),
            ),
          if (filtrados.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(contagem,
                    style: const TextStyle(
                        color: bibMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          Expanded(
            child: filtrados.isEmpty
                ? Center(
                    child: Text(
                      _filtro.ativo ? 'Nenhum resultado' : 'Nenhum livro cadastrado',
                      style: const TextStyle(color: bibMuted, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtrados.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) {
                      final livro = filtrados[i];
                      return Dismissible(
                        key: Key(livro.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: bibDanger,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Remover livro'),
                              content: Text('Remover "${livro.titulo}" da biblioteca?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancelar')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Remover',
                                        style: TextStyle(color: bibDanger))),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) =>
                            context.read<BibliotecaStore>().remover(livro.id),
                        child: ListTile(
                          title: Text(livro.titulo,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, color: bibText)),
                          subtitle: _subtitulo(livro),
                          trailing: const Icon(Icons.chevron_right, color: bibMuted),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DetalheView(livro: livro)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget? _subtitulo(Livro livro) {
    final partes = <String>[];
    final autores = livro.autores.where((a) => a.isNotEmpty).join('; ');
    if (autores.isNotEmpty) partes.add(autores);
    final temas = livro.temas.where((t) => t.isNotEmpty).join(', ');
    if (temas.isNotEmpty) partes.add(temas);
    if (partes.isEmpty) return null;
    return Text(partes.join('\n'),
        style: const TextStyle(color: bibMuted, fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis);
  }

  Future<void> _abrirFiltros(List<Livro> livros) async {
    final novo = await showModalBottomSheet<FiltroPesquisa>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => FiltrosSheet(
        filtro: _filtro,
        grupos: GruposStore.shared.oferecidos(livros),
      ),
    );
    if (novo == null) return;
    setState(() {
      _filtro.status = novo.status;
      _filtro.grupo = novo.grupo;
      _filtro.comFoto = novo.comFoto;
    });
  }

  List<Livro> _filtrar(List<Livro> livros) {
    var resultado = livros.where(_filtro.aceita).toList();
    if (_filtro.comFoto) {
      resultado =
          resultado.where((l) => _fotosExistentes.contains(l.fotoId)).toList();
    }
    final termo = _normalizar(_filtro.texto.trim());
    if (termo.isEmpty) return resultado;
    return resultado.where((l) => _corresponde(l, termo)).toList();
  }

  /// A caixa unica procura nos mesmos campos que as quatro caixas do Mac
  /// (titulo, autor, tema, local) mais o ano. Status e grupo saem daqui:
  /// eles tem seletor proprio na folha de filtros.
  bool _corresponde(Livro l, String termo) {
    return _contem(l.titulo, termo) ||
        l.autores.any((a) => _contem(a, termo)) ||
        l.temas.any((t) => _contem(t, termo)) ||
        _contem(l.local, termo) ||
        _contem(l.ano, termo);
  }

  bool _contem(String texto, String termo) =>
      _normalizar(texto).contains(termo);

  String _normalizar(String s) =>
      s.toLowerCase()
          .replaceAll(RegExp(r'[àáâãä]'), 'a')
          .replaceAll(RegExp(r'[èéêë]'), 'e')
          .replaceAll(RegExp(r'[ìíîï]'), 'i')
          .replaceAll(RegExp(r'[òóôõö]'), 'o')
          .replaceAll(RegExp(r'[ùúûü]'), 'u')
          .replaceAll('ç', 'c')
          .replaceAll('ñ', 'n');
}
