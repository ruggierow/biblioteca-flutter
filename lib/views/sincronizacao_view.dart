import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
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
            child: store.arquivoPath == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Nenhum arquivo vinculado',
                        style: TextStyle(color: bibMuted)),
                  )
                : Column(
                    children: [
                      _InfoRow(
                          label: 'Selecionado',
                          valor: store.arquivoPath!.split('/').last),
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
                  title: Text(store.arquivoPath == null
                      ? 'Selecionar biblioteca.txt'
                      : 'Trocar arquivo'),
                  onTap: () => _selecionarArquivo(context, store),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync, color: bibPrimary),
                  title: const Text('Recarregar arquivo'),
                  onTap: store.arquivoPath == null
                      ? null
                      : () => store.recarregarArquivo(),
                  contentPadding: EdgeInsets.zero,
                  textColor: store.arquivoPath == null ? bibMuted : null,
                  iconColor: store.arquivoPath == null ? bibMuted : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Instruções
          _Secao(
            titulo: 'Como sincronizar com outros dispositivos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Instrucao(
                  numero: '1',
                  texto:
                      'Coloque o biblioteca.txt em um serviço de nuvem (Google Drive, Dropbox, etc.).',
                ),
                SizedBox(height: 10),
                _Instrucao(
                  numero: '2',
                  texto:
                      'Aqui no Android, toque em "Selecionar arquivo" e aponte para esse arquivo na nuvem.',
                ),
                SizedBox(height: 10),
                _Instrucao(
                  numero: '↺',
                  texto:
                      'Antes de editar, toque em "Recarregar" para garantir que está com a versão mais recente.',
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result != null && result.files.single.path != null) {
      await store.vincularArquivo(result.files.single.path!);
    }
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
