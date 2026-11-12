import 'package:flutter/material.dart';

import '../models/biblioteca_store.dart';
import '../models/idioma.dart';
import '../theme.dart';

/// O fluxo de "Selecionar pasta" — o mesmo nas quatro plataformas.
///
/// Mora num arquivo só porque DOIS lugares o chamam: a linha nova da tela
/// inicial e o "Trocar pasta" da Sincronização. Duplicá-lo seria recriar o
/// problema que esta mudança existe para resolver — dois caminhos para a
/// mesma coisa, divergindo com o tempo.
///
/// Os quatro ramos, e a razão de cada um:
///
///  A. a pasta TEM biblioteca.txt  → mostra quantos livros achou e confirma.
///     Perguntar "quer usar o arquivo?" sem dizer o que há dentro é pedir um
///     palpite; com a contagem, é uma pergunta respondível.
///  B. a pasta está VAZIA          → cria e avisa, sem perguntar. O usuário
///     acabou de escolher aquela pasta com essa finalidade.
///  C. tem arquivo e não leu       → diz o que houve e oferece outra pasta.
///     NUNCA cria por cima: pode ser a biblioteca de alguém, ilegível por
///     permissão ou ainda baixando da nuvem.
///  D. vazia, mas há livros abertos → pergunta. É o único caso com algo a
///     perder, e a resposta muda o que vai para o disco.
Future<void> selecionarPasta(
    BuildContext context, BibliotecaStore store) async {
  while (true) {
    final conteudo = await store.escolherPastaEOlhar();
    if (conteudo == null) return; // cancelou o seletor: nada muda
    if (!context.mounted) return;

    // C — há arquivo e não deu para ler.
    if (conteudo.erroDeLeitura != null) {
      final tentarOutra = await _perguntar(
        context,
        titulo: t('naoConsegueLerTitulo'),
        corpo: t('naoConsegueLer', [conteudo.erroDeLeitura!]),
        confirmar: t('escolherOutraPasta'),
      );
      if (tentarOutra != true) return;
      continue; // volta ao seletor
    }

    // A — há biblioteca: mostra a contagem e confirma.
    if (conteudo.temArquivo) {
      final usar = await _perguntar(
        context,
        titulo: t('achouBiblioteca'),
        corpo: t('achouBibliotecaCorpo', [conteudo.pasta, conteudo.livros]),
        confirmar: t('usarEstaBiblioteca'),
        recusar: t('escolherOutraPasta'),
      );
      if (usar == null) return; // fechou a caixa: fica como está
      if (!usar) continue; // quer outra pasta
      await store.usarArquivoDaPasta();
      return;
    }

    // D — vazia, com livros abertos: a única pergunta com algo a perder.
    var levar = false;
    if (store.livros.isNotEmpty) {
      final n = store.livros.length;
      final resposta = await _perguntar(
        context,
        titulo: t('pastaVaziaComLivros', [n]),
        corpo: null,
        confirmar: t('levarParaPasta', [n]),
        recusar: t('comecarVazia'),
      );
      if (resposta == null) return; // fechou a caixa: não escreve nada
      levar = resposta;
    }

    // B — cria, vincula e avisa.
    final criou = await store.criarArquivoNaPasta(levarLivros: levar);
    if (!context.mounted) return;
    if (criou) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('criouArquivo', [conteudo.pasta]))),
      );
    }
    return;
  }
}

/// Caixa de duas (ou uma) saídas.
///
/// Devolve `true` no [confirmar], `false` no [recusar] e **null** quando o
/// usuário fecha sem escolher — e os três são desfechos diferentes: fechar
/// não pode valer por "não", porque aqui o "não" escreve no disco.
Future<bool?> _perguntar(
  BuildContext context, {
  required String titulo,
  required String? corpo,
  required String confirmar,
  String? recusar,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: corpo == null ? null : Text(corpo),
      actions: [
        if (recusar != null)
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(recusar, style: const TextStyle(color: bibMuted))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmar,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    ),
  );
}
