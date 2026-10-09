// O ISBN entra no campo de comentarios, nao numa 9a coluna: o leitor do
// motor-web descarta linha com 9 campos e o livro sumiria no Mac e no Windows.
// Estes casos sao os mesmos provados no motor-web e no iPhone.
import 'package:flutter_test/flutter_test.dart';
import 'package:biblioteca/views/cadastro_view.dart';

void main() {
  test('campo vazio recebe so a marca', () {
    expect(comISBN('', '978-85-359-0277-8'), 'ISBN: 9788535902778');
  });

  test('anexa preservando o que ja estava la', () {
    expect(comISBN('Editora: Companhia das Letras', '9788535902778'),
        'Editora: Companhia das Letras | ISBN: 9788535902778');
  });

  test('reler o mesmo livro NAO duplica a marca', () {
    const antes = 'ISBN: 9788535902778';
    expect(comISBN(antes, '9788535902778'), antes);
  });

  test('reler com outro numero substitui, sem mexer no resto', () {
    expect(comISBN('Editora: X | ISBN: 1111111111', '9788535902778'),
        'Editora: X | ISBN: 9788535902778');
  });

  test('ISBN-10 terminado em X sobrevive', () {
    expect(comISBN('Ler: https://a | Kindle: kindle://b', '85-359-0277-x'),
        'Ler: https://a | Kindle: kindle://b | ISBN: 853590277X');
  });

  test('sem ISBN nao toca no comentario', () {
    expect(comISBN('Editora: X', ''), 'Editora: X');
  });
}
