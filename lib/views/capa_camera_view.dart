import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Tela de confirmação exibida após o usuário fotografar a capa.
/// Retorna true se o usuário confirmar ("Usar capa") ou false/null se refizer.
class ConfirmacaoCapaPage extends StatelessWidget {
  final Uint8List bytes;
  const ConfirmacaoCapaPage({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Refazer',
              style: TextStyle(color: Colors.white70, fontSize: 15)),
        ),
        leadingWidth: 90,
        title: const Text('Confirmar foto',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usar capa',
                style: TextStyle(
                    color: bibPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
