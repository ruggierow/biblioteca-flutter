import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O idioma da interface, e o dicionario.
///
/// Mesmo desenho do motor-web (`TEXTOS` + `t()` em biblioteca.html): o
/// dicionario mora no codigo, sem geracao e sem dependencia nova. Um gerador
/// de .arb para um app deste tamanho custaria mais do que paga — e o mesmo
/// argumento que `bin/conferir-paises.py` registra para as quatro tabelas de
/// pais escritas a mao.
///
///     t('chave')              texto simples
///     t('chave', [x, y])      troca ${0} e ${1}
///
/// A chave de preferencia e a MESMA do motor-web (`biblioteca-idioma`), para
/// que as duas implementacoes se leiam como uma so.
///
/// O PORTUGUES E A LINGUA-FONTE, e por isso tambem o padrao desta variavel.
/// Duas consequencias de proposito:
///
///   1. chave que falte em `en` cai no `pt` em vez de sumir da tela;
///   2. em teste, que nao chama `Idioma.carregar()`, a interface fica em
///      portugues. Sem isso os testes que ja existiam passariam a ler ingles
///      — o aparelho simulado do `flutter_test` responde `en-US` — e
///      reprovariam em massa. E o mesmo motivo do `locale: "pt-BR"` em
///      motor-web/testes/playwright.config.js.
const chaveIdiomaPref = 'biblioteca-idioma';

String _idioma = 'pt';

/// O idioma em vigor: `'pt'` ou `'en'`.
String get idiomaAtual => _idioma;

/// A regra da escolha automatica: portugues so quando o aparelho esta em
/// portugues; o resto do mundo ve ingles. Igual ao `/^pt\b/i` do motor-web.
String idiomaDoAparelho(Locale local) =>
    local.languageCode.toLowerCase() == 'pt' ? 'pt' : 'en';

/// O texto da chave no idioma em vigor, com `${0}`, `${1}`… substituidos.
///
/// Chave desconhecida volta como ela mesma, em vez de vazio: um texto faltando
/// tem de APARECER na tela para alguem notar — sumir calado esconderia o
/// defeito. Mesma decisao de `Paises.nome`, que devolve o codigo ISO.
String t(String chave, [List<Object?> valores = const []]) {
  final texto = TEXTOS[_idioma]?[chave] ?? TEXTOS['pt']![chave];
  if (texto == null) return chave;
  return texto.replaceAllMapped(RegExp(r'\$\{(\d+)\}'), (m) {
    final i = int.parse(m.group(1)!);
    final v = i < valores.length ? valores[i] : null;
    return v == null ? '' : '$v';
  });
}

/// Troca o idioma e redesenha a arvore inteira.
///
/// Vive acima do `MaterialApp` em main.dart: notificar daqui reconstroi todas
/// as telas de uma vez, inclusive as que estao empilhadas no Navigator.
class Idioma extends ChangeNotifier {
  String get atual => _idioma;

  /// Le a escolha guardada; na falta dela, segue o idioma do aparelho.
  Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString(chaveIdiomaPref);
    final novo = (salvo == 'pt' || salvo == 'en')
        ? salvo!
        : idiomaDoAparelho(PlatformDispatcher.instance.locale);
    if (novo != _idioma) {
      _idioma = novo;
      notifyListeners();
    }
  }

  Future<void> trocar(String novo) async {
    if (novo != 'pt' && novo != 'en') return;
    if (novo == _idioma) return;
    _idioma = novo;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(chaveIdiomaPref, novo);
  }
}

/// So para os testes do dicionario: fixa o idioma sem gravar preferencia.
@visibleForTesting
void fixarIdioma(String id) => _idioma = id;

