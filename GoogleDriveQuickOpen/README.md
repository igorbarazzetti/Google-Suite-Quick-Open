# Google Suite Quick Open (Docs / Sheets / Slides)

Esse app abre arquivos locais diretamente no navegador, usando a aplicacao do Google correspondente:

1. Detecta o tipo do arquivo:
   - `doc`: `.doc/.docx`
   - `sheet`: `.xls/.xlsx`
   - `slide`: `.ppt/.pptx`
2. Faz upload para o Google Drive autenticado na sua conta.
3. Converte o arquivo para Google Docs, Google Sheets ou Google Slides.
4. Abre automaticamente o documento no navegador em modo de edicao.
5. Salva em uma pasta temporaria no Google Drive e remove arquivos antigos automaticamente.

Observacao: o fluxo usa a API do Google Drive, entao a primeira execucao pede login/consentimento no Google.

## 1) Pasta padrao temporaria

Por padrao, o app usa:

```text
GoogleDriveQuickOpen Temp
```

No primeiro uso, essa pasta e criada automaticamente na raiz do seu Drive.

## 2) Retencao de arquivos no Drive

O padrao atual e remover os arquivos temporarios apos **24 horas**.

Voce pode ajustar por parametro:

```powershell
python "C:\caminho\seu-projeto\GoogleDriveQuickOpen\open_in_google.py" --retention-hours 0.5 "C:\caminho\planilha.xlsx"
```

Ou deixar sem remocao automatica:

```powershell
python "...\\open_in_google.py" --no-cleanup "C:\caminho\arquivo.docx"
```

Tambem da para escolher outro nome de pasta:

```powershell
python "...\\open_in_google.py" --temp-folder "Rascunhos Docs" "C:\caminho\arquivo.docx"
```

## 3) Preparar credenciais do Google

1. Acesse o Google Cloud Console.
2. Crie ou escolha um projeto.
3. Ative a **Google Drive API**.
4. Va em `APIs e Servicos > Credenciais`.
5. Crie `ID do cliente OAuth` com tipo **Aplicativo para desktop**.
6. Baixe o JSON e salve como:

```text
C:\caminho\seu-projeto\GoogleDriveQuickOpen\client_secret.json
```

> Voce tambem pode usar variaveis de ambiente `GOOGLE_CLIENT_ID` e `GOOGLE_CLIENT_SECRET`, mas o JSON e mais simples.

## 4) Instalar o launcher no Windows

```powershell
cd "$env:USERPROFILE\OneDrive\Documentos\Windows Apps\GoogleDriveQuickOpen"
.\install.ps1
```

O script copia o app para:

```text
%LOCALAPPDATA%\GoogleDriveQuickOpen\open_in_google.py
```

Depois disso, registra:

- `.doc/.docx` para Google Docs
- `.xls/.xlsx` para Google Sheets
- `.ppt/.pptx` para Google Slides

Os icones de arquivo tambem sao atualizados com os icones oficiais do Google Docs, Google Sheets e Google Slides.

## 5) Opcoes uteis

- `--kind doc|sheet|slide`: define explicitamente o tipo.
- `--temp-folder "nome"`: muda a pasta temporaria no Drive.
- `--retention-hours N`: tempo de retencao em horas (`0` = nao remove).
- `--no-cleanup`: desativa a limpeza automatica.
- `--no-cache`: sempre cria novo arquivo no Drive (sem reutilizar o anterior).

## 6) Ajustes uteis no Windows

- Em alguns Windows 10/11 novos, a associacao global pode continuar vindo de "Apps Padrao".  
  Abra as configuracoes e force `.doc/.docx`, `.xls/.xlsx` e `.ppt/.pptx` para o app criado, se necessario.

## Arquivos locais

- Configuracao/estado: `%LOCALAPPDATA%\GoogleDriveQuickOpen\state.json`
- Log: `%LOCALAPPDATA%\GoogleDriveQuickOpen\launcher.log`

## 7) Guia para quem quiser testar em outro PC

Se voce quer testar este projeto no seu computador, siga exatamente estes passos:

1) Tenha Python 3.x instalado.

2) Baixe o projeto (ou clone):

```powershell
git clone https://github.com/igorbarazzetti/Google-Suite-Quick-Open.git
cd Google-Suite-Quick-Open\GoogleDriveQuickOpen
```

3) Crie as credenciais do Google OAuth (necessario para qualquer teste real):

- Entre no Google Cloud Console.
- Crie um projeto e habilite a Google Drive API.
- Gere um OAuth Client de tipo **Desktop app**.
- Baixe o arquivo `client_secret.json` e cole ao lado do `open_in_google.py`.

Sem esse arquivo, o app nao abre no Google (pede as credenciais e para).

4) Instale e registre as associacoes:

```powershell
.\install.ps1
```

5) Teste:

- Feche e abra novamente o Explorer (ou reinicie a sessao).
- Dê duplo clique em um `.docx`, `.xlsx` ou `.pptx`.
- O arquivo deve abrir no navegador em Docs/Sheets/Slides.

6) Se a associacao nao funcionar na primeira vez:

- Acesse Configuracoes > Apps > Apps padrao.
- Defina `.docx`, `.doc`, `.xlsx`, `.xls`, `.ppt`, `.pptx` para "Google Suite Quick Open".
- Reinicie o Explorer se necessario (`taskkill /f /im explorer.exe` e abra de novo).

7) Desinstalar (caso precise):

```powershell
%LOCALAPPDATA%\GoogleDriveQuickOpen\uninstall.ps1
```

Notas para compartilhamento:

- O app abre usando sua conta Google local; nao funciona compartilhado por outra conta.
- Os arquivos sao enviados para o Google Drive do usuario logado.
- O tempo de retencao padrao e 24h, mas voce pode alterar com `--retention-hours`.
