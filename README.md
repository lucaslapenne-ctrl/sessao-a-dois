# Sessão a Dois

App para controlar o que vocês assistem juntos: fila de "quero ver", progresso de séries e animes, a nota de cada um e as capas.

Cada pessoa entra com a própria conta do Google. Quem cria uma lista manda um **link de convite** para quem assiste junto. Ninguém precisa cadastrar o e-mail de ninguém, e cada um só vê as listas das quais faz parte. Uma pessoa pode estar em várias listas (o casal, a família, os amigos).

Tudo funciona de graça:

- **GitHub Pages** hospeda o site.
- **Supabase** guarda as listas, faz o login e sincroniza entre os celulares.
- **TMDB** fornece as sugestões enquanto você digita e as capas.

## 1. TMDB (base de filmes, séries e animes)

1. Crie uma conta em https://www.themoviedb.org/signup.
2. Vá em **Settings → API** e peça uma chave do tipo **Developer**, para uso pessoal e não comercial.
3. Copie o **API Read Access Token** (o token longo, que começa com `eyJ...`).

## 2. Supabase (banco de dados)

1. Crie uma conta em https://supabase.com e um projeto novo. Escolha a região São Paulo e anote a senha do banco.
2. Em **SQL Editor → New query**, cole todo o conteúdo de `schema.sql` e clique em **Run**. (Se o app mudar depois, é só rodar o arquivo novo de novo; os dados ficam.)
3. Em **Project Settings → API**, copie a **Project URL** e a chave **anon public** (ou a **publishable key**). Nunca use a `service_role` / secret.

## 3. Login com Google

**No Google Cloud** (https://console.cloud.google.com):

1. Crie um projeto (ex.: `Sessao a Dois`).
2. Abra **Google Auth Platform** (ou **APIs e serviços → Tela de consentimento OAuth**) e clique em **Get started**: nome do app `Sessão a Dois`, seu e-mail de suporte, público **External**, seu e-mail de contato. Conclua.
3. Em **Audience**, clique em **Publish app** para sair do modo *Testing*. Assim qualquer conta Google consegue entrar (quem vai ver cada lista é decidido pelo convite, não pelo Google). Como o app só pede nome e e-mail, não precisa de verificação do Google.
4. Em **Clients → Create client**, tipo **Web application**:
   - **Authorized JavaScript origins:** `https://lucaslapenne-ctrl.github.io`
   - **Authorized redirect URIs:** `https://aszqzonvevkzokwpewfp.supabase.co/auth/v1/callback` (o endereço exato aparece no Supabase, no passo seguinte)
5. Copie o **Client ID** e o **Client secret**.

**No Supabase:**

1. **Authentication → Sign In / Providers → Google**: ligue, cole Client ID e Client secret e salve. Deixe **Allow new users to sign up** ligado.
2. **Authentication → URL Configuration**:
   - **Site URL:** `https://lucaslapenne-ctrl.github.io/sessao-a-dois/`
   - **Redirect URLs:** adicione o mesmo endereço.

O Client secret fica só no Supabase. Não coloque ele no `config.js`.

## 4. Configurar

Abra `config.js` e cole a Project URL em `SUPABASE_URL`, a chave anon/publishable em `SUPABASE_ANON_KEY` e o token do TMDB em `TMDB_TOKEN`.

## 5. Publicar no GitHub Pages

1. Crie um repositório no GitHub, por exemplo `sessao-a-dois`, e suba `index.html`, `config.js`, `manifest.webmanifest`, `sw.js`, `privacidade.html` e a pasta `icons/` (o `schema.sql` e o README podem ir junto, não têm nada secreto).
2. Vá em **Settings → Pages → Source: Deploy from a branch**, escolha `main` / `(root)` e salve.
3. Em 1 ou 2 minutos o site fica em `https://lucaslapenne-ctrl.github.io/sessao-a-dois/`.
4. Instale como app (veja abaixo).

## 6. Instalar como app no celular

O site é um PWA: instalado, ganha ícone na tela, abre em tela cheia sem a barra do navegador e continua abrindo mesmo sem internet (a lista atualiza quando a conexão volta).

- **Android (Chrome):** abra o link e toque em **Instalar o app** no rodapé (ou no aviso que o Chrome mostra). Se não aparecer, menu ⋮ → **Instalar app**.
- **iPhone (Safari):** abra o link no Safari, toque em **Compartilhar** → **Adicionar à Tela de Início**. Só funciona pelo Safari.
- **Computador (Chrome/Edge):** ícone de instalar na barra de endereço.

Ao publicar uma versão nova do `index.html`, o app instalado pega a atualização sozinho na próxima vez que abrir com internet. Só é preciso trocar `VERSAO` no `sw.js` se mudar a lista de arquivos que ele guarda.

## Como usar

1. Entre com o Google, escreva seu nome e crie uma lista (ex.: "Lucas & Ana").
2. Toque em **Lista e convite → Compartilhar** e mande o link pelo WhatsApp.
3. Quem abrir o link entra com o Google e aceita o convite. Pronto: os dois veem e editam a mesma lista, ao vivo.
4. Cada um dá a sua nota quando terminarem um título. O app mostra as notas de todos e a média.

Em **Lista e convite** também dá para: trocar de lista ou criar outra, mudar o nome da lista e o seu, remover alguém (só quem criou a lista), gerar um link novo (o antigo para de funcionar) e sair da lista.

Se o link for aberto dentro do navegador do Instagram ou de outro app, o Google pode bloquear o login. Nesse caso, abra o link no Chrome ou no Safari.

## Sobre as chaves no código público

- **Chave anon do Supabase:** foi feita para ficar no navegador. A proteção é o login mais as regras do banco (RLS): cada pessoa só lê e escreve nas listas das quais é membro, e só entra numa lista com o código de convite.
- **Token do TMDB:** dá acesso só de leitura a dados públicos de filmes. Se alguém abusar dele, você gera outro no site do TMDB.
- **Nunca coloque no `config.js` a `service_role` key do Supabase nem o Client secret do Google.**

## Bom saber

- No plano grátis, o Supabase **pausa projetos sem uso por cerca de 1 semana**. Se ninguém abrir o app por um tempo, entre no painel do Supabase e clique em **Restore project**. Os dados não se perdem.
- O plano grátis do Supabase aguenta bem um app desse tamanho (dezenas de milhares de usuários por mês, 500 MB de banco).
- A chave do TMDB é para uso **não comercial**. Se um dia cobrar pelo app, é preciso licença comercial do TMDB.
- Os termos do TMDB pedem crédito a eles. O rodapé do app já mostra esse aviso.
