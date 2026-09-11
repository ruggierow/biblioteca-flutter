import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/biblioteca_store.dart';
import '../theme.dart';

class SincronizacaoView extends StatelessWidget {
  const SincronizacaoView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BibliotecaStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sincronização')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status do arquivo
          _Secao(
            titulo: 'Arquivo',
            child: store.arquivoNome == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Nenhum arquivo vinculado',
                        style: TextStyle(color: bibMuted)),
                  )
                : Column(
                    children: [
                      _InfoRow(
                          label: 'Selecionado',
                          valor: store.arquivoNome!),
                      _InfoRow(
                          label: 'Livros carregados',
                          valor: '${store.livros.length}'),
                      if (store.ultimaRecarga != null)
                        _InfoRow(
                            label: 'Recarregado',
                            valor: _hora(store.ultimaRecarga!)),
                      if (store.ultimaGravacao != null)
                        _InfoRow(
                            label: 'Salvo', valor: _hora(store.ultimaGravacao!)),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // Ações
          _Secao(
            titulo: 'Ações',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_open, color: bibPrimary),
                  title: Text(store.arquivoNome == null
                      ? 'Selecionar biblioteca.txt'
                      : 'Trocar arquivo'),
                  onTap: () => _selecionarArquivo(context, store),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync, color: bibPrimary),
                  title: const Text('Recarregar arquivo'),
                  onTap: store.arquivoNome == null
                      ? null
                      : () => store.recarregarArquivo(),
                  contentPadding: EdgeInsets.zero,
                  textColor: store.arquivoNome == null ? bibMuted : null,
                  iconColor: store.arquivoNome == null ? bibMuted : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Instruções Google Drive
          _Secao(
            titulo: 'Sincronizar via Google Drive',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Instrucao(
                  numero: '1',
                  texto:
                      'No computador, mova o biblioteca.txt para a pasta do Google Drive e aguarde sincronizar.',
                ),
                SizedBox(height: 10),
                _Instrucao(
                  numero: '2',
                  texto:
                      'No app Google Drive do Android, encontre o biblioteca.txt, toque em ⋮ e selecione "Tornar disponível offline".',
                ),
                SizedBox(height: 10),
                _Instrucao(
                  numero: '3',
                  texto:
                      'Aqui em Sincronização, toque em "Selecionar arquivo", navegue até Drive no menu lateral e selecione o biblioteca.txt.',
                ),
                SizedBox(height: 10),
                _Instrucao(
                  numero: '↺',
                  texto:
                      'Antes de editar, toque em "Recarregar" se alterou a base em outro dispositivo. Evite editar simultaneamente em dois lugares.',
                ),
              ],
            ),
          ),
          if (store.erroMensagem != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bibDanger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: bibDanger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: bibDanger),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(store.erroMensagem!,
                            style: const TextStyle(color: bibDanger))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _hora(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _selecionarArquivo(
      BuildContext context, BibliotecaStore store) async {
    // Seletor do sistema (SAF). O file_picker devolvia o caminho de uma cópia
    // no cache do app — o que se editava não voltava para o arquivo original.
    await store.escolherEVincular();
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
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: bibBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ],
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
          Text(label, style: const TextStyle(color: bibMuted, fontSize: 13)),
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

class _Instrucao extends StatelessWidget {
  final String numero;
  final String texto;
  const _Instrucao({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: bibPrimary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(numero,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texto,
              style: const TextStyle(color: bibText, fontSize: 13)),
        ),
      ],
    );
  }
}
