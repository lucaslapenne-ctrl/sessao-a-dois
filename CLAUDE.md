# Sessão a Dois — contexto do projeto

App web para controlar filmes, séries e animes assistidos em grupo (começou para o Lucas e a namorada; agora qualquer pessoa cria listas e convida outras).

## Stack
- **Frontend:** um único `index.html` (HTML/CSS/JS puro, sem build). Hospedado no GitHub Pages.
- **Banco + login:** Supabase com login Google: botão do Google Identity Services + `signInWithIdToken` (nonce em SHA-256), com `signInWithOAuth` de reserva se o script do Google não carregar; cadastro aberto. Multi-lista: qualquer pessoa cria listas e convida outras por link `?convite=CODIGO`; RLS via `eh_membro()`/`eh_dono()`. Listas e membros só mudam por RPC (`criar_lista`, `ver_convite`, `entrar_na_lista`, `novo_convite`, `remover_membro`, `sair_da_lista`), exceto o campo `nome`. Realtime em `titles`, `notas`, `membros`, filtrado por `lista_id`.
- **Base de títulos e capas:** API do TMDB (`/search/multi` para autocompletar, `/tv/{id}` para nº de temporadas, imagens em `image.tmdb.org/t/p/`). Idioma `pt-BR`.
- **Config:** `config.js` (URL e anon key do Supabase, Client ID do Google, token de leitura do TMDB). Público no GitHub — nunca colocar a `service_role` key nem o Client secret do Google.

## Arquivos
- `index.html` — app inteiro
- `config.js` — chaves
- `manifest.webmanifest`, `sw.js`, `icons/` — PWA (instalável, abre offline). `sw.js`: rede primeiro para arquivos do app, cache para fontes/CDN e capas do TMDB, nunca cacheia Supabase/Google/API do TMDB. Ícones gerados em PIL (ingresso com coração).
- `schema.sql` — estrutura do banco, idempotente (rodar no SQL Editor do Supabase)
- `README.md` — passo a passo de configuração e publicação

## Modelo de dados
- `listas`: id, nome, convite (10 caracteres, único), created_at.
- `membros`: lista_id, user_id, nome (nome exibido nesta lista), dono, entrou_em.
- `titles`: lista_id, title, original, kind (`filme|serie|anime`), status (`quero|vendo|visto`), year, tmdb_id, tmdb_type (`movie|tv`), poster_path, season, episode, watched_on, note, criado_por, created_at, updated_at.
- `notas`: title_id, user_id, lista_id, nota (0–5, passo 0,25; até out/2026 era 0–10 e foi convertida dividindo por 2). Uma nota por pessoa por título; cada um só edita a própria.

## Regras
- Anime = TMDB com gênero 16 (Animação) e idioma original `ja` ou país `JP`.
- Interface em português; layout estilo "ingresso", tema claro/escuro, funciona no celular.
- Manter crédito ao TMDB no rodapé (exigência dos termos).
- Supabase grátis pausa após ~1 semana sem uso → "Restore project" no painel.
