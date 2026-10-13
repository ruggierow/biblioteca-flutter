// A tabela por país no celular — não mapa, por decisão do usuário em 12/10/2026:
// "no iPhone e no Android faça por tabela e não por mapa".
import 'package:flutter_test/flutter_test.dart';
import 'package:biblioteca/models/filtro_pesquisa.dart';
import 'package:biblioteca/models/livro.dart';
import 'package:biblioteca/models/paises.dart';

Livro livro(String titulo, {String pais = ''}) =>
    Livro(id: titulo, titulo: titulo, pais: pais);

void main() {
  group('Nomes dos países', () {
    test('traduz o código', () {
      expect(Paises.nome('BR'), 'Brasil');
      expect(Paises.nome('jp'), 'Japão');
    });

    // Um país fora da tabela tem de APARECER, para alguém notar e acrescentá-lo.
    // Sumir calado seria esconder um livro.
    test('código desconhecido aparece como ele mesmo', () {
      expect(Paises.nome('ZZ'), 'ZZ');
      expect(Paises.conhecido('ZZ'), isFalse);
    });

    test('vazio continua vazio', () => expect(Paises.nome('  '), ''));
  });

  group('Filtro por país', () {
    test('aceita só os livros do país escolhido', () {
      final f = FiltroPesquisa(pais: 'BR');
      expect(f.aceita(livro('Daqui', pais: 'BR')), isTrue);
      expect(f.aceita(livro('De fora', pais: 'JP')), isFalse);
      expect(f.aceita(livro('Sem pais')), isFalse);
    });

    test('compara sem se importar com maiúsculas', () {
      expect(FiltroPesquisa(pais: 'BR').aceita(livro('x', pais: 'br')), isTrue);
    });

    test('sem país escolhido, não filtra nada', () {
      final f = FiltroPesquisa();
      expect(f.aceita(livro('x', pais: 'JP')), isTrue);
      expect(f.aceita(livro('y')), isTrue);
    });

    test('conta como filtro ligado e aparece no resumo', () {
      final f = FiltroPesquisa(pais: 'PT');
      expect(f.ativo, isTrue);
      expect(f.quantosLigados, 1);
      expect(f.resumo((_) => ''), contains('Portugal'));
    });

    test('limpar desliga o país', () {
      final f = FiltroPesquisa(pais: 'PT')..limpar();
      expect(f.pais, '');
      expect(f.ativo, isFalse);
    });

    // Sem isto, abrir a folha de filtros e fechar perderia o país — a cópia é
    // o que a folha edita antes de confirmar.
    test('a cópia leva o país junto', () {
      expect(FiltroPesquisa(pais: 'IT').copia().pais, 'IT');
    });
  });
}
