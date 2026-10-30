-- 001_init.sql: datos importados (gasolineras, precios, cargadores, parkings)
-- y funciones de lectura para el mapa.
--
-- Los datos importados solo los escribe el importador con la service_role
-- (a través de las funciones import_*). La app (anon y authenticated) solo lee.

create extension if not exists postgis with schema extensions;

-- ------------------------------------------------------------------ tablas

create table public.fuel_stations (
  id            bigint primary key,                 -- IDEESS del MITECO
  brand         text,                               -- Rótulo
  address       text,
  municipality  text,
  province      text,
  province_id   text,                               -- código INE de 2 cifras
  postcode      text,
  location      extensions.geography(Point, 4326) not null,
  opening_hours text,
  sale_type     text,                               -- 'P' público, 'R' restringido
  active        boolean not null default true,      -- false si deja de salir en la fuente
  seen_at       timestamptz not null default now(), -- última importación en la que salió
  updated_at    timestamptz not null default now()
);
create index fuel_stations_location_idx on public.fuel_stations using gist (location);
create index fuel_stations_province_idx on public.fuel_stations (province_id);

create table public.fuel_prices (
  station_id  bigint not null references public.fuel_stations on delete cascade,
  fuel        text not null,                        -- clave normalizada, p. ej. 'gasoleo_a'
  price       numeric(6, 3) not null check (price > 0 and price < 10),
  updated_at  timestamptz not null default now(),
  primary key (station_id, fuel)
);
create index fuel_prices_fuel_price_idx on public.fuel_prices (fuel, price);

-- Resumen diario por provincia (no se guarda el histórico de cada gasolinera:
-- 11.000 gasolineras × 8 combustibles × 365 días no cabe en el plan gratis).
create table public.fuel_daily_stats (
  day          date not null,
  province_id  text not null,
  fuel         text not null,
  n            integer not null,
  min_price    numeric(6, 3) not null,
  median_price numeric(6, 3) not null,
  avg_price    numeric(6, 3) not null,
  primary key (day, province_id, fuel)
);

