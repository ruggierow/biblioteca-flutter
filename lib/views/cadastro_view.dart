import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/biblioteca_store.dart';
import '../models/livro.dart';
import '../services/isbn_service.dart';
import '../theme.dart';
import 'scanner_view.dart';

class CadastroView extends StatefulWidget {
  final Livro? livroEditando;
  final String? isbnInicial;

  const CadastroView({super.key, this.livroEditando, this.isbnInicial});

  @override
  State<CadastroView> createState() => _CadastroViewState();
}

class _CadastroViewState extends State<CadastroView> {
  final _tituloCtrl = TextEditingController();
  final _anoCtrl = TextEditingController();
  final _localCtrl = TextEditingController();
  final _comentariosCtrl = TextEditingController();
  final _isbnCtrl = TextEditingController();

  List<TextEditingController> _autoresCtrl = [TextEditingController()];
  List<TextEditingController> _temasCtrl = [TextEditingController()];

  bool _emprestado = false;
  bool _grupoLiteratura = false;
  bool _buscandoISBN = false;
  String _isbnStatus = '';
  bool _isbnSucesso = false;

  bool get _editando => widget.livroEditando != null;

  @override
  void initState() {
    super.initState();
    if (_editando) _preencherParaEdicao();
    if (widget.isbnInicial != null && widget.isbnInicial!.isNotEmpty) {
      _isbnCtrl.text = widget.isbnInicial!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _buscarISBN());
    }
  }

  @override
  void dispose() {
    for (final c in [_tituloCtrl, _anoCtrl, _localCtrl, _comentariosCtrl, _isbnCtrl,
        ..._autoresCtrl, ..._temasCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _preencherParaEdicao() {
    final l = widget.livroEditando!;
    _tituloCtrl.text = l.titulo;
    _anoCtrl.text = l.ano;
    _localCtrl.text = l.local;
    _comentariosCtrl.text = l.comentarios;
    _emprestado = l.emprestado;
    _grupoLiteratura = l.grupoLiteratura;
    _autoresCtrl = l.autores.isEmpty
        ? [TextEditingController()]
        : l.autores.map((s) => TextEditingController(text: s)).toList();
    _temasCtrl = l.temas.isEmpty
        ? [TextEditingController()]
        : l.temas.map((s) => TextEditingController(text: s)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<BibliotecaStore>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar livro' : 'Novo livro'),
        actions: [
          TextButton(
            onPressed: _tituloCtrl.text.trim().isEmpty ? null : () => _salvar(store),
            child: const Text('Salvar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ISBN
          _Secao(
            titulo: 'Buscar por ISBN',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _isbnCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'ISBN (10 ou 13 dígitos)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.barcode_reader, color: bibPrimary),
                      onPressed: () => _abrirScanner(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _buscandoISBN || _isbnCtrl.text.trim().isEmpty
                            ? null
                            : _buscarISBN,
                    icon: _buscandoISBN
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search),
                    label:
                        Text(_buscandoISBN ? 'Buscando…' : 'Buscar ISBN'),
                  ),
                ),
                if (_isbnStatus.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _isbnStatus,
                    style: TextStyle(
                        fontSize: 12,
                        color: _isbnSucesso ? bibAccent : bibDanger),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Dados do livro
          _Secao(
            titulo: 'Dados do livro',
            child: Column(
              children: [
                _buildTextField(_tituloCtrl, 'Título'),
                const SizedBox(height: 8),
                _SugestoesCadastro(
                  sugestoes: _sugestoes(
                      store.livros.map((l) => l.titulo).toList(),
                      _tituloCtrl.text),
                  onSelecionar: (s) =>
                      setState(() => _tituloCtrl.text = s),
                ),
                const SizedBox(height: 8),
                _buildTextField(_anoCtrl, 'Ano de publicação',
                    tipo: TextInputType.number),
                const SizedBox(height: 8),
                _buildTextField(_localCtrl, 'Local do exemplar'),
                const SizedBox(height: 8),
                _SugestoesCadastro(
                  sugestoes: _sugestoes(
                      store.livros.map((l) => l.local).toList(),
                      _localCtrl.text),
                  onSelecionar: (s) =>
                      setState(() => _localCtrl.text = s),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Autores
          _Secao(
            titulo: 'Autor(es)',
            child: Column(
              children: [
                for (int i = 0; i < _autoresCtrl.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                          child: _buildTextField(
                              _autoresCtrl[i], 'Nome do autor')),
                      if (_autoresCtrl.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: bibDanger),
                          onPressed: () => setState(
                              () => _autoresCtrl.removeAt(i)),
                        ),
                    ],
                  ),
                  _SugestoesCadastro(
                    sugestoes: _sugestoes(
                        store.livros.expand((l) => l.autores).toList(),
                        _autoresCtrl[i].text),
                    onSelecionar: (s) =>
                        setState(() => _autoresCtrl[i].text = s),
                  ),
                  const SizedBox(height: 4),
                ],
                TextButton.icon(
                  onPressed: () => setState(
                      () => _autoresCtrl.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar autor'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Temas
          _Secao(
            titulo: 'Tema(s)',
            child: Column(
              children: [
                for (int i = 0; i < _temasCtrl.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                          child: _buildTextField(_temasCtrl[i], 'Tema')),
                      if (_temasCtrl.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: bibDanger),
                          onPressed: () =>
                              setState(() => _temasCtrl.removeAt(i)),
                        ),
                    ],
                  ),
                  _SugestoesCadastro(
                    sugestoes: _sugestoes(
                        store.livros.expand((l) => l.temas).toList(),
                        _temasCtrl[i].text),
                    onSelecionar: (s) =>
                        setState(() => _temasCtrl[i].text = s),
                  ),
                  const SizedBox(height: 4),
                ],
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _temasCtrl.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar tema'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Extras
          _Secao(
            titulo: 'Extras',
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Emprestado'),
                  value: _emprestado,
                  onChanged: (v) => setState(() => _emprestado = v),
                  activeColor: bibPrimary,
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Grupo de literatura'),
                  value: _grupoLiteratura,
                  onChanged: (v) => setState(() => _grupoLiteratura = v),
                  activeColor: bibPrimary,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _comentariosCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Comentários'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label,
      {TextInputType tipo = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: tipo,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    );
  }

  List<String> _sugestoes(List<String> valores, String termo) {
    final t = termo.trim();
    if (t.length < 2) return [];
    final tn = _normalizar(t);
    final vistos = <String>{};
    return valores
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .where((v) => _normalizar(v).contains(tn))
        .where((v) {
          final chave = _normalizar(v);
          if (vistos.contains(chave)) return false;
          vistos.add(chave);
          return chave != tn;
        })
        .take(5)
        .toList()
      ..sort((a, b) => a.compareTo(b));
  }

  String _normalizar(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[àáâãä]'), 'a')
          .replaceAll(RegExp(r'[èéêë]'), 'e')
          .replaceAll(RegExp(r'[ìíîï]'), 'i')
          .replaceAll(RegExp(r'[òóôõö]'), 'o')
          .replaceAll(RegExp(r'[ùúûü]'), 'u')
          .replaceAll('ç', 'c')
          .replaceAll('ñ', 'n');

  void _salvar(BibliotecaStore store) {
    final autores = _autoresCtrl
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final temas = _temasCtrl
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final livro = (_editando ? widget.livroEditando! : Livro(id: UniqueKey().toString(), titulo: ''))
        .copyWith(
          titulo: _tituloCtrl.text.trim(),
          autores: autores,
          temas: temas,
          ano: _anoCtrl.text.trim(),
          comentarios: _comentariosCtrl.text,
          local: _localCtrl.text.trim(),
          emprestado: _emprestado,
          grupoLiteratura: _grupoLiteratura,
        );

    if (_editando) {
      store.atualizar(livro);
    } else {
      store.adicionar(livro);
    }
    Navigator.pop(context);
  }

  Future<void> _buscarISBN() async {
    setState(() {
      _buscandoISBN = true;
      _isbnStatus = '';
    });
    try {
      final r = await ISBNService.buscar(_isbnCtrl.text);
      if (r != null) {
        setState(() {
          if (r.titulo.isNotEmpty) _tituloCtrl.text = r.titulo;
          if (r.autores.isNotEmpty) {
            _autoresCtrl = r.autores.map((s) => TextEditingController(text: s)).toList();
          }
          if (r.temas.isNotEmpty) {
            _temasCtrl = r.temas.map((s) => TextEditingController(text: s)).toList();
          }
          if (r.ano.isNotEmpty) _anoCtrl.text = r.ano;
          if (r.comentarios.isNotEmpty && _comentariosCtrl.text.trim().isEmpty) {
            _comentariosCtrl.text = r.comentarios;
          }
          _isbnStatus = 'Preenchido com sucesso.';
          _isbnSucesso = true;
        });
      } else {
        setState(() {
          _isbnStatus = 'ISBN não encontrado em nenhuma base de dados.';
          _isbnSucesso = false;
        });
      }
    } on ISBNInvalidoException {
      setState(() {
        _isbnStatus = 'ISBN inválido (deve ter 10 ou 13 dígitos).';
        _isbnSucesso = false;
      });
    } catch (_) {
      setState(() {
        _isbnStatus = 'Erro ao buscar. Verifique a internet.';
        _isbnSucesso = false;
      });
    }
    setState(() => _buscandoISBN = false);
  }

  void _abrirScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerView(
          onScaneado: (isbn) {
            Navigator.pop(context);
            setState(() => _isbnCtrl.text = isbn);
            _buscarISBN();
          },
        ),
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

class _SugestoesCadastro extends StatelessWidget {
  final List<String> sugestoes;
  final ValueChanged<String> onSelecionar;
  const _SugestoesCadastro(
      {required this.sugestoes, required this.onSelecionar});

  @override
  Widget build(BuildContext context) {
    if (sugestoes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sugestoes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => ActionChip(
          label: Text(sugestoes[i]),
          onPressed: () => onSelecionar(sugestoes[i]),
        ),
      ),
    );
  }
}
