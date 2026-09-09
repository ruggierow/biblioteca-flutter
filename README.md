# Biblioteca para Android

![Plataforma](https://img.shields.io/badge/plataforma-Android-3DDC84?logo=android&logoColor=white)
![Versão](https://img.shields.io/badge/versão-1.8.2-blue)
![Distribuição](https://img.shields.io/badge/distribuição-APK%20direto-orange)

App Android para gerenciar sua coleção de livros pessoais. Catálogo completo com fotos de capa, scanner de ISBN e sincronização com Google Drive. Compartilha os mesmos dados com o app iOS e com o [Biblioteca Web](https://github.com/ruggierow/biblioteca-web).

---

## Download

Acesse a [página de Releases](https://github.com/ruggierow/biblioteca-flutter/releases/latest) e baixe o arquivo `Biblioteca-Android-v1.8.2.apk`.

---

## Instalação

O app não está na Play Store — ele é distribuído diretamente como APK.

### Passo a passo

1. **Habilite fontes desconhecidas** no seu Android:
   - Android 8 ou mais novo: *Configurações → Aplicativos → Instalar apps desconhecidos* → habilite para o navegador ou gerenciador de arquivos que você usa.
   - Android 7 ou mais antigo: *Configurações → Segurança → Fontes desconhecidas*.

2. **Baixe o APK** pelo link acima (ou transfira do computador via cabo USB).

3. **Toque no arquivo APK** no gerenciador de arquivos e confirme a instalação.

4. O ícone **Biblioteca** aparecerá na tela inicial.

> **Nota:** a versão atual assina o APK com chave de debug. Ela é totalmente funcional para uso pessoal, mas não é adequada para distribuição na Play Store.

---

## Funcionalidades

| Funcionalidade | Descrição |
|---|---|
| Catálogo de livros | Lista todos os seus livros com capa, título e autor |
| Cadastro completo | Título, autor, editora, ano, ISBN, gênero, estante e notas |
| Fotos de capa | Capture pela câmera do celular ou escolha da galeria |
| Scanner de ISBN | Aponte a câmera para o código de barras do livro e os dados são preenchidos automaticamente |
| Busca e filtros | Encontre livros por qualquer campo |
| Sincronização | Lê e grava o `biblioteca.txt` no Google Drive |

---

## Sincronização de dados

O app salva seus livros no arquivo `biblioteca.txt` dentro da pasta `Documentos/Biblioteca/` do Google Drive. As fotos de capa ficam no arquivo `biblioteca.dat` (formato JSON) na mesma pasta.

### Como vincular ao Google Drive

1. Abra o app e toque no menu (três pontos) → **Sincronizar**.
2. Na primeira vez, o app pede permissão para acessar o Google Drive — toque em **Permitir**.
3. O app localiza (ou cria) a pasta `Documentos/Biblioteca/` automaticamente.
4. Para sincronizar manualmente a qualquer momento, use o mesmo menu.

> Se o Google Drive estiver offline, o app trabalha com a cópia local e sincroniza quando a conexão for restaurada.

---

## Formato dos dados

Os dados são armazenados em formato aberto, legível em qualquer editor de texto:

- **`biblioteca.txt`** — arquivo TSV (valores separados por tabulação) com 8 colunas: `id`, `titulo`, `autor`, `editora`, `ano`, `isbn`, `genero`, `estante` e `notas`.
- **`biblioteca.dat`** — arquivo JSON com as fotos de capa em Base64.

Esses formatos são idênticos nos apps Android, iOS e Web — seus dados portam entre plataformas sem conversão.

---

## Compatibilidade com outros apps

| App | Plataforma | Repositório |
|---|---|---|
| Biblioteca Web | Mac e Windows | [biblioteca-web](https://github.com/ruggierow/biblioteca-web) |
| Biblioteca iOS | iPhone | [biblioteca-ios](https://github.com/ruggierow/biblioteca-ios) |

Os três apps leem e gravam exatamente o mesmo `biblioteca.txt` e `biblioteca.dat`. Se você usar o app iOS com iCloud e o Android com Google Drive, basta manter o arquivo sincronizado entre as nuvens (por exemplo, pelo app Arquivos do iPhone ou pelo Google Drive no Mac).

---

## Requisitos

- Android 8.0 (Oreo) ou superior
- Google Drive instalado (para sincronização)
- Câmera (para scanner de ISBN e fotos de capa)