create table public.chargers (
  id             text primary key,                  -- id del sitio en la DGT
  name           text,
  operator       text,
  address        text,
  municipality   text,
  province       text,
  postcode       text,
  location       extensions.geography(Point, 4326) not null,
  opening_hours  text,
  points         integer not null default 0,        -- puntos de recarga
  max_power_kw   numeric(7, 1),
  connectors     jsonb not null default '[]'::jsonb,-- [{type, mode, power_kw, count}]
  source_updated timestamptz,                       -- lastUpdated de la DGT
  active         boolean not null default true,
  seen_at        timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index chargers_location_idx on public.chargers using gist (location);
create index chargers_power_idx on public.chargers (max_power_kw);

create table public.parkings (
  id          text primary key,                     -- 'osm:node/123', 'osm:way/456'...
  name        text,
  operator    text,
  kind        text,                                 -- surface, underground, multi-storey...
  fee         boolean,                              -- de pago según OSM (null = no se sabe)
  capacity    integer,
  access      text,
  location    extensions.geography(Point, 4326) not null,
  active      boolean not null default true,
  seen_at     timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index parkings_location_idx on public.parkings using gist (location);

create table public.import_runs (
  id          bigint generated always as identity primary key,
  source      text not null,                        -- 'miteco', 'dgt', 'osm'
  started_at  timestamptz not null,
  finished_at timestamptz,
  ok          boolean,
  rows        integer,
  error       text
);
create index import_runs_source_idx on public.import_runs (source, started_at desc);

-- ------------------------------------------------------------------ RLS
-- Lectura para todos (la app se puede usar sin cuenta). Ninguna política de
-- escritura: solo la service_role (que se salta la RLS) escribe.

alter table public.fuel_stations    enable row level security;
alter table public.fuel_prices      enable row level security;
alter table public.fuel_daily_stats enable row level security;
alter table public.chargers         enable row level security;
alter table public.parkings         enable row level security;
alter table public.import_runs      enable row level security;

create policy fuel_stations_read    on public.fuel_stations    for select to anon, authenticated using (true);
create policy fuel_prices_read      on public.fuel_prices      for select to anon, authenticated using (true);
create policy fuel_daily_stats_read on public.fuel_daily_stats for select to anon, authenticated using (true);
create policy chargers_read         on public.chargers         for select to anon, authenticated using (true);
create policy parkings_read         on public.parkings         for select to anon, authenticated using (true);
-- import_runs: sin políticas (solo se consulta desde el panel); la app usa data_freshness().

revoke insert, update, delete, truncate on
  public.fuel_stations, public.fuel_prices, public.fuel_daily_stats,
  public.chargers, public.parkings, public.import_runs
  from anon, authenticated;

-- ------------------------------------------------------------------ lectura para el mapa

-- Puntos visibles en una caja. Con zoom bajo agrupa en una rejilla
-- (count > 1 = grupo) para no mandar 11.000 puntos al móvil.
-- kind: 'fuel' | 'charger' | 'parking'.
-- fuel: combustible para el precio (solo kind = 'fuel').
-- min_kw: potencia mínima (solo kind = 'charger').
create or replace function public.map_points(
  kind text,
  min_lon double precision, min_lat double precision,
  max_lon double precision, max_lat double precision,
  zoom integer,
  fuel text default 'gasolina_95_e5',
  min_kw numeric default 0
)
returns table (
  id        text,
  lat       double precision,
  lon       double precision,
  count     integer,
  label     text,      -- marca / nombre (solo puntos sueltos)
  price     numeric,   -- precio del combustible (fuel) o mínimo del grupo
  power_kw  numeric    -- potencia máxima (charger) o máxima del grupo
)
language plpgsql
stable
set search_path = ''
as $$
#variable_conflict use_column
declare
  bbox  extensions.geometry := extensions.st_makeenvelope(min_lon, min_lat, max_lon, max_lat, 4326);
  -- tamaño de celda en grados: con zoom >= 13 no se agrupa
  cell  double precision := case when zoom >= 13 then 0 else 360.0 / power(2, greatest(zoom, 3)) / 6 end;
begin
  if kind not in ('fuel', 'charger', 'parking') then
    raise exception 'kind no válido: %', kind;
  end if;
  -- límite de seguridad del tamaño de la caja (toda España cabe de sobra)
  if (max_lon - min_lon) > 40 or (max_lat - min_lat) > 30 then
    raise exception 'caja demasiado grande';
  end if;

  if kind = 'fuel' then
    return query
    with pts as (
      select s.id::text as id, s.location::extensions.geometry as g, s.brand as label, p.price
      from public.fuel_stations s
      left join public.fuel_prices p on p.station_id = s.id and p.fuel = map_points.fuel
      where s.active and s.location::extensions.geometry operator(extensions.&&) bbox
    )
    select * from public._group_points(
      (select coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'lat', extensions.st_y(g), 'lon', extensions.st_x(g),
        'label', label, 'price', price)), '[]') from pts),
      cell);
  elsif kind = 'charger' then
    return query
    with pts as (
      select c.id, c.location::extensions.geometry as g, coalesce(c.name, c.operator) as label, c.max_power_kw
      from public.chargers c
      where c.active and coalesce(c.max_power_kw, 0) >= min_kw
        and c.location::extensions.geometry operator(extensions.&&) bbox
    )
    select * from public._group_points(
      (select coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'lat', extensions.st_y(g), 'lon', extensions.st_x(g),
        'label', label, 'power_kw', max_power_kw)), '[]') from pts),
      cell);
  else
    return query
    with pts as (
      select k.id, k.location::extensions.geometry as g, k.name as label
      from public.parkings k
      where k.active and k.location::extensions.geometry operator(extensions.&&) bbox
    )
    select * from public._group_points(
      (select coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'lat', extensions.st_y(g), 'lon', extensions.st_x(g),
        'label', label)), '[]') from pts),
      cell);
  end if;
