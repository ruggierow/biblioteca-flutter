import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme.dart';

class ScannerView extends StatefulWidget {
  final ValueChanged<String> onScaneado;

  const ScannerView({super.key, required this.onScaneado});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  final _ctrl = MobileScannerController();
  bool _escaneado = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
