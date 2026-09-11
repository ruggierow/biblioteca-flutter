import 'package:permission_handler/permission_handler.dart';

/// Estado da permissão de câmera. Os quatro casos de `comum/permissoes.md`.
/// Espelha `EstadoPermissao` do app iOS (`Services/Permissoes.swift`).
enum EstadoPermissao {
  concedida,
  naoPerguntada,
  negada,

  /// Bloqueada por política de dispositivo — pedir não adianta.
  restrita;

  bool get podeUsarCamera => this == EstadoPermissao.concedida;

  /// Só faz sentido oferecer "Abrir Configurações" se o usuário puder mudar.
  bool get adiantaAbrirConfiguracoes => this == EstadoPermissao.negada;
}

/// Ponto único de consulta e pedido de permissão no app Android.
///
/// Existe para que o scanner de ISBN e a captura de capa se comportem igual —
/// antes, a captura de capa não checava nada e o seletor voltava vazio sem
/// explicação. Comportamento especificado em `comum/permissoes.md`.
class Permissoes {
  Permissoes._();

  static EstadoPermissao _traduzir(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return EstadoPermissao.concedida;
    if (s.isRestricted) return EstadoPermissao.restrita;
    return EstadoPermissao.negada;
  }

  /// Estado atual da câmera, sem perguntar nada ao usuário.
  static Future<EstadoPermissao> estadoDaCamera() async {
    final s = await Permission.camera.status;
    // No Android, "denied" também é o estado de quem nunca foi perguntado.
    if (s.isDenied && !s.isPermanentlyDenied) return EstadoPermissao.naoPerguntada;
    return _traduzir(s);
  }

  /// Consulta e, se o usuário nunca foi perguntado, pergunta.
  /// Retorna o estado final — nunca deixa em [EstadoPermissao.naoPerguntada].
  static Future<EstadoPermissao> garantirCamera() async {
    var s = await Permission.camera.status;
    if (s.isDenied && !s.isPermanentlyDenied) {
      s = await Permission.camera.request();
    }
    return _traduzir(s);
  }

  static Future<void> abrirConfiguracoes() => openAppSettings();
}