end;
$$;

-- Agrupa puntos (jsonb) en celdas de 'cell' grados. cell = 0: sin agrupar.
create or replace function public._group_points(pts jsonb, cell double precision)
returns table (
  id text, lat double precision, lon double precision, count integer,
  label text, price numeric, power_kw numeric
)
language sql
immutable
set search_path = ''
as $$
  with p as (
    select x->>'id' as id, (x->>'lat')::float8 as lat, (x->>'lon')::float8 as lon,
           x->>'label' as label, (x->>'price')::numeric as price, (x->>'power_kw')::numeric as power_kw
    from jsonb_array_elements(pts) x
  )
  select
    case when count(*) = 1 then min(p.id) else null end,
    avg(p.lat), avg(p.lon), count(*)::int,
    case when count(*) = 1 then min(p.label) else null end,
    min(p.price), max(p.power_kw)
  from p
  group by
    case when cell > 0 then floor(p.lat / cell) else null end,
    case when cell > 0 then floor(p.lon / cell) else null end,
    case when cell > 0 then null else p.id end
  limit 3000;
$$;

-- Gasolineras cercanas ordenadas por precio o distancia (para la lista).
create or replace function public.fuel_near(
  lat double precision, lon double precision,
  radius_m integer default 10000,
  fuel text default 'gasolina_95_e5',
  order_by text default 'price',     -- 'price' | 'distance'
  max_rows integer default 50
)
returns table (
  id bigint, brand text, address text, municipality text,
  lat double precision, lon double precision,
  price numeric, price_updated timestamptz, distance_m double precision
)
language sql
stable
set search_path = ''
as $$
  with me as (select extensions.st_setsrid(extensions.st_makepoint(lon, lat), 4326)::extensions.geography as g)
  select s.id, s.brand, s.address, s.municipality,
         extensions.st_y(s.location::extensions.geometry), extensions.st_x(s.location::extensions.geometry),
         p.price, p.updated_at,
         extensions.st_distance(s.location, me.g)
  from public.fuel_stations s
  join public.fuel_prices p on p.station_id = s.id and p.fuel = fuel_near.fuel
  cross join me
  where s.active
    and extensions.st_dwithin(s.location, me.g, least(radius_m, 100000))
  order by
    case when order_by = 'distance' then extensions.st_distance(s.location, me.g) end,
    p.price,
    extensions.st_distance(s.location, me.g)
  limit least(max_rows, 200);
$$;

-- Cargadores cercanos (ordenados por distancia).
create or replace function public.chargers_near(
  lat double precision, lon double precision,
  radius_m integer default 10000,
  min_kw numeric default 0,
  max_rows integer default 50
)
returns table (
  id text, name text, operator text, address text, municipality text,
  lat double precision, lon double precision,
  points integer, max_power_kw numeric, connectors jsonb, distance_m double precision
)
language sql
stable
set search_path = ''
as $$
  with me as (select extensions.st_setsrid(extensions.st_makepoint(lon, lat), 4326)::extensions.geography as g)
  select c.id, c.name, c.operator, c.address, c.municipality,
         extensions.st_y(c.location::extensions.geometry), extensions.st_x(c.location::extensions.geometry),
         c.points, c.max_power_kw, c.connectors,
         extensions.st_distance(c.location, me.g)
  from public.chargers c cross join me
  where c.active and coalesce(c.max_power_kw, 0) >= min_kw
    and extensions.st_dwithin(c.location, me.g, least(radius_m, 100000))
  order by extensions.st_distance(c.location, me.g)
  limit least(max_rows, 200);
$$;