// =====================================================================
// O DICIONARIO
// =====================================================================
// Uma entrada por chave, nos dois idiomas, na ordem das telas — a inicial
// primeiro, como quem abre o app.
//
// O texto em portugues e o que ja estava no codigo, palavra por palavra. O
// ingles foi copiado do motor-web onde a mesma ideia ja tinha traducao
// ("Where the copy is", "Reading group", "On loan"…), para as duas
// plataformas nao dizerem a mesma coisa de dois jeitos.
// O nome em maiusculas e de proposito: e o MESMO `TEXTOS` do
// motor-web, e as duas implementacoes devem se ler como uma so.
// ignore: constant_identifier_names
const TEXTOS = <String, Map<String, String>>{
  'pt': {
    // --- tela inicial ---
    'idiomaDica': 'Idioma / Language',
    'subtituloApp': 'Cadastro, pesquisa e sincronização da sua base de livros.',
    'livrosCarregados': '\${0} livros carregados',
    'escanearLivro': 'Escanear livro',
    'menuCadastro': 'Cadastro',
    'menuPaises': 'Países',
    'menuPesquisa': 'Pesquisa',
    'menuSincronizacao': 'Sincronização',
    'arquivo': 'Arquivo',
    'nenhumArquivoVinculado': 'Nenhum arquivo vinculado',
    'selecionado': 'Selecionado',
    'livros': 'Livros',
    'recarregado': 'Recarregado',
    'salvo': 'Salvo',

    // --- cadastro ---
    'editarLivro': 'Editar livro',
    'novoLivro': 'Novo livro',
    'salvar': 'Salvar',
    'buscarPorIsbn': 'Buscar por ISBN',
    'digitarIsbn': 'Digitar ISBN',
    'isbnDica': 'ISBN (10 ou 13 dígitos)',
    'fotoDaCapa': 'Foto da capa',
    'dadosDoLivro': 'Dados do livro',
    'titulo': 'Título',
    'anoDePublicacao': 'Ano de publicação',
    'localDoExemplar': 'Local do exemplar',
    'autores': 'Autor(es)',
    'nomeDoAutor': 'Nome do autor',
    'adicionarAutor': 'Adicionar autor',
    'temasRotulo': 'Tema(s)',
    'tema': 'Tema',
    'adicionarTema': 'Adicionar tema',
    'gruposDeLiteratura': 'Grupos de literatura',
    'extras': 'Extras',
    'emprestado': 'Emprestado',
    'comentarios': 'Comentários',
    'trocar': 'Trocar',
    'remover': 'Remover',
    'fotografarCapa': 'Fotografar capa',
    'camera': 'Câmera',
    'galeria': 'Galeria',
    'semPais': '— sem país —',
    'foraDaTabela': '\${0} (fora da tabela)',
    'pais': 'País',
    'preenchidoComSucesso': 'Preenchido com sucesso.',
    'isbnNaoEncontrado': 'ISBN não encontrado, mas o número foi guardado.',
    'isbnInvalido': 'ISBN inválido (deve ter 10 ou 13 dígitos).',
    'erroAoBuscar': 'Erro ao buscar. Verifique a internet.',

    // --- foto da capa ---
    'refazer': 'Refazer',
    'confirmarFoto': 'Confirmar foto',
    'usarCapa': 'Usar capa',

    // --- detalhe do livro ---
    'editar': 'Editar',
    'identificacao': 'Identificação',
    'ano': 'Ano',
    'local': 'Local',
    'status': 'Status',
    'sim': 'Sim',
    'nao': 'Não',
    'grupoDeLiteratura': 'Grupo de literatura',
    'semFotoDaCapa': 'Sem foto da capa',
    'tituloCopiado': 'Título copiado: \${0} — cole na busca do Kindle.',
    'appKindle': 'app Kindle',

    // --- filtros ---
    'filtros': 'Filtros',
    'limpar': 'Limpar',
    'todosOsLivros': 'Todos os livros',
    'qualquerGrupo': 'Qualquer grupo',
    'soLivrosComFoto': 'Só livros com foto',
    'pronto': 'Pronto',
    'statusTodos': 'Todos',
    'statusDisponiveis': 'Disponíveis',
    'statusEmprestados': 'Emprestados',
    'comFoto': 'Com foto',

    // --- grupos de literatura ---
    'grupoDeLiteraturaNome': 'Grupo de Literatura',
    'grupoNumero': 'Grupo \${0}',

    // --- paises ---
    'paises': 'Países',
    'nenhumLivroComPais': 'Nenhum livro tem país ainda.',
    'umLivro': 'livro',
    'variosLivros': 'livros',
    'umPais': 'país',
    'variosPaises': 'países',
    'acervoEmPaises': '\${0} \${1} em \${2} \${3}',
    'aindaSemPais': ' · \${0} ainda sem país',
    'paisVemDoTema': 'O país vem do tema do livro ou do ISBN. ',
    'leiaCodigoParaComecar':
        'Leia o código de barras de um livro para começar.',

    // --- permissao de camera ---
    'permissaoScanner': 'Para escanear o código de barras, permita o acesso à '
        'câmera nas configurações do dispositivo.',
    'permissaoFoto': 'Para fotografar a capa, permita o acesso à câmera nas '
        'configurações do dispositivo.',
    'cameraBloqueada': 'O acesso à câmera está bloqueado neste dispositivo.',
    'acessoCameraNegado': 'Acesso à câmera negado',
    'abrirConfiguracoes': 'Abrir Configurações',
    'cancelar': 'Cancelar',

    // --- pesquisa ---
    'pesquisa': 'Pesquisa',
    'buscarPlaceholder': 'Buscar por título, autor, tema, local ou ano…',
    'umLivroEncontrado': 'livro encontrado',
    'variosLivrosEncontrados': 'livros encontrados',
    'carregandoBiblioteca': 'Carregando a biblioteca…',
    'nenhumResultado': 'Nenhum resultado',
    'nenhumLivroCadastrado': 'Nenhum livro cadastrado',
    'removerLivro': 'Remover livro',
    'removerConfirma': 'Remover "\${0}" da biblioteca?',

    // --- scanner ---
    'erroAoAcessarCamera': 'Erro ao acessar câmera',
    'aponteParaCodigo': 'Aponte para o código de barras do livro',
    'cameraIndisponivel': 'Câmera indisponível',
    'voltar': 'Voltar',

    // --- selecionar pasta ---
    'selecionarPastaDica': 'Onde o seu biblioteca.txt está — ou vai ficar',
    'achouBiblioteca': 'Encontrei uma biblioteca nesta pasta',
    'achouBibliotecaCorpo':
        'A pasta "\${0}" já tem um biblioteca.txt com \${1} livro(s).',
    'usarEstaBiblioteca': 'Usar esta biblioteca',
    'escolherOutraPasta': 'Escolher outra pasta',
    'criouArquivo':
        'Criei o biblioteca.txt em "\${0}". Pode começar a cadastrar.',
    'naoConsegueLerTitulo': 'Não consegui ler esta biblioteca',
    'naoConsegueLer':
        'Há um biblioteca.txt nesta pasta, mas não consegui lê-lo: \${0}',
    'escolhaSubpasta': 'Escolha uma subpasta. O Android não deixa escolher '
        '"Meu Drive" nem a memória do telefone.',
    'pastaVaziaComLivros':
        'Esta pasta está vazia. O que fazer com os \${0} livros que estão '
        'abertos?',
    'comecarVazia': 'Criar uma biblioteca nova e vazia',
    'levarParaPasta': 'Levar os \${0} para esta pasta',

    // --- sincronizacao ---
    'sincronizacao': 'Sincronização',
    'nenhumaFotoNova': 'Nenhuma foto nova encontrada.',
    'umaFotoCopiada': 'foto copiada',
    'variasFotosCopiadas': 'fotos copiadas',
    'fotosCopiadas': '\${0} \${1} com sucesso.',
    'erroGenerico': 'Erro: \${0}',
    'livrosCarregadosRotulo': 'Livros carregados',
    'acoes': 'Ações',
    'trocarPasta': 'Trocar pasta',
    'selecionarPasta': 'Selecionar pasta',
    'recarregarArquivo': 'Recarregar arquivo',
    'fotosDeCapa': 'Fotos de capa',
    'semDatNaPasta': 'Não há um biblioteca.dat nesta pasta. É o arquivo em '
        'que o Mac e o iPhone guardam todas as capas; ele '
        'fica ao lado do biblioteca.txt.',
    'vinculePastaPrimeiro': 'Vincule a pasta primeiro. As capas vêm do '
        'biblioteca.dat que está dentro dela.',
    'sincronizando': 'Sincronizando…',
    'sincronizarAgora': 'Sincronizar agora',
    'sincronizarViaDrive': 'Sincronizar via Google Drive',
    'passoDrive1': 'No computador, ponha o biblioteca.txt e o biblioteca.dat '
        'numa pasta do Google Drive e aguarde sincronizar.',
    'passoDrive2': 'No app Google Drive do Android, encontre essa pasta, '
        'toque em ⋮ e selecione "Tornar disponível offline".',
    'passoDrive3': 'Aqui em Sincronização, toque em "Selecionar pasta", '
        'navegue até Drive no menu lateral e escolha a pasta. O Android não '
        'deixa escolher "Meu Drive" direto: tem de ser uma pasta dentro dele.',
    'passoDrive4': 'Antes de editar, toque em "Recarregar" se alterou a base '
        'em outro dispositivo. Evite editar simultaneamente em dois lugares.',

    // --- arquivo e erros do store ---
    'erroAoVincular': 'Erro ao vincular: \${0}',
    'pastaEscolhida': 'escolhida',
    'semArquivoNaPasta': 'Não há um \${0} na pasta "\${1}". '
        'Escolha a pasta onde o arquivo está.',
    'erroAoCriarArquivo': 'Não foi possível criar o arquivo nesta pasta: \${0}',
    'naoFoiPossivelCarregar': 'Não foi possível carregar o arquivo vinculado. '
        'Toque em Selecionar arquivo para vinculá-lo de novo.',
    'agoraVinculaPasta': 'Agora a Biblioteca vincula a PASTA inteira, e não '
        'cada arquivo. Toque em Selecionar pasta e escolha a pasta onde está '
        'o biblioteca.txt — o biblioteca.dat vem junto.',
    'erroAoCarregar': 'Erro ao carregar: \${0}',
    'erroAoSalvar': 'Erro ao salvar: \${0}',
    'naoParecebibliotecaDat':
        'O arquivo escolhido não parece ser o biblioteca.dat.',
  },
  'en': {
    // --- tela inicial ---
    'idiomaDica': 'Idioma / Language',
    'subtituloApp': 'Add, search and sync your book collection.',
    'livrosCarregados': '\${0} books loaded',
    'escanearLivro': 'Scan a book',
    'menuCadastro': 'Add a book',
    'menuPaises': 'Countries',
    'menuPesquisa': 'Search',
    'menuSincronizacao': 'Sync',
    'arquivo': 'File',
    'nenhumArquivoVinculado': 'No file linked',
    'selecionado': 'Selected',
    'livros': 'Books',
    'recarregado': 'Reloaded',
    'salvo': 'Saved',

    // --- cadastro ---
    'editarLivro': 'Edit book',
    'novoLivro': 'New book',
    'salvar': 'Save',
    'buscarPorIsbn': 'Look up by ISBN',
    'digitarIsbn': 'Enter ISBN',
    'isbnDica': 'ISBN (10 or 13 digits)',
    'fotoDaCapa': 'Cover photo',
    'dadosDoLivro': 'Book details',
    'titulo': 'Title',
    'anoDePublicacao': 'Year of publication',
    'localDoExemplar': 'Where the copy is',
    'autores': 'Author(s)',
    'nomeDoAutor': 'Author name',
    'adicionarAutor': 'Add author',
    'temasRotulo': 'Subject(s)',
    'tema': 'Subject',
    'adicionarTema': 'Add subject',
    'gruposDeLiteratura': 'Reading groups',
    'extras': 'Extras',
    'emprestado': 'On loan',
    'comentarios': 'Notes',
    'trocar': 'Change',
    'remover': 'Remove',
    'fotografarCapa': 'Photograph the cover',
    'camera': 'Camera',
    'galeria': 'Gallery',
    'semPais': '— no country —',
    'foraDaTabela': '\${0} (not in the table)',
    'pais': 'Country',
    'preenchidoComSucesso': 'Filled in successfully.',
    'isbnNaoEncontrado': 'ISBN not found, but the number was kept.',
    'isbnInvalido': 'Invalid ISBN (it must have 10 or 13 digits).',
    'erroAoBuscar': 'Lookup failed. Check your internet connection.',

    // --- foto da capa ---
    'refazer': 'Retake',
    'confirmarFoto': 'Confirm photo',
    'usarCapa': 'Use cover',

    // --- detalhe do livro ---
    'editar': 'Edit',
    'identificacao': 'Identification',
    'ano': 'Year',
    'local': 'Location',
    'status': 'Status',
    'sim': 'Yes',
    'nao': 'No',
    'grupoDeLiteratura': 'Reading group',
    'semFotoDaCapa': 'No cover photo',
    'tituloCopiado': 'Title copied: \${0} — paste it into the Kindle search.',
    'appKindle': 'Kindle app',

    // --- filtros ---
    'filtros': 'Filters',
    'limpar': 'Clear',
    'todosOsLivros': 'All books',
    'qualquerGrupo': 'Any group',
    'soLivrosComFoto': 'Only books with a photo',
    'pronto': 'Done',
    'statusTodos': 'All',
    'statusDisponiveis': 'Available',
    'statusEmprestados': 'On loan',
    'comFoto': 'With photo',

    // --- grupos de literatura ---
    'grupoDeLiteraturaNome': 'Reading Group',
    'grupoNumero': 'Group \${0}',

    // --- paises ---
    'paises': 'Countries',
    'nenhumLivroComPais': 'No book has a country yet.',
    'umLivro': 'book',
    'variosLivros': 'books',
    'umPais': 'country',
    'variosPaises': 'countries',
    'acervoEmPaises': '\${0} \${1} from \${2} \${3}',
    'aindaSemPais': ' · \${0} still without a country',
    'paisVemDoTema': "The country comes from the book's subject or ISBN. ",
    'leiaCodigoParaComecar': "Scan a book's barcode to get started.",

    // --- permissao de camera ---
    'permissaoScanner': 'To scan the barcode, allow camera access in the '
        'device settings.',
    'permissaoFoto': 'To photograph the cover, allow camera access in the '
        'device settings.',
    'cameraBloqueada': 'Camera access is blocked on this device.',
    'acessoCameraNegado': 'Camera access denied',
    'abrirConfiguracoes': 'Open Settings',
    'cancelar': 'Cancel',

    // --- pesquisa ---
    'pesquisa': 'Search',
    'buscarPlaceholder': 'Search by title, author, subject, location or year…',
    'umLivroEncontrado': 'book found',
    'variosLivrosEncontrados': 'books found',
    'carregandoBiblioteca': 'Loading the library…',
    'nenhumResultado': 'No results',
    'nenhumLivroCadastrado': 'No books yet',
    'removerLivro': 'Remove book',
    'removerConfirma': 'Remove "\${0}" from the library?',

    // --- scanner ---
    'erroAoAcessarCamera': 'Could not access the camera',
    'aponteParaCodigo': "Point at the book's barcode",
    'cameraIndisponivel': 'Camera unavailable',
    'voltar': 'Back',

    // --- selecionar pasta ---
    'selecionarPastaDica': 'Where your biblioteca.txt is — or will be',
    'achouBiblioteca': 'Found a library in this folder',
    'achouBibliotecaCorpo':
        'The folder "\${0}" already has a biblioteca.txt with \${1} book(s).',
    'usarEstaBiblioteca': 'Use this library',
    'escolherOutraPasta': 'Choose another folder',
    'criouArquivo':
        'Created biblioteca.txt in "\${0}". You can start adding books.',
    'naoConsegueLerTitulo': 'This library could not be read',
    'naoConsegueLer':
        'There is a biblioteca.txt in this folder, but it could not be read: \${0}',
    'escolhaSubpasta': 'Choose a subfolder. Android does not allow picking '
        '"My Drive" or the phone\'s storage.',
    'pastaVaziaComLivros':
        'This folder is empty. What should happen to the \${0} books you have '
        'open?',
    'comecarVazia': 'Start a new, empty library',
    'levarParaPasta': 'Move the \${0} here',

    // --- sincronizacao ---
    'sincronizacao': 'Sync',
    'nenhumaFotoNova': 'No new photos found.',
    'umaFotoCopiada': 'photo copied',
    'variasFotosCopiadas': 'photos copied',
    'fotosCopiadas': '\${0} \${1} successfully.',
    'erroGenerico': 'Error: \${0}',
    'livrosCarregadosRotulo': 'Books loaded',
    'acoes': 'Actions',
    'trocarPasta': 'Change folder',
    'selecionarPasta': 'Select folder',
    'recarregarArquivo': 'Reload file',
    'fotosDeCapa': 'Cover photos',
    'semDatNaPasta': 'There is no biblioteca.dat in this folder. That is the '
        'file where the Mac and the iPhone keep every cover; it sits next to '
        'biblioteca.txt.',
    'vinculePastaPrimeiro': 'Link the folder first. The covers come from the '
        'biblioteca.dat inside it.',
    'sincronizando': 'Syncing…',
    'sincronizarAgora': 'Sync now',
    'sincronizarViaDrive': 'Sync through Google Drive',
    'passoDrive1': 'On the computer, put biblioteca.txt and biblioteca.dat in '
        'a Google Drive folder and wait for it to sync.',
    'passoDrive2': 'In the Google Drive app on Android, find that folder, tap '
        '⋮ and choose "Make available offline".',
    'passoDrive3': 'Here in Sync, tap "Select folder", go to Drive in the side '
        'menu and pick the folder. Android will not let you pick "My Drive" '
        'itself: it has to be a folder inside it.',
    'passoDrive4': 'Before editing, tap "Reload" if you changed the data on '
        'another device. Avoid editing in two places at the same time.',

    // --- arquivo e erros do store ---
    'erroAoVincular': 'Could not link: \${0}',
    'pastaEscolhida': 'the one you chose',
    'semArquivoNaPasta': 'There is no \${0} in the "\${1}" folder. '
        'Choose the folder where the file is.',
    'erroAoCriarArquivo': 'The file could not be created in this folder: \${0}',
    'naoFoiPossivelCarregar': 'The linked file could not be loaded. '
        'Tap Select file to link it again.',
    'agoraVinculaPasta': 'Biblioteca now links the WHOLE folder, not each '
        'file. Tap Select folder and choose the folder where biblioteca.txt '
        'is — biblioteca.dat comes with it.',
    'erroAoCarregar': 'Could not load: \${0}',
    'erroAoSalvar': 'Could not save: \${0}',
    'naoParecebibliotecaDat':
        'The file you chose does not look like biblioteca.dat.',
  },
};
