-- Sessão a Dois — estrutura do banco no Supabase (listas compartilhadas com convite)
-- Cole tudo em: Supabase > SQL Editor > New query > Run.
-- Pode rodar de novo depois (para atualizar) sem perder dados.

-- Versão antiga (com e-mails fixos): remove a tabela velha, se existir.
do $$ begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='titles')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='titles' and column_name='lista_id') then
    drop table public.titles cascade;
  end if;
end $$;
drop function if exists public.sou_do_casal() cascade;

-- ---------- tabelas ----------
create table if not exists public.listas (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null check (char_length(nome) between 1 and 60),
  convite     text not null unique default upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),
  created_at  timestamptz not null default now()
);

create table if not exists public.membros (
  lista_id   uuid not null references public.listas(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  nome       text not null check (char_length(nome) between 1 and 40),
  dono       boolean not null default false,
  entrou_em  timestamptz not null default now(),
  primary key (lista_id, user_id)
);
create index if not exists membros_user on public.membros(user_id);

create table if not exists public.titles (
  id           uuid primary key default gen_random_uuid(),
  lista_id     uuid not null references public.listas(id) on delete cascade,
  title        text not null,
  original     text,
  kind         text not null check (kind in ('filme','serie','anime')),
  status       text not null check (status in ('quero','vendo','visto')),
  year         int,
  tmdb_id      int,
  tmdb_type    text check (tmdb_type in ('movie','tv')),
  poster_path  text,
  season       int,
  episode      int,
  watched_on   date,
  note         text,
  criado_por   uuid default auth.uid() references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists titles_lista on public.titles(lista_id);

-- Uma nota por pessoa por título
create table if not exists public.notas (
  title_id    uuid not null references public.titles(id) on delete cascade,
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  lista_id    uuid not null references public.listas(id) on delete cascade,
  nota        numeric(3,1) not null check (nota between 0 and 10),
  updated_at  timestamptz not null default now(),
  primary key (title_id, user_id)
);
create index if not exists notas_lista on public.notas(lista_id);

-- ---------- quem é membro de quê ----------
create or replace function public.eh_membro(p_lista uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from membros where lista_id = p_lista and user_id = auth.uid())
$$;

create or replace function public.eh_dono(p_lista uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from membros where lista_id = p_lista and user_id = auth.uid() and dono)
$$;

-- ---------- permissões (RLS) ----------
-- Cada pessoa só enxerga as listas das quais é membro.
alter table public.listas  enable row level security;
alter table public.membros enable row level security;
alter table public.titles  enable row level security;
alter table public.notas   enable row level security;

revoke all on public.listas, public.membros, public.titles, public.notas from anon;
-- listas e membros só mudam pelas funções abaixo (exceto o nome)
revoke insert, update, delete on public.listas, public.membros from authenticated;
grant select on public.listas, public.membros to authenticated;
grant update (nome) on public.listas, public.membros to authenticated;
grant select, insert, update, delete on public.titles, public.notas to authenticated;

drop policy if exists "membros veem a lista" on public.listas;
create policy "membros veem a lista" on public.listas
  for select to authenticated using (public.eh_membro(id));
drop policy if exists "dono renomeia a lista" on public.listas;
create policy "dono renomeia a lista" on public.listas
  for update to authenticated using (public.eh_dono(id)) with check (public.eh_dono(id));

drop policy if exists "membros veem os membros" on public.membros;
create policy "membros veem os membros" on public.membros
  for select to authenticated using (public.eh_membro(lista_id));
drop policy if exists "cada um muda o proprio nome" on public.membros;
create policy "cada um muda o proprio nome" on public.membros
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "membros usam os titulos" on public.titles;
create policy "membros usam os titulos" on public.titles
  for all to authenticated using (public.eh_membro(lista_id)) with check (public.eh_membro(lista_id));

drop policy if exists "membros veem as notas" on public.notas;
create policy "membros veem as notas" on public.notas
  for select to authenticated using (public.eh_membro(lista_id));
drop policy if exists "cada um da a propria nota" on public.notas;
create policy "cada um da a propria nota" on public.notas
  for all to authenticated
  using (user_id = auth.uid() and public.eh_membro(lista_id))
  with check (user_id = auth.uid() and public.eh_membro(lista_id)
              and exists (select 1 from public.titles t where t.id = title_id and t.lista_id = notas.lista_id));

-- ---------- ações (chamadas pelo app) ----------
create or replace function public.criar_lista(p_nome text, p_meu_nome text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  if auth.uid() is null then raise exception 'Faça login primeiro.'; end if;
  if (select count(*) from membros where user_id = auth.uid() and dono) >= 20 then
    raise exception 'Você já criou listas demais.';
  end if;
  insert into listas(nome) values (left(trim(p_nome), 60)) returning id into v;
  insert into membros(lista_id, user_id, nome, dono) values (v, auth.uid(), left(trim(p_meu_nome), 40), true);
  return v;
end $$;

-- Mostra o nome da lista antes de aceitar o convite
create or replace function public.ver_convite(p_convite text)
returns table(id uuid, nome text, qtd int, ja_sou boolean)
language sql stable security definer set search_path = public as $$
  select l.id, l.nome,
         (select count(*) from membros m where m.lista_id = l.id)::int,
         exists (select 1 from membros m where m.lista_id = l.id and m.user_id = auth.uid())
  from listas l
  where auth.uid() is not null and l.convite = upper(trim(p_convite))
$$;

create or replace function public.entrar_na_lista(p_convite text, p_meu_nome text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  if auth.uid() is null then raise exception 'Faça login primeiro.'; end if;
  select l.id into v from listas l where l.convite = upper(trim(p_convite));
  if v is null then raise exception 'Esse convite não vale mais. Peça um link novo.'; end if;
  insert into membros(lista_id, user_id, nome) values (v, auth.uid(), left(trim(p_meu_nome), 40))
  on conflict (lista_id, user_id) do nothing;
  return v;
end $$;

create or replace function public.novo_convite(p_lista uuid) returns text
language plpgsql security definer set search_path = public as $$
declare c text := upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
begin
  if not eh_dono(p_lista) then raise exception 'Só quem criou a lista pode trocar o convite.'; end if;
  update listas set convite = c where id = p_lista;
  return c;
end $$;

-- Remove alguém e troca o link (para a pessoa não voltar pelo link antigo)
create or replace function public.remover_membro(p_lista uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not eh_dono(p_lista) then raise exception 'Só quem criou a lista pode remover pessoas.'; end if;
  if p_user = auth.uid() then raise exception 'Para sair, use "Sair da lista".'; end if;
  delete from notas   where lista_id = p_lista and user_id = p_user;
  delete from membros where lista_id = p_lista and user_id = p_user;
  update listas set convite = upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)) where id = p_lista;
end $$;

-- Sai da lista. Se era o último, apaga a lista; se era o dono, passa para o membro mais antigo.
create or replace function public.sair_da_lista(p_lista uuid) returns void
language plpgsql security definer set search_path = public as $$
declare prox uuid;
begin
  if not eh_membro(p_lista) then return; end if;
  delete from notas   where lista_id = p_lista and user_id = auth.uid();
  delete from membros where lista_id = p_lista and user_id = auth.uid();
  if not exists (select 1 from membros where lista_id = p_lista) then
    delete from listas where id = p_lista;
  elsif not exists (select 1 from membros where lista_id = p_lista and dono) then
    select user_id into prox from membros where lista_id = p_lista order by entrou_em limit 1;
    update membros set dono = true where lista_id = p_lista and user_id = prox;
  end if;
end $$;

revoke execute on function public.eh_membro(uuid), public.eh_dono(uuid),
  public.criar_lista(text,text), public.ver_convite(text), public.entrar_na_lista(text,text),
  public.novo_convite(uuid), public.remover_membro(uuid,uuid), public.sair_da_lista(uuid)
  from public, anon;
grant execute on function public.eh_membro(uuid), public.eh_dono(uuid),
  public.criar_lista(text,text), public.ver_convite(text), public.entrar_na_lista(text,text),
  public.novo_convite(uuid), public.remover_membro(uuid,uuid), public.sair_da_lista(uuid)
  to authenticated;

-- ---------- updated_at automático ----------
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;

drop trigger if exists titles_touch on public.titles;
create trigger titles_touch before update on public.titles
  for each row execute function public.touch_updated_at();
drop trigger if exists notas_touch on public.notas;
create trigger notas_touch before update on public.notas
  for each row execute function public.touch_updated_at();

-- ---------- sincronização ao vivo ----------
do $$
declare t text;
begin
  foreach t in array array['titles','notas','membros'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;
