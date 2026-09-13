import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/biblioteca_store.dart';
import '../models/livro.dart';
import '../services/foto_service.dart';
import '../theme.dart';
import 'detalhe_view.dart';

class PesquisaView extends StatefulWidget {
  const PesquisaView({super.key});

  @override
  State<PesquisaView> createState() => _PesquisaViewState();
}

class _PesquisaViewState extends State<PesquisaView> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';
  bool _soComFoto = false;
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
    final filtrados = _filtrar(store.livros, _busca);
    final contagem = _busca.isEmpty && !_soComFoto
        ? '${filtrados.length} ${filtrados.length == 1 ? 'livro' : 'livros'}'
        : '${filtrados.length} ${filtrados.length == 1 ? 'livro encontrado' : 'livros encontrados'}';

    return Scaffold(
      appBar: AppBar(title: const Text('Pesquisa')),
      body: Column(
        children: [
          // Campo de busca no corpo — teclado funciona corretamente
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _buscaCtrl,
              autofocus: false,
              onChanged: (v) => setState(() => _busca = v),
              decoration: InputDecoration(
                hintText: 'Buscar por título, autor, tema, ano ou status…',
                prefixIcon: const Icon(Icons.search, color: bibPrimary),
                suffixIcon: _busca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            setState(() { _buscaCtrl.clear(); _busca = ''; }),
                      )
                    : null,
              ),
            ),
          ),
          // Filtro de foto
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Com foto'),
                avatar: const Icon(Icons.photo, size: 16),
                selected: _soComFoto,
                onSelected: (v) => setState(() => _soComFoto = v),
                selectedColor: bibPrimary.withOpacity(0.15),
                checkmarkColor: bibPrimary,
                labelStyle: TextStyle(
                  color: _soComFoto ? bibPrimary : bibMuted,
                  fontSize: 13,
                ),
              ),
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
                      _busca.isEmpty ? 'Nenhum livro cadastrado' : 'Nenhum resultado',
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

  List<Livro> _filtrar(List<Livro> livros, String busca) {
    var resultado = livros;
    if (_soComFoto) {
      resultado = resultado.where((l) => _fotosExistentes.contains(l.fotoId)).toList();
    }
    if (busca.trim().isEmpty) return resultado;
    final termo = _normalizar(busca.trim());
    return resultado.where((l) => _corresponde(l, termo)).toList();
  }

  bool _corresponde(Livro l, String termo) {
    return _contem(l.titulo, termo) ||
        l.autores.any((a) => _contem(a, termo)) ||
        l.temas.any((t) => _contem(t, termo)) ||
        _contem(l.local, termo) ||
        _contem(l.ano, termo) ||
        _correspondeEmprestado(l, termo) ||
        _correspondeGrupo(l, termo);
  }

  bool _correspondeEmprestado(Livro l, String termo) {
    final opcoes = l.emprestado
        ? ['emprestado', 'emprestada', 'emprestimo']
        : ['nao emprestado', 'disponivel'];
    return opcoes.any((o) {
      final n = _normalizar(o);
      return n.contains(termo) || termo.contains(n);
    });
  }

  bool _correspondeGrupo(Livro l, String termo) {
    final opcoes = l.grupoLiteratura
        ? ['grupo', 'literatura', 'grupo de literatura']
        : ['sem grupo', 'fora do grupo'];
    return opcoes.any((o) {
      final n = _normalizar(o);
      return n.contains(termo) || termo.contains(n);
    });
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
