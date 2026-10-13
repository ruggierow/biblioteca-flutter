import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/biblioteca_store.dart';
import '../models/paises.dart';
import '../theme.dart';
import 'pesquisa_view.dart';

/// A tabela do acervo por país.
///
/// POR QUE TABELA E NÃO MAPA: decisão do usuário em 12/10/2026 — "no iPhone e no
/// Android faça por tabela e não por mapa". Mapa clicável com quase quarenta
/// países num polegar não funciona; no Mac e no Windows, onde há mouse e tela
/// larga, o mapa existe.
///
/// Tocar numa linha abre a Pesquisa já filtrada por aquele país.
class PaisesView extends StatelessWidget {
  const PaisesView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BibliotecaStore>();

    final contagem = <String, int>{};
    for (final l in store.livros) {
      final iso = l.pais.trim().toUpperCase();
      if (iso.isNotEmpty) contagem[iso] = (contagem[iso] ?? 0) + 1;
    }
    final ordenados = contagem.entries.toList()
      ..sort((a, b) {
        final porTamanho = b.value.compareTo(a.value);
        return porTamanho != 0 ? porTamanho : Paises.nome(a.key).compareTo(Paises.nome(b.key));
      });
    final comPais = contagem.values.fold<int>(0, (a, b) => a + b);
    final semPais = store.livros.length - comPais;
    final maior = ordenados.isEmpty ? 1 : ordenados.first.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Países')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              ordenados.isEmpty
                  ? 'Nenhum livro tem país ainda.'
                  : '$comPais ${comPais == 1 ? 'livro' : 'livros'} em '
                      '${ordenados.length} ${ordenados.length == 1 ? 'país' : 'países'}'
                      '${semPais > 0 ? ' · $semPais ainda sem país' : ''}',
              style: const TextStyle(color: bibMuted, fontSize: 14),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ordenados.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'O país vem do tema do livro ou do ISBN. '
                        'Leia o código de barras de um livro para começar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: bibMuted, fontSize: 15),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        0, 4, 0, 16 + MediaQuery.viewPaddingOf(context).bottom),
                    itemCount: ordenados.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) {
                      final e = ordenados[i];
                      return ListTile(
                        title: Text(Paises.nome(e.key),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6, right: 40),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: e.value / maior,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFE2E8F2),
                            ),
                          ),
                        ),
                        trailing: Text('${e.value}',
                            style: const TextStyle(
                                color: bibMuted, fontFeatures: [FontFeature.tabularFigures()])),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PesquisaView(paisInicial: e.key)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
