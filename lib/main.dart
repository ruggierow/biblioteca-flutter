import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/biblioteca_store.dart';
import 'theme.dart';
import 'views/home_view.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => BibliotecaStore(),
      child: const BibliotecaApp(),
    ),
  );
}

class BibliotecaApp extends StatelessWidget {
  const BibliotecaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biblioteca',
      theme: appTheme,
      home: const HomeView(),
      debugShowCheckedModeBanner: false,
    );
  }
}
