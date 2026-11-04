import 'package:flutter/material.dart';
import '../services/permissoes.dart';
import '../theme.dart';
import '../models/idioma.dart';

/// Para que serve a câmera na tela que pediu a permissão.
/// Muda o texto explicativo e se existe alternativa sem câmera.
enum UsoDaCamera {
  scanner('permissaoScanner'),
  capa('permissaoFoto');

  const UsoDaCamera(this._chave);
  final String _chave;

  /// Resolvido na hora, nao guardado: o idioma pode mudar depois de o enum
  /// existir, e um texto gravado na constante ficaria na lingua antiga.
  String get explicacao => t(_chave);
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
      ? t('cameraBloqueada')
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
            Text(
              t('acessoCameraNegado'),
              style: const TextStyle(
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
                label: Text(t('abrirConfiguracoes')),
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
                child: Text(t('digitarIsbn'),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],

            const SizedBox(height: 12),
            TextButton(
              onPressed: onCancelar,
              child: Text(t('cancelar'),
                  style: const TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