-- Fecha de la última importación correcta de cada fuente ("Actualizado hace 20 min").
create or replace function public.data_freshness()
returns table (source text, finished_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select r.source, max(r.finished_at)
  from public.import_runs r
  where r.ok
  group by r.source;
$$;

-- ------------------------------------------------------------------ importación (solo service_role)

create or replace function public.import_fuel_batch(rows jsonb, run_at timestamptz)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.fuel_stations as s
    (id, brand, address, municipality, province, province_id, postcode, location,
     opening_hours, sale_type, active, seen_at, updated_at)
  select (r->>'id')::bigint, r->>'brand', r->>'address', r->>'municipality', r->>'province',
         r->>'province_id', r->>'postcode',
         extensions.st_setsrid(extensions.st_makepoint((r->>'lon')::float8, (r->>'lat')::float8), 4326)::extensions.geography,
         r->>'opening_hours', r->>'sale_type', true, run_at, run_at
  from jsonb_array_elements(rows) r
  on conflict (id) do update set
    brand = excluded.brand, address = excluded.address, municipality = excluded.municipality,
    province = excluded.province, province_id = excluded.province_id, postcode = excluded.postcode,
    location = excluded.location, opening_hours = excluded.opening_hours, sale_type = excluded.sale_type,
    active = true, seen_at = excluded.seen_at,
    updated_at = case
      when (s.brand, s.address, s.opening_hours, s.location::text)
           is distinct from (excluded.brand, excluded.address, excluded.opening_hours, excluded.location::text)
      then excluded.updated_at else s.updated_at end;
  get diagnostics n = row_count;

  -- precios: los que vienen se insertan/actualizan; los que ya no vienen se borran
  delete from public.fuel_prices p
  using jsonb_array_elements(rows) r
  where p.station_id = (r->>'id')::bigint
    and not (r->'prices' ? p.fuel);

  insert into public.fuel_prices as p (station_id, fuel, price, updated_at)
  select (r->>'id')::bigint, kv.key, (kv.value)::text::numeric, run_at
  from jsonb_array_elements(rows) r, jsonb_each(r->'prices') kv
  on conflict (station_id, fuel) do update set
    price = excluded.price,
    updated_at = case when p.price is distinct from excluded.price then excluded.updated_at else p.updated_at end;

  return n;
end;
$$;

-- Al terminar: desactiva lo que no salió en esta importación, guarda el
-- resumen del día y apunta la ejecución.
create or replace function public.import_fuel_finish(run_at timestamptz, started_at timestamptz, total integer)
returns void
language plpgsql
set search_path = ''
as $$
begin
  update public.fuel_stations set active = false where active and seen_at < run_at;

  insert into public.fuel_daily_stats as d (day, province_id, fuel, n, min_price, median_price, avg_price)
  select (run_at at time zone 'Europe/Madrid')::date, s.province_id, p.fuel, count(*),
         min(p.price),
         percentile_cont(0.5) within group (order by p.price)::numeric(6, 3),
         avg(p.price)::numeric(6, 3)
  from public.fuel_prices p join public.fuel_stations s on s.id = p.station_id
  where s.active and s.province_id is not null
  group by s.province_id, p.fuel
  on conflict (day, province_id, fuel) do update set
    n = excluded.n, min_price = excluded.min_price,
    median_price = excluded.median_price, avg_price = excluded.avg_price;

  insert into public.import_runs (source, started_at, finished_at, ok, rows)
  values ('miteco', started_at, now(), true, total);
end;
$$;

create or replace function public.import_chargers_batch(rows jsonb, run_at timestamptz)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.chargers as c
    (id, name, operator, address, municipality, province, postcode, location, opening_hours,
     points, max_power_kw, connectors, source_updated, active, seen_at, updated_at)
  select r->>'id', r->>'name', r->>'operator', r->>'address', r->>'municipality', r->>'province',
         r->>'postcode',
         extensions.st_setsrid(extensions.st_makepoint((r->>'lon')::float8, (r->>'lat')::float8), 4326)::extensions.geography,
         r->>'opening_hours', coalesce((r->>'points')::int, 0), (r->>'max_power_kw')::numeric,
         coalesce(r->'connectors', '[]'::jsonb), (r->>'source_updated')::timestamptz,
         true, run_at, run_at
  from jsonb_array_elements(rows) r
  on conflict (id) do update set
    name = excluded.name, operator = excluded.operator, address = excluded.address,
    municipality = excluded.municipality, province = excluded.province, postcode = excluded.postcode,
    location = excluded.location, opening_hours = excluded.opening_hours, points = excluded.points,
    max_power_kw = excluded.max_power_kw, connectors = excluded.connectors,
    source_updated = excluded.source_updated, active = true, seen_at = excluded.seen_at,
    updated_at = case when c.source_updated is distinct from excluded.source_updated
                      then excluded.updated_at else c.updated_at end;
  get diagnostics n = row_count;
  return n;
end;
$$;

create or replace function public.import_parkings_batch(rows jsonb, run_at timestamptz)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  n integer;
begin
  insert into public.parkings as k
    (id, name, operator, kind, fee, capacity, access, location, active, seen_at, updated_at)
  select r->>'id', r->>'name', r->>'operator', r->>'kind', (r->>'fee')::boolean,
         (r->>'capacity')::int, r->>'access',
         extensions.st_setsrid(extensions.st_makepoint((r->>'lon')::float8, (r->>'lat')::float8), 4326)::extensions.geography,
         true, run_at, run_at
  from jsonb_array_elements(rows) r
  on conflict (id) do update set
    name = excluded.name, operator = excluded.operator, kind = excluded.kind, fee = excluded.fee,
    capacity = excluded.capacity, access = excluded.access, location = excluded.location,
    active = true, seen_at = excluded.seen_at, updated_at = excluded.updated_at;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Final genérico para cargadores y parkings.
create or replace function public.import_finish(source text, run_at timestamptz, started_at timestamptz, total integer)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if source = 'dgt' then
    update public.chargers set active = false where active and seen_at < run_at;
  elsif source = 'osm' then
    update public.parkings set active = false where active and seen_at < run_at;
  else
    raise exception 'fuente no válida: %', source;
  end if;
  insert into public.import_runs (source, started_at, finished_at, ok, rows)
  values (source, started_at, now(), true, total);
end;
$$;

create or replace function public.import_failed(source text, started_at timestamptz, error text)
returns void
language sql
set search_path = ''
as $$
  insert into public.import_runs (source, started_at, finished_at, ok, error)
  values (source, started_at, now(), false, left(error, 2000));
$$;

-- Permisos: lectura para la app; importación solo para service_role.
revoke execute on function
  public.import_fuel_batch(jsonb, timestamptz),
  public.import_fuel_finish(timestamptz, timestamptz, integer),
  public.import_chargers_batch(jsonb, timestamptz),
  public.import_parkings_batch(jsonb, timestamptz),
  public.import_finish(text, timestamptz, timestamptz, integer),
  public.import_failed(text, timestamptz, text),
  public._group_points(jsonb, double precision)
  from public, anon, authenticated;
grant execute on function
  public.import_fuel_batch(jsonb, timestamptz),
  public.import_fuel_finish(timestamptz, timestamptz, integer),
  public.import_chargers_batch(jsonb, timestamptz),
  public.import_parkings_batch(jsonb, timestamptz),
  public.import_finish(text, timestamptz, timestamptz, integer),
  public.import_failed(text, timestamptz, text)
  to service_role;
-- _group_points la llama map_points (security invoker): hay que dejarla ejecutar.
grant execute on function public._group_points(jsonb, double precision) to anon, authenticated;
grant execute on function
  public.map_points(text, double precision, double precision, double precision, double precision, integer, text, numeric),
  public.fuel_near(double precision, double precision, integer, text, text, integer),
  public.chargers_near(double precision, double precision, integer, numeric, integer),
  public.data_freshness()
  to anon, authenticated;
