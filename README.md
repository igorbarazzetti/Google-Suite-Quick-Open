# Google Suite Quick Open

[![Status](https://img.shields.io/badge/platform-Windows-0078d4?logo=windows)](https://www.microsoft.com/windows)
[![Python](https://img.shields.io/badge/python-3.10+-blue?logo=python)](https://www.python.org/)

Google Suite Quick Open abre arquivos locais no navegador usando Google Docs, Google Sheets e Google Slides com duplo clique no Windows.

## Visao geral

- Suporta:
  - Documentos Word: `.doc`, `.docx`
  - Planilhas Excel: `.xls`, `.xlsx`
  - Apresentacoes PowerPoint: `.ppt`, `.pptx`
- Detecta o tipo de arquivo e abre no app Google correspondente.
- Faz upload para Google Drive autenticado.
- Abre automaticamente o arquivo no modo de edicao do navegador.
- Cria pasta temporaria no Drive e faz limpeza automatica de arquivos antigos.

## Preview

### 1) Abrindo Word no Google Docs
![Abertura de docx no Google Docs](assets/screenshots/01-open-doc.png)

### 2) Abrindo Excel no Google Sheets
![Abertura de xlsx no Google Sheets](assets/screenshots/02-open-sheet.png)

### 3) Abrindo PowerPoint no Google Slides
![Abertura de pptx no Google Slides](assets/screenshots/03-open-slides.png)

### 4) App instalado no contexto de arquivos
![Menu do app no Windows](assets/screenshots/04-file-association.png)

## Como colocar seus prints

1. Abra o app e gere seus captures de tela.
2. Salve as imagens na pasta `assets/screenshots/` com os seguintes nomes:
   - `01-open-doc.png`
   - `02-open-sheet.png`
   - `03-open-slides.png`
   - `04-file-association.png`
3. Commit e push.

## Instalar

```powershell
cd "C:\Users\igor\OneDrive\Documentos\Windows Apps\GoogleDriveQuickOpen"
.\install.ps1
```

Depois de instalado, os arquivos estao associados para abrir diretamente no Google Suite Quick Open.

## Opcoes da linha de comando

- `--kind doc|sheet|slide`: força o destino (Docs, Sheets, Slides).
- `--temp-folder "nome"`: pasta temporaria no Drive.
- `--retention-hours N`: tempo de vida dos arquivos em horas.
- `--no-cleanup`: desativa a limpeza automatica.
- `--no-cache`: forca upload novo a cada abertura.

## Credenciais do Google

1. Ative Google Drive API no Google Cloud.
2. Crie credencial OAuth2 (Desktop).
3. Baixe o JSON para:
   - `GoogleDriveQuickOpen/client_secret.json`

Esse arquivo **nao** deve ser enviado para o Git.

## Pasta temporaria no Drive

- Padrão: `GoogleDriveQuickOpen Temp`
- Retencao padrao: `24 horas` (ajustavel com `--retention-hours`)

## Estrutura do projeto

- `GoogleDriveQuickOpen/open_in_google.py` - script principal.
- `GoogleDriveQuickOpen/install.ps1` - instalador/registrador de associacoes.
- `GoogleDriveQuickOpen/uninstall.ps1` - limpeza de associacoes.
- `GoogleDriveQuickOpen/README.md` - guia detalhado.
- `.gitignore` - protege credenciais locais.

## Requisitos

- Windows 10/11
- Python 3.10+
- Conta Google com Drive ativo

## Troubleshooting rapido

- Se algum arquivo abrir no app errado, ajuste associacao em Configuracoes do Windows.
- Se o Google solicitar login, confirme a conta e aceite o consentimento da API Drive.
