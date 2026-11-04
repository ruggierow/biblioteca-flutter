import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/biblioteca_store.dart';
import 'models/idioma.dart';
import 'theme.dart';
import 'views/home_view.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BibliotecaStore()),
        // `carregar()` resolve a escolha guardada e, na falta dela, o idioma
        // do aparelho. Enquanto nao volta, a interface fica em portugues, que
        // e a lingua-fonte do dicionario.
        ChangeNotifierProvider(create: (_) => Idioma()..carregar()),
      ],
      child: const BibliotecaApp(),
    ),
  );
}

class BibliotecaApp extends StatelessWidget {
  const BibliotecaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Observar o idioma AQUI, acima do MaterialApp, e o que faz a troca
    // alcancar a tela inteira: o app e reconstruido de cima.
    context.watch<Idioma>();
    return MaterialApp(
      title: 'Biblioteca',
      theme: appTheme,
      // SEM `const`, e isso nao e estilo. Widget constante e canonizado: a
      // cada reconstrucao vem o MESMO objeto, o Flutter compara, ve que nao
      // mudou e PULA a subarvore inteira. Com `const HomeView()` o seletor
      // trocava para PT e a tela continuava em ingles — verificado no
      // emulador em 04/11/2026, com a suite verde.
      // ignore: prefer_const_constructors
      home: HomeView(),
      debugShowCheckedModeBanner: false,
    );
  }
}
