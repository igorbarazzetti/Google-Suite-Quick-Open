# Google Suite Quick Open

Abra documentos do Office com duplo clique no navegador, direto em:

- Google Docs (`.doc`, `.docx`)
- Google Sheets (`.xls`, `.xlsx`)
- Google Slides (`.ppt`, `.pptx`)

É para quem quer continuar usando arquivo local, mas editar no Google sem abrir manualmente o Drive.

## O que esse app faz

- Associa os tipos de arquivo no Windows para abrir com um clique no projeto.
- Faz upload seguro do arquivo para sua conta Google.
- Abre automaticamente no navegador no modo de edição.
- Mantém os arquivos em uma pasta temporaria do Google Drive.
- Limpa arquivos antigos automaticamente (padrão: 24 horas).

## Como instalar (2 minutos)

1. Abra PowerShell na pasta do projeto.
2. Rode:

```powershell
cd "C:\caminho\do\GoogleDriveQuickOpen"
.\install.ps1
```

Feito. A partir daí os tipos suportados passam a abrir no Google Suite Quick Open.

## Como usar

- Dê dois cliques em qualquer arquivo suportado.
- O app abre o navegador no arquivo convertido para o app certo.
- Se quiser mudar a pasta temporaria ou tempo de limpeza, use a opção de linha de comando.

## Opcoes de linha de comando

- `--kind doc|sheet|slide`: define explicitamente o destino.
- `--temp-folder "nome"`: nome da pasta no Drive para uploads temporarios.
- `--retention-hours N`: tempo de permanencia em horas.
- `--no-cleanup`: desativa a limpeza dos arquivos antigos.
- `--no-cache`: cria novo upload a cada abertura.

## Configuracao do Google

1. Crie credencial OAuth no Google Cloud (Desktop app).
2. Copie o arquivo para `GoogleDriveQuickOpen/client_secret.json`.

O JSON deve ficar fora do Git (`.gitignore` já protege esse arquivo).

## Screenshots

![Abrindo DOCX no Google Docs](assets/screenshots/01-open-doc.png)

![Abrindo XLSX no Google Sheets](assets/screenshots/02-open-sheet.png)

![Abrindo PPTX no Google Slides](assets/screenshots/03-open-slides.png)

![Icones no Windows](assets/screenshots/04-file-association.png)

## Para quem quer só usar

- Windows 10/11
- Python 3.10+
- Conta Google com Drive ativo
- PowerShell

## Tirou duvida?

- Arquivo abriu no app errado: ajuste a associacao nas configuracoes do Windows.
- Se o login pedir confirmacao, aceite o acesso da app ao Google Drive.
