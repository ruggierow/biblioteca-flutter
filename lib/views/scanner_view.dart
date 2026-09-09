import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/permissoes.dart';
import '../theme.dart';
import 'permissao_negada_view.dart';

class ScannerView extends StatefulWidget {
  final ValueChanged<String> onScaneado;

  const ScannerView({super.key, required this.onScaneado});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView>
    with WidgetsBindingObserver {
  final _ctrl = MobileScannerController();
  bool _escaneado = false;

  /// Nulo enquanto a permissão ainda não foi consultada.
  EstadoPermissao? _permissao;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificarPermissao();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // Voltou das Configurações: reconsulta e abre a câmera se agora pode.
    if (estado == AppLifecycleState.resumed) _verificarPermissao();
  }

  /// Consulta — e pede, na primeira vez — a permissão de câmera.
  /// Comportamento especificado em `comum/permissoes.md`.
  Future<void> _verificarPermissao() async {
    if (_permissao?.podeUsarCamera == true) return;
    final estado = await Permissoes.garantirCamera();
    if (mounted) setState(() => _permissao = estado);
  }

  @override
  Widget build(BuildContext context) {
    final permissao = _permissao;
    if (permissao != null && !permissao.podeUsarCamera) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: PermissaoNegadaView(
          uso: UsoDaCamera.scanner,
          estado: permissao,
          onDigitarISBN: () => Navigator.pop(context),
          onCancelar: () => Navigator.pop(context),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            errorBuilder: (context, error) {
              // Rede de seguranca: se o plugin recusar por permissao apesar da
              // checagem acima, cai na mesma tela em vez de mostrar erro cru.
              if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
                return PermissaoNegadaView(
                  uso: UsoDaCamera.scanner,
                  estado: EstadoPermissao.negada,
                  onDigitarISBN: () => Navigator.pop(context),
                  onCancelar: () => Navigator.pop(context),
                );
              }
              return _ErroCamara(
                mensagem: error.errorDetails?.message ?? 'Erro ao acessar câmera',
              );
            },
            onDetect: (capture) {
              if (_escaneado) return;
              final codigo = capture.barcodes.firstOrNull?.rawValue;
              if (codigo == null) return;
              _escaneado = true;
              widget.onScaneado(codigo);
            },
          ),

          // Mira
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: bibPrimary, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          // Instrução
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Aponte para o código de barras do livro',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),

          // Botão cancelar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErroCamara extends StatelessWidget {
  final String mensagem;
  const _ErroCamara({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Colors.white54, size: 72),
            const SizedBox(height: 20),
            const Text(
              'Câmera indisponível',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              mensagem,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
