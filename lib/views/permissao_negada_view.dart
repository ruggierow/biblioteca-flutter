import 'package:flutter/material.dart';
import '../services/permissoes.dart';
import '../theme.dart';

/// Para que serve a câmera na tela que pediu a permissão.
/// Muda o texto explicativo e se existe alternativa sem câmera.
enum UsoDaCamera {
  scanner(
    'Para escanear o código de barras, permita o acesso à câmera nas '
        'configurações do dispositivo.',
  ),
  capa(
    'Para fotografar a capa, permita o acesso à câmera nas configurações '
        'do dispositivo.',
  );

  const UsoDaCamera(this.explicacao);
  final String explicacao;
}

/// Tela exibida quando a câmera está negada ou restrita.
/// Mesma aparência e mesmos textos do equivalente iOS
/// (`Views/PermissaoNegadaView.swift`). Especificação: `comum/permissoes.md`.
class PermissaoNegadaView extends StatelessWidget {
  final UsoDaCamera uso;
  final EstadoPermissao estado;

  /// Só o scanner tem alternativa sem câmera.
  final VoidCallback? onDigitarISBN;
  final VoidCallback onCancelar;

  const PermissaoNegadaView({
    super.key,
    required this.uso,
    required this.estado,
    required this.onCancelar,
    this.onDigitarISBN,
  });

  String get _explicacao => estado == EstadoPermissao.restrita
      ? 'O acesso à câmera está bloqueado neste dispositivo.'
      : uso.explicacao;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white54, size: 72),
            const SizedBox(height: 20),
            const Text(
              'Acesso à câmera negado',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _explicacao,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Não adianta oferecer Configurações quando a permissão é restrita.
            if (estado.adiantaAbrirConfiguracoes)
              ElevatedButton.icon(
                onPressed: Permissoes.abrirConfiguracoes,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Abrir Configurações'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bibPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),

            if (onDigitarISBN != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onDigitarISBN,
                child: const Text('Digitar ISBN',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],

            const SizedBox(height: 12),
            TextButton(
              onPressed: onCancelar,
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
