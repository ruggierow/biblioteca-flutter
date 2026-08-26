import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/biblioteca_store.dart';
import '../models/livro.dart';
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

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BibliotecaStore>();
    final filtrados = _filtrar(store.livros, _busca);
    final contagem = _busca.isEmpty
        ? '${filtrados.length} ${filtrados.length == 1 ? 'livro' : 'livros'}'
        : '${filtrados.length} ${filtrados.length == 1 ? 'livro encontrado' : 'livros encontrados'}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesquisa'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _buscaCtrl,
              onChanged: (v) => setState(() => _busca = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por título, autor, tema, ano ou status…',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _busca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () =>
                            setState(() { _buscaCtrl.clear(); _busca = ''; }),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
      ),
      body: filtrados.isEmpty
          ? Center(
              child: Text(
                _busca.isEmpty
                    ? 'Nenhum livro cadastrado'
                    : 'Nenhum resultado',
                style: const TextStyle(color: bibMuted, fontSize: 16),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(contagem,
                      style: const TextStyle(
                          color: bibMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: ListView.separated(
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
                              content: Text(
                                  'Remover "${livro.titulo}" da biblioteca?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancelar')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
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
                                  fontWeight: FontWeight.w600,
                                  color: bibText)),
                          subtitle: _subtitulo(livro),
                          trailing: const Icon(Icons.chevron_right,
                              color: bibMuted),
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
    if (busca.trim().isEmpty) return livros;
    final termo = _normalizar(busca.trim());
    return livros.where((l) => _corresponde(l, termo)).toList();
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
