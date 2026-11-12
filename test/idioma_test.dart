
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:biblioteca/models/biblioteca_store.dart';
import 'package:biblioteca/models/filtro_pesquisa.dart';
import 'package:biblioteca/models/grupos_store.dart';
import 'package:biblioteca/models/idioma.dart';
import 'package:biblioteca/models/paises.dart';
import 'package:biblioteca/main.dart';
import 'package:biblioteca/views/home_view.dart';

/// Os portões da tradução, espelhando o `10-idioma.spec.js` do motor-web.
///
/// O que eles guardam não é a redação — é a FALTA. Uma chave esquecida numa
/// das tabelas não quebra nada: o `t()` cai no português e a tela fica meio
/// traduzida, calada. Só um portão vê isso.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // O português é o padrão em teste (ver idioma.dart). Quem mexer nisso aqui
  // devolve como estava, senão contamina os outros arquivos de teste — eles
  // rodam no mesmo isolate e esperam português.
  tearDown(() => fixarIdioma('pt'));

  group('o dicionário', () {
    final pt = TEXTOS['pt']!;
    final en = TEXTOS['en']!;

    test('as duas tabelas existem e não estão vazias', () {
      // Zero chave lida é FALHA, não sucesso: um portão que não olha passa
      // verde. (A lição de bin/conferir-paises.py.)
      expect(pt.length, greaterThan(100));
      expect(en.length, pt.length);
    });

    test('nenhuma meia-tradução: as duas tabelas têm as MESMAS chaves', () {
      expect(pt.keys.toSet().difference(en.keys.toSet()), isEmpty,
          reason: 'chave só em português');
      expect(en.keys.toSet().difference(pt.keys.toSet()), isEmpty,
          reason: 'chave só em inglês');
    });

    test('nenhum texto vazio', () {
      for (final tabela in [pt, en]) {
        for (final e in tabela.entries) {
          expect(e.value.trim(), isNotEmpty, reason: e.key);
        }
      }
    });

    test('os ${'\$'}{n} de cada chave são os mesmos nos dois idiomas', () {
      // Se o inglês perde um ${0}, o valor não aparece na tela e ninguém vê:
      // a frase continua lendo bem, só sem o número.
      final r = RegExp(r'\$\{(\d+)\}');
      Set<String> marcas(String s) =>
          r.allMatches(s).map((m) => m.group(1)!).toSet();
      for (final k in pt.keys) {
        expect(marcas(en[k]!), equals(marcas(pt[k]!)), reason: k);
      }
    });

    test('só estas chaves são iguais nos dois idiomas', () {
      // Igualdade quase sempre é tradução esquecida. As legítimas entram aqui
      // uma a uma, e qualquer outra reprova.
      final iguais = pt.keys.where((k) => pt[k] == en[k]).toList()..sort();
      expect(iguais, equals(['extras', 'idiomaDica', 'status']));
    });
  });

  group('a escolha do idioma', () {
    test('português só quando o aparelho está em português', () {
      expect(idiomaDoAparelho(const Locale('pt', 'BR')), 'pt');
      expect(idiomaDoAparelho(const Locale('pt', 'PT')), 'pt');
      expect(idiomaDoAparelho(const Locale('PT')), 'pt');
      expect(idiomaDoAparelho(const Locale('en', 'US')), 'en');
      expect(idiomaDoAparelho(const Locale('es')), 'en');
      expect(idiomaDoAparelho(const Locale('fr', 'CA')), 'en');
    });

    test('o padrão é português, a língua-fonte', () {
      expect(idiomaAtual, 'pt');
    });

    test('chave desconhecida volta como ela mesma, não vazia', () {
      expect(t('istoNaoExiste'), 'istoNaoExiste');
    });

    test('t() troca os valores na ordem', () {
      expect(t('grupoNumero', [7]), 'Grupo 7');
      fixarIdioma('en');
      expect(t('grupoNumero', [7]), 'Group 7');
    });

    test('valor que falta sai vazio em vez de "null"', () {
      expect(t('grupoNumero'), 'Grupo ');
    });
  });

  group('os países', () {
    test('a tabela em inglês tem exatamente os mesmos códigos ISO', () {
      // As duas tabelas são escritas à mão, como as outras quatro de país
      // (bin/conferir-paises.py). Um código a mais ou a menos aqui faria um
      // país aparecer em português no meio da tela em inglês.
      //
      // Comparar os CONJUNTOS, e não o que `nome()` devolve: `nome()` cai no
      // português quando falta o inglês, e devolve "Moçambique" para `MZ` —
      // um teste que comparasse com o código ISO passaria verde. Medi isso:
      // apaguei MZ da tabela inglesa e a primeira versão deste portão não viu.
      expect(Paises.codigos.length, 47);
      expect(Paises.codigosIngles, equals(Paises.codigos));
    });

    test('só estes países se escrevem igual nos dois idiomas', () {
      // O conjunto de códigos bater não garante tradução: um valor copiado do
      // português passaria. Os que são legitimamente iguais entram aqui um a
      // um, e qualquer outro reprova.
      final iguais = <String>[];
      for (final c in Paises.codigos) {
        fixarIdioma('pt');
        final pt = Paises.nome(c);
        fixarIdioma('en');
        if (Paises.nome(c) == pt) iguais.add(c);
      }
      iguais.sort();
      expect(
          iguais,
          equals(
              ['AO', 'AR', 'CL', 'CN', 'CU', 'IL', 'PE', 'PT', 'SN']));
    });

    test('nome() segue o idioma em vigor', () {
      expect(Paises.nome('BR'), 'Brasil');
      expect(Paises.nome('ZA'), 'África do Sul');
      fixarIdioma('en');
      expect(Paises.nome('BR'), 'Brazil');
      expect(Paises.nome('ZA'), 'South Africa');
    });

    test('código fora da tabela continua aparecendo, nos dois idiomas', () {
      // Sumir calado esconderia um livro.
      expect(Paises.nome('XX'), 'XX');
      fixarIdioma('en');
      expect(Paises.nome('XX'), 'XX');
    });
  });

  group('os rótulos resolvidos na hora', () {
    test('o status do filtro acompanha o idioma', () {
      expect(FiltroStatus.emprestados.rotulo, 'Emprestados');
      fixarIdioma('en');
      expect(FiltroStatus.emprestados.rotulo, 'On loan');
    });

    test('o resumo do filtro acompanha o idioma', () {
      final f = FiltroPesquisa(
          status: FiltroStatus.emprestados, comFoto: true);
      expect(f.resumo((_) => 'x'), 'Emprestados · Com foto');
      fixarIdioma('en');
      expect(f.resumo((_) => 'x'), 'On loan · With photo');
    });

    test('o nome do grupo padrão acompanha o idioma', () {
      // Ele mora numa CONSTANTE (`Grupo.doDicionario`), que guarda a chave e
      // não o texto: sem isso o nome ficaria congelado na língua do arranque.
      expect(GruposStore.shared.nome(1), 'Grupo de Literatura');
      expect(GruposStore.shared.nome(97), 'Grupo 97');
      fixarIdioma('en');
      expect(GruposStore.shared.nome(1), 'Reading Group');
      expect(GruposStore.shared.nome(97), 'Group 97');
    });
  });

  group('a tela inicial', () {
    Future<void> desenhar(WidgetTester tester) async {
      // A janela PADRAO do teste e 800x600 logicos — deitada, e mais curta
      // que qualquer telefone. A tela inicial nao cabe nela, e o que fica
      // para fora NAO e construido: `find.text` nao acha, e o teste reprova
      // por um motivo que nao existe no aparelho.
      //
      // Medido em 12/11/2026, ao acrescentar a linha "Selecionar pasta": a
      // faixa do arquivo saiu da janela e dois testes cairam. O tamanho
      // abaixo e o do Pixel 9 do emulador (1080x2424 a 2.625).
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BibliotecaStore()),
          ChangeNotifierProvider(create: (_) => Idioma()),
        ],
        child: const MaterialApp(home: HomeView()),
      ));
      await tester.pump();
    }

    testWidgets('em português mostra português', (tester) async {
      await desenhar(tester);
      expect(find.text('Escanear livro'), findsOneWidget);
      expect(find.text('Selecionar pasta'), findsOneWidget);
      expect(find.text('Sincronização'), findsOneWidget);
      expect(find.text('Nenhum arquivo vinculado'), findsOneWidget);
    });

    testWidgets('em inglês mostra inglês, e nada de português sobra',
        (tester) async {
      fixarIdioma('en');
      await desenhar(tester);
      expect(find.text('Scan a book'), findsOneWidget);
      expect(find.text('Select folder'), findsOneWidget);
      expect(find.text('Sync'), findsOneWidget);
      expect(find.text('No file linked'), findsOneWidget);

      // O contrário importa tanto quanto: um rótulo esquecido ficaria em
      // português no meio da tela em inglês, e o teste de cima não veria.
      expect(find.text('Escanear livro'), findsNothing);
      expect(find.text('Selecionar pasta'), findsNothing);
      expect(find.text('Sincronização'), findsNothing);
      expect(find.text('Nenhum arquivo vinculado'), findsNothing);
    });

    testWidgets('o seletor mostra a língua em vigor e oferece as duas',
        (tester) async {
      await desenhar(tester);
      expect(find.text('PT'), findsOneWidget);

      await tester.tap(find.text('PT'));
      await tester.pumpAndSettle();
      expect(find.text('Português'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('trocar no seletor REDESENHA a tela, não só o rótulo',
        (tester) async {
      // Este monta o app INTEIRO (BibliotecaApp), não a HomeView solta, e
      // troca de verdade pelo seletor. Os testes de cima fixavam o idioma
      // ANTES de desenhar e por isso não viam o defeito que havia aqui: com
      // `home: const HomeView()`, o widget constante é canonizado, vem o
      // mesmo objeto a cada reconstrução e o Flutter PULA a subárvore —
      // o seletor virava EN e a tela ficava em português. Verificado no
      // emulador em 04/11/2026, com a suíte verde.
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BibliotecaStore()),
          ChangeNotifierProvider(create: (_) => Idioma()),
        ],
        child: const BibliotecaApp(),
      ));
      await tester.pump();
      expect(find.text('Escanear livro'), findsOneWidget);

      await tester.tap(find.text('PT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(find.text('EN'), findsOneWidget);
      expect(find.text('Scan a book'), findsOneWidget);
      expect(find.text('Escanear livro'), findsNothing);
    });
  });
}
