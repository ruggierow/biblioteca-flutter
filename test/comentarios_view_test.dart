import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biblioteca/views/detalhe_view.dart';

/// O comentário dos livros do Kindle traz dois endereços rotulados. Na tela
/// aparece só o rótulo: a URL inteira não quebra linha e, no Samsung, empurrava
/// o resto da seção para fora — o segundo link ficava inalcançável.
void main() {
  const comentario =
      'Ler: https://read.amazon.com/?asin=B00LFTCMHO'
      ' | Kindle: kindle://book?action=open&asin=B00LFTCMHO';

  Future<void> desenhar(WidgetTester tester, String texto) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ComentariosView(texto: texto, titulo: 'O assassinato de Roger Ackroyd'),
      ),
    ));
  }

  testWidgets('mostra os rótulos e nenhum endereço', (tester) async {
    await desenhar(tester, comentario);

    // Os rótulos são widgets dentro do parágrafo; o resto é texto comum.
    // Medir os dois separadamente, e INTEIROS: o defeito de 08/10 deixava
    // "Le" antes de "Ler" e "Ki" antes de "Kindle", e um contains('Ler')
    // passava feliz por cima disso.
    final rotulos = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(rotulos, ['Ler', 'Kindle']);

    // Só o parágrafo EXTERNO: cada rótulo também é um parágrafo por dentro,
    // e somar os três devolvia "| LerKindle".
    final paragrafo = tester
        .widget<RichText>(find.byType(RichText).first)
        .text
        .toPlainText(includePlaceholders: false);
    expect(paragrafo.trim(), '|');
    expect(paragrafo, isNot(contains('read.amazon.com')));
    expect(paragrafo, isNot(contains('kindle://')));
  });

  testWidgets('sem rótulo, mostra o servidor', (tester) async {
    await desenhar(tester, 'veja https://www.exemplo.com.br/pagina');
    final textos = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .join(' ');
    expect(textos, contains('exemplo.com.br'));
    expect(textos, isNot(contains('/pagina')));
  });

  testWidgets('comentário sem link nenhum continua inteiro', (tester) async {
    await desenhar(tester, 'Livro emprestado para o João em 2019.');
    expect(find.textContaining('emprestado para o João'), findsOneWidget);
  });
}
