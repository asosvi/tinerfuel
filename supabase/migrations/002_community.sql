-- 002_community.sql: aportaciones de la comunidad sobre parkings (precios,
-- opiniones y fotos), perfiles, denuncias, bloqueos y borrado de cuenta.
--
-- Ver: leer, todos (también sin cuenta). Escribir: solo con cuenta y solo lo propio.
-- Las aportaciones apuntan a profiles (no a auth.users) para que la app lea el
-- nombre del autor en la misma consulta: select('*, profiles(display_name)').

-- ------------------------------------------------------------------ perfiles

create table public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 50),
  created_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;
create policy profiles_read   on public.profiles for select to anon, authenticated using (true);
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke insert, delete on public.profiles from anon, authenticated;
revoke update on public.profiles from anon, authenticated;
grant update (display_name) on public.profiles to authenticated;

-- Perfil automático al crear la cuenta. Nombre: el de Google/Apple si viene,
-- si no la parte del email antes de la @ (recortada), si no "Usuario".
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  name text := coalesce(
    nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
    nullif(trim(new.raw_user_meta_data->>'name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Usuario');
begin
  insert into public.profiles (id, display_name)
  values (new.id, left(name, 50))
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------------ aportaciones

create table public.parking_prices (
  id          uuid primary key default gen_random_uuid(),
  parking_id  text not null references public.parkings on delete cascade,
  user_id     uuid not null default auth.uid() references public.profiles on delete cascade,
  kind        text not null check (kind in ('hour', 'day', 'month', 'flat', 'free')),
  amount      numeric(7, 2) not null check (amount >= 0 and amount <= 1000),
  note        text check (char_length(note) <= 300),
  created_at  timestamptz not null default now(),
  check (kind <> 'free' or amount = 0)
);
create index parking_prices_parking_idx on public.parking_prices (parking_id, created_at desc);

create table public.parking_reviews (
  id          uuid primary key default gen_random_uuid(),
  parking_id  text not null references public.parkings on delete cascade,
  user_id     uuid not null default auth.uid() references public.profiles on delete cascade,
  rating      smallint not null check (rating between 1 and 5),
  comment     text check (char_length(comment) <= 1000),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (parking_id, user_id)                       -- una opinión por persona y parking
);
create index parking_reviews_parking_idx on public.parking_reviews (parking_id, created_at desc);

create table public.parking_photos (
  id           uuid primary key default gen_random_uuid(),
  parking_id   text not null references public.parkings on delete cascade,
  user_id      uuid not null default auth.uid() references public.profiles on delete cascade,
  storage_path text not null unique,
  created_at   timestamptz not null default now(),
  -- la foto tiene que estar en la carpeta de quien la sube: <user_id>/<id>.jpg
  check (storage_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png)$'),
  check (split_part(storage_path, '/', 1) = user_id::text)
);
create index parking_photos_parking_idx on public.parking_photos (parking_id, created_at desc);

alter table public.parking_prices  enable row level security;
alter table public.parking_reviews enable row level security;
alter table public.parking_photos  enable row level security;

create policy parking_prices_read   on public.parking_prices  for select to anon, authenticated using (true);
create policy parking_prices_insert on public.parking_prices  for insert to authenticated with check (user_id = (select auth.uid()));
create policy parking_prices_delete on public.parking_prices  for delete to authenticated using (user_id = (select auth.uid()));

create policy parking_reviews_read   on public.parking_reviews for select to anon, authenticated using (true);
create policy parking_reviews_insert on public.parking_reviews for insert to authenticated with check (user_id = (select auth.uid()));
create policy parking_reviews_update on public.parking_reviews for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy parking_reviews_delete on public.parking_reviews for delete to authenticated using (user_id = (select auth.uid()));

create policy parking_photos_read   on public.parking_photos  for select to anon, authenticated using (true);
create policy parking_photos_insert on public.parking_photos  for insert to authenticated with check (user_id = (select auth.uid()));
create policy parking_photos_delete on public.parking_photos  for delete to authenticated using (user_id = (select auth.uid()));

revoke insert, update, delete on public.parking_prices, public.parking_reviews, public.parking_photos from anon;
revoke update on public.parking_prices, public.parking_photos from authenticated;
revoke update on public.parking_reviews from authenticated;
grant update (rating, comment) on public.parking_reviews to authenticated;

-- Guardas: autor y fechas los pone el servidor; límite de aportaciones por día.
create or replace function public.community_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recent integer;
begin
  if tg_op = 'INSERT' then
    new.user_id := auth.uid();
    new.created_at := now();
    if tg_table_name = 'parking_reviews' then
      new.updated_at := now();
    end if;
    select (select count(*) from public.parking_prices  where user_id = new.user_id and created_at > now() - interval '1 day')
         + (select count(*) from public.parking_reviews where user_id = new.user_id and created_at > now() - interval '1 day')
         + (select count(*) from public.parking_photos  where user_id = new.user_id and created_at > now() - interval '1 day')
      into recent;
    if recent >= 30 then
      raise exception 'rate_limited' using errcode = 'P0001', hint = 'Máximo 30 aportaciones al día';
    end if;
  else  -- UPDATE (solo opiniones)
    new.user_id := old.user_id;
    new.parking_id := old.parking_id;
    new.created_at := old.created_at;
    new.updated_at := now();
  end if;
  return new;
end;
$$;
revoke execute on function public.community_guard() from public, anon, authenticated;

create trigger parking_prices_guard  before insert            on public.parking_prices  for each row execute function public.community_guard();
create trigger parking_reviews_guard before insert or update  on public.parking_reviews for each row execute function public.community_guard();
create trigger parking_photos_guard  before insert            on public.parking_photos  for each row execute function public.community_guard();

-- Resumen de un parking para la ficha.
create or replace function public.parking_summary(p_id text)
returns table (reviews integer, avg_rating numeric, prices integer, photos integer, last_price_at timestamptz)
language sql
stable
set search_path = ''
as $$
  select
    (select count(*)::int from public.parking_reviews r where r.parking_id = p_id),
    (select round(avg(r.rating), 1) from public.parking_reviews r where r.parking_id = p_id),
    (select count(*)::int from public.parking_prices p where p.parking_id = p_id),
    (select count(*)::int from public.parking_photos f where f.parking_id = p_id),
    (select max(p.created_at) from public.parking_prices p where p.parking_id = p_id);
$$;
grant execute on function public.parking_summary(text) to anon, authenticated;

-- ------------------------------------------------------------------ fotos (Storage)

-- Público para leer (las fotos se ven sin cuenta); 2 MB; solo JPEG/PNG.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('parking-photos', 'parking-photos', true, 2097152, array['image/jpeg', 'image/png'])
on conflict (id) do update set
  public = excluded.public, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy parking_photos_storage_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'parking-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy parking_photos_storage_delete on storage.objects for delete to authenticated
  using (bucket_id = 'parking-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
-- Sin política de select: un bucket público sirve los archivos por URL sin
-- necesitarla, y así nadie puede listar todas las fotos por la API.

-- ------------------------------------------------------------------ moderación

create table public.reports (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid not null default auth.uid() references auth.users on delete cascade,
  target_type  text not null check (target_type in ('price', 'review', 'photo', 'user')),
  target_id    text not null check (char_length(target_id) <= 100),
  reason       text not null check (reason in ('spam', 'offensive', 'false', 'personal_data', 'other')),
  details      text check (char_length(details) <= 1000),
  created_at   timestamptz not null default now(),
  resolved_at  timestamptz,
  unique (reporter_id, target_type, target_id)
);
alter table public.reports enable row level security;
create policy reports_insert on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()) and resolved_at is null);
-- sin select: las denuncias solo se leen desde el panel de Supabase
revoke select, update, delete on public.reports from anon, authenticated;
revoke insert on public.reports from anon;

create table public.user_blocks (
  blocker_id  uuid not null default auth.uid() references auth.users on delete cascade,
  blocked_id  uuid not null references auth.users on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table public.user_blocks enable row level security;
create policy user_blocks_read   on public.user_blocks for select to authenticated using (blocker_id = (select auth.uid()));
create policy user_blocks_insert on public.user_blocks for insert to authenticated with check (blocker_id = (select auth.uid()));
create policy user_blocks_delete on public.user_blocks for delete to authenticated using (blocker_id = (select auth.uid()));
revoke all on public.user_blocks from anon;
revoke update on public.user_blocks from authenticated;

-- ------------------------------------------------------------------ borrar la cuenta

-- Borra al usuario y, en cascada, su perfil, aportaciones, denuncias y bloqueos.
-- Los archivos de Storage los borra antes la app (Supabase no deja borrarlos por SQL).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not_authenticated';
  end if;
  delete from auth.users where id = me;
end;
$$;
revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
