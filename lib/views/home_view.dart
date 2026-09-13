import 'package:flutter/material.dart';

import '../services/versao_app.dart';
import 'package:provider/provider.dart';
import '../models/biblioteca_store.dart';
import '../theme.dart';
import 'cadastro_view.dart';
import 'pesquisa_view.dart';
import 'sincronizacao_view.dart';
import 'scanner_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BibliotecaStore>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [bibPrimary, Color(0xFFD8F3DC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Cabeçalho
              _HomeHeader(livrosCount: store.livros.length),
              const SizedBox(height: 16),

              // Botão scanner
              _Card(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: store.arquivoNome == null
                        ? null
                        : () => _abrirScanner(context),
                    icon: const Icon(Icons.barcode_reader),
                    label: const Text(
                      'Escanear livro',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: bibAccent,
                      disabledBackgroundColor: bibAccent.withOpacity(0.55),
                      disabledForegroundColor: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Menu principal
              _Card(
                child: Column(
                  children: [
                    _MenuRow(
                      icon: Icons.add_circle_outline,
                      titulo: 'Cadastro',
                      habilitado: store.arquivoNome != null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CadastroView()),
                      ),
                    ),
                    const Divider(height: 1),
                    _MenuRow(
                      icon: Icons.search,
                      titulo: 'Pesquisa',
                      habilitado: store.arquivoNome != null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PesquisaView()),
                      ),
                    ),
                    const Divider(height: 1),
                    _MenuRow(
                      icon: Icons.sync,
                      titulo: 'Sincronização',
                      habilitado: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SincronizacaoView()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Info do arquivo
              _Card(
                titulo: 'Arquivo',
                child: store.arquivoNome == null
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Nenhum arquivo vinculado',
                            style: TextStyle(color: bibMuted)),
                      )
                    : Column(
                        children: [
                          _InfoRow(
                              label: 'Selecionado',
                              valor: store.arquivoNome!),
                          _InfoRow(
                              label: 'Livros',
                              valor: '${store.livros.length}'),
                          if (store.ultimaRecarga != null)
                            _InfoRow(
                                label: 'Recarregado',
                                valor: _formatarHora(store.ultimaRecarga!)),
                          if (store.ultimaGravacao != null)
                            _InfoRow(
                                label: 'Salvo',
                                valor: _formatarHora(store.ultimaGravacao!)),
                        ],
                      ),
              ),

              // Erro
              if (store.erroMensagem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _Card(
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: bibDanger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(store.erroMensagem!,
                              style: const TextStyle(color: bibDanger)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => store.erroMensagem = null,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatarHora(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _abrirScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerView(
          onScaneado: (isbn) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CadastroView(isbnInicial: isbn)),
            );
          },
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final int livrosCount;
  const _HomeHeader({required this.livrosCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Biblioteca',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Cadastro, pesquisa e sincronização da sua base de livros.',
              style: TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.menu_book, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text('$livrosCount livros carregados',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const Spacer(),
              // Versao e build, lidos do pacote instalado. Discretos: servem
              // para saber o que esta rodando quando algo da errado.
              FutureBuilder<String>(
                future: VersaoApp.obter(),
                builder: (_, s) => Text(
                  s.data == null || s.data!.isEmpty ? '' : 'v.${s.data}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final String? titulo;
  const _Card({required this.child, this.titulo});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: titulo == null
            ? child
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo!,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: bibMuted,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  child,
                ],
              ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final bool habilitado;
  final VoidCallback onTap;
  const _MenuRow(
      {required this.icon,
      required this.titulo,
      required this.habilitado,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: habilitado ? bibPrimary : bibMuted),
      title: Text(titulo,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: habilitado ? bibText : bibMuted)),
      trailing: const Icon(Icons.chevron_right, color: bibMuted),
      onTap: habilitado ? onTap : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String valor;
  const _InfoRow({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: bibMuted, fontSize: 13)),
          Text(valor,
              style: const TextStyle(
                  color: bibText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
