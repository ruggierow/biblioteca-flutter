import 'package:flutter/services.dart';

/// Versão do aplicativo, lida do pacote instalado.
///
/// POR QUE NÃO É UMA CONSTANTE NO CÓDIGO: uma constante mente na hora errada.
/// Ela só muda se alguém lembrar de mudá-la, e é exatamente quando se está
/// caçando um defeito que se precisa confiar nela. Perguntar ao sistema qual
/// pacote está rodando não tem como estar errado.
///
/// Formato: "1.9.0 (7)" — o número entre parênteses é o build, que muda a cada
/// APK mesmo quando a versão não muda.
class VersaoApp {
  VersaoApp._();

  static const _canal = MethodChannel('biblioteca/app');
  static String? _cache;

  static Future<String> obter() async {
    if (_cache != null) return _cache!;
    try {
      _cache = await _canal.invokeMethod<String>('versao') ?? '';
    } catch (_) {
      _cache = ''; // a tela some, não quebra
    }
    return _cache!;
  }
}
