import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/biblioteca_store.dart';
import '../services/capas_dat_service.dart';
import '../services/vinculo_pasta.dart';
import '../theme.dart';
import '../models/idioma.dart';

class SincronizacaoView extends StatefulWidget {
  const SincronizacaoView({super.key});

  @override
  State<SincronizacaoView> createState() => _SincronizacaoViewState();
}

class _SincronizacaoViewState extends State<SincronizacaoView> {
  String? _capasNome;
  bool _sincronizando = false;
  String? _resultadoSync;

  @override
  void initState() {
    super.initState();
    _carregarEstadoCapas();
  }

  /// As capas saem da MESMA pasta do biblioteca.txt: não há mais vínculo
  /// próprio para o .dat, só a pergunta de se ele está lá.
  Future<void> _carregarEstadoCapas() async {
    final n = await CapasDatService.shared.nome;
    if (mounted) setState(() => _capasNome = n);
  }

  Future<void> _sincronizar() async {
    if (_sincronizando) return;
    setState(() { _sincronizando = true; _resultadoSync = null; });

    final store = context.read<BibliotecaStore>();
    final fotoIds = store.livros.map((l) => l.fotoId).toSet();

    try {
      final copiados = await CapasDatService.shared.sincronizar(fotoIds);
      if (mounted) {
        setState(() {
          _resultadoSync = copiados == 0
              ? t('nenhumaFotoNova')
              : t('fotosCopiadas', [
                  copiados,
                  copiados == 1
                      ? t('umaFotoCopiada')
                      : t('variasFotosCopiadas'),
                ]);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _resultadoSync = t('erroGenerico', [e]));
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BibliotecaStore>();

    return Scaffold(
      appBar: AppBar(title: Text(t('sincronizacao'))),
        // Android 15 impoe o modo borda a borda para quem mira o SDK 35+: o
        // app desenha POR BAIXO da barra de navegacao e cabe a ele reservar o
        // espaco. Sem isto, a ultima secao fica debaixo da barra e a lista nem
        // rola — ela acha que o conteudo coube. Medido no Galaxy A57 em
        // 08/10/2026: os links do comentario apareciam e nao aceitavam toque.
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          // Status do arquivo
          _Secao(
            titulo: t('arquivo'),
            child: store.arquivoNome == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(t('nenhumArquivoVinculado'),
                        style: const TextStyle(color: bibMuted)),
                  )
                : Column(
                    children: [
                      _InfoRow(label: t('selecionado'), valor: store.arquivoNome!),
                      _InfoRow(label: t('livrosCarregadosRotulo'), valor: '${store.livros.length}'),
                      if (store.ultimaRecarga != null)
                        _InfoRow(label: t('recarregado'), valor: _hora(store.ultimaRecarga!)),
                      if (store.ultimaGravacao != null)
                        _InfoRow(label: t('salvo'), valor: _hora(store.ultimaGravacao!)),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // Ações de arquivo
          _Secao(
            titulo: t('acoes'),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_open, color: bibPrimary),
                  title: Text(VinculoPasta.vinculada
                      ? t('trocarPasta')
                      : t('selecionarPasta')),
                  subtitle: VinculoPasta.nome == null
                      ? null
                      : Text(VinculoPasta.nome!,
                          style: const TextStyle(color: bibMuted, fontSize: 12)),
                  onTap: () => _selecionarPasta(context, store),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync, color: bibPrimary),
                  title: Text(t('recarregarArquivo')),
                  onTap: store.arquivoNome == null ? null : () => store.recarregarArquivo(),
                  contentPadding: EdgeInsets.zero,
                  textColor: store.arquivoNome == null ? bibMuted : null,
                  iconColor: store.arquivoNome == null ? bibMuted : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Fotos de capa
          _Secao(
            titulo: t('fotosDeCapa'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_capasNome == null) ...[
                  Text(
                    VinculoPasta.vinculada
                        ? t('semDatNaPasta')
                        : t('vinculePastaPrimeiro'),
                    style: const TextStyle(color: bibMuted, fontSize: 13),
                  ),
                ] else ...[
                  _InfoRow(label: t('arquivo'), valor: _capasNome!),
                  const SizedBox(height: 8),
                  if (_resultadoSync != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_resultadoSync!,
                          style: const TextStyle(color: bibPrimary, fontSize: 13)),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _sincronizando ? null : _sincronizar,
                          icon: _sincronizando
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.download),
                          label: Text(_sincronizando ? t('sincronizando') : t('sincronizarAgora')),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Instruções Google Drive
          _Secao(
            titulo: t('sincronizarViaDrive'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Instrucao(
                  numero: '1',
                  texto: t('passoDrive1'),
                ),
                const SizedBox(height: 10),
                _Instrucao(
                  numero: '2',
                  texto: t('passoDrive2'),
                ),
                const SizedBox(height: 10),
                _Instrucao(
                  numero: '3',
                  texto: t('passoDrive3'),
                ),
                const SizedBox(height: 10),
                _Instrucao(
                  numero: '↺',
                  texto: t('passoDrive4'),
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

  Future<void> _selecionarPasta(BuildContext context, BibliotecaStore store) async {
    await store.escolherEVincular();
    await _carregarEstadoCapas();
    if (mounted) setState(() {});
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
          Flexible(
            child: Text(valor,
                style: const TextStyle(
                    color: bibText, fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
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
          decoration: const BoxDecoration(color: bibPrimary, shape: BoxShape.circle),
          child: Center(
            child: Text(numero,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texto, style: const TextStyle(color: bibText, fontSize: 13)),
        ),
      ],
    );
  }
}
