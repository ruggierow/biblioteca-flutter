// Este arquivo era o teste de exemplo do `flutter create` — testava um contador
// que nunca existiu neste app, referenciando uma classe `MyApp` inexistente.
// Era o único erro do `flutter analyze` no projeto.
//
// No lugar dele, um teste do que de fato importa e não depende de tela: o
// parser e o serializador do TSV, que são o contrato compartilhado com o app do
// iPhone e com o motor web (ver comum/formato-tsv.md).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:biblioteca/models/biblioteca_store.dart';
import 'package:biblioteca/models/livro.dart';

void main() {
  // O construtor do store lê SharedPreferences para restaurar o vínculo;
  // sem o binding e sem valores simulados, ele lança num teste puro.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BibliotecaStore store;
  setUp(() => store = BibliotecaStore());

  group('TSV', () {
    test('lê as 8 colunas', () {
      final livros = store.parsear(
        'O Hobbit\tTolkien\tFantasia\t1937\t0\tótimo\testante 2\t1\n',
      );
      expect(livros.length, 1);
      final l = livros.first;
      expect(l.titulo, 'O Hobbit');
      expect(l.autores, ['Tolkien']);
      expect(l.temas, ['Fantasia']);
      expect(l.ano, '1937');
      expect(l.emprestado, isFalse);
      expect(l.comentarios, 'ótimo');
      expect(l.local, 'estante 2');
      expect(l.grupoLiteratura, isTrue);
    });

    test('aceita arquivos legados com menos colunas', () {
      // Compatibilidade retroativa: 5 a 7 colunas continuam válidas.
      final livros = store.parsear('Dom Casmurro\tMachado\tRomance\t1899\t1\n');
      expect(livros.length, 1);
      expect(livros.first.emprestado, isTrue);
      expect(livros.first.comentarios, '');
      expect(livros.first.grupoLiteratura, isFalse);
    });

    test('separa vários autores e temas por ponto e vírgula', () {
      final livros = store.parsear('Título\tA; B\tX; Y\t2000\t0\t\t\t0\n');
      expect(livros.first.autores, ['A', 'B']);
      expect(livros.first.temas, ['X', 'Y']);
    });

    test('ignora linhas em branco', () {
      expect(store.parsear('\n\n  \n').length, 0);
    });

    test('serializar e parsear preserva o conteúdo', () {
      store.livros = [
        const Livro(
          id: '1',
          titulo: 'Livro A',
          autores: ['Autor Um', 'Autor Dois'],
          temas: ['Tema'],
          ano: '2020',
          emprestado: true,
          comentarios: 'nota',
          local: 'sala',
          grupoLiteratura: true,
        ),
      ];
      final devolta = store.parsear(store.serializar());
      expect(devolta.length, 1);
      expect(devolta.first.titulo, 'Livro A');
      expect(devolta.first.autores, ['Autor Um', 'Autor Dois']);
      expect(devolta.first.emprestado, isTrue);
      expect(devolta.first.grupoLiteratura, isTrue);
    });
  });
}
