// A nona coluna (pais) entra em DUAS etapas, e esta versao e a primeira: o
// aplicativo aprende a ler e a DEVOLVER o campo, sem ainda mostrar nada.
//
// Por que a ordem importa: ate a 1.9.13 o motor-web descartava EM SILENCIO a
// linha com 9 colunas. Como o Mac salva sozinho, o dado entrando antes faria a
// biblioteca abrir vazia e o vazio ser gravado por cima.
import 'package:flutter_test/flutter_test.dart';
import 'package:biblioteca/models/biblioteca_store.dart';
import 'package:biblioteca/models/livro.dart';

void main() {
  final store = BibliotecaStore();

  test('linha de 9 campos traz o pais', () {
    final l = store.parsear('Com Pais\tAutor\tTema\t2020\t0\t\tEstante\t0\tBR');
    expect(l, hasLength(1));
    expect(l.first.pais, 'BR');
  });

  test('linha de 8 campos continua valendo, com pais vazio', () {
    final l = store.parsear('Sem Pais\tAutor\tTema\t2020\t0\t\tEstante\t0');
    expect(l, hasLength(1));
    expect(l.first.pais, '');
  });

  test('ida e volta preserva o pais', () {
    store.livros = store.parsear('Ida\tAutor\tTema\t2020\t0\tnota\tEstante\t0\tJP');
    final texto = store.serializar();
    expect(texto, 'Ida\tAutor\tTema\t2020\t0\tnota\tEstante\t0\tJP');
    expect(store.parsear(texto).first.pais, 'JP');
  });

  test('sem pais, a linha sai com 8 colunas', () {
    store.livros = store.parsear('Sem\tAutor\tTema\t2020\t0\t\tEstante\t0');
    expect(store.serializar().split('\t'), hasLength(8));
  });

  test('o codigo e guardado em maiusculas', () {
    expect(store.parsear('X\tA\tT\t2020\t0\t\tE\t0\tbr').first.pais, 'BR');
  });

  test('base mista de 8 e 9 colunas nao perde livro', () {
    store.livros = store.parsear(
        'Com\tA\tT\t2020\t0\t\tE\t0\tBR\nSem\tA\tT\t2021\t0\t\tE\t0');
    expect(store.livros, hasLength(2));
    expect(store.parsear(store.serializar()).map((l) => l.pais), ['BR', '']);
  });

  // Sem isto, editar qualquer campo no aparelho apagaria o pais: o copyWith
  // reconstroi o livro inteiro e o que nao for copiado volta ao padrao.
  test('copyWith PRESERVA o pais ao mexer noutro campo', () {
    final l = store.parsear('X\tA\tT\t2020\t0\t\tE\t0\tPT').first;
    expect(l.copyWith(local: 'Outra estante').pais, 'PT');
    expect(l.copyWith(emprestado: true).pais, 'PT');
  });
}
