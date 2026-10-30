-- Prueba de las migraciones 001 y 002. Pegar en el SQL Editor DESPUÉS de ejecutarlas.
-- Todo va dentro de un bloque que termina con un error a propósito: así se
-- deshace todo y no queda ningún dato de prueba. El resultado sale en el mensaje
-- del error: cada línea debe decir OK.

do $$
declare
  res   text := '';
  n     integer;
  ok    boolean;
  u_a   uuid := gen_random_uuid();
  u_b   uuid := gen_random_uuid();
  run   timestamptz := now();
  rid   uuid;
begin
  -- ---------------------------------------------------------- importación (como postgres)
  perform public.import_fuel_batch(jsonb_build_array(
    jsonb_build_object('id', 999001, 'brand', 'TEST A', 'lat', 28.46, 'lon', -16.25, 'province_id', '38',
                       'prices', jsonb_build_object('gasoleo_a', 1.5, 'gasolina_95_e5', 1.4)),
    jsonb_build_object('id', 999002, 'brand', 'TEST B', 'lat', 28.47, 'lon', -16.26, 'province_id', '38',
                       'prices', jsonb_build_object('gasolina_95_e5', 1.3))
  ), run);
  perform public.import_fuel_finish(run, run, 2);
  select count(*) into n from public.fuel_prices where station_id in (999001, 999002);
  res := res || format(E'\n%s importar gasolineras (3 precios: %s)', case when n = 3 then 'OK' else 'FALLO' end, n);

  -- un segundo import sin el diésel lo borra
  perform public.import_fuel_batch(jsonb_build_array(
    jsonb_build_object('id', 999001, 'brand', 'TEST A', 'lat', 28.46, 'lon', -16.25, 'province_id', '38',
                       'prices', jsonb_build_object('gasolina_95_e5', 1.45))), run);
  select count(*) into n from public.fuel_prices where station_id = 999001;
  res := res || format(E'\n%s precio que desaparece se borra (%s)', case when n = 1 then 'OK' else 'FALLO' end, n);

  select count(*) into n from public.fuel_daily_stats where province_id = '38' and day = current_date;
  res := res || format(E'\n%s resumen diario (%s filas)', case when n > 0 then 'OK' else 'FALLO' end, n);

  perform public.import_chargers_batch(jsonb_build_array(jsonb_build_object(
    'id', 'TEST-C1', 'name', 'Cargador test', 'lat', 28.46, 'lon', -16.25, 'points', 2, 'max_power_kw', 150,
    'connectors', '[{"type":"ccs2","power_kw":150,"count":1}]'::jsonb)), run);
  perform public.import_parkings_batch(jsonb_build_array(jsonb_build_object(
    'id', 'osm:node/999', 'name', 'Parking test', 'lat', 28.46, 'lon', -16.25, 'fee', true)), run);

  -- ---------------------------------------------------------- anon (sin cuenta)
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);

  select count(*) into n from public.map_points('fuel', -16.3, 28.4, -16.2, 28.5, 15, 'gasolina_95_e5', 0);
  res := res || format(E'\n%s anon ve el mapa de gasolineras (%s)', case when n >= 2 then 'OK' else 'FALLO' end, n);
  select count(*) into n from public.map_points('fuel', -18, 27, 4, 44, 5, 'gasolina_95_e5', 0) where count > 1 or id like '9990%';
  res := res || format(E'\n%s con poco zoom agrupa (%s filas)', case when n >= 1 then 'OK' else 'FALLO' end, n);
  select count(*) into n from public.fuel_near(28.46, -16.25, 5000, 'gasolina_95_e5') where id in (999001, 999002);
  res := res || format(E'\n%s fuel_near (%s)', case when n = 2 then 'OK' else 'FALLO' end, n);
  select count(*) into n from public.chargers_near(28.46, -16.25, 5000, 100) where id = 'TEST-C1';
  res := res || format(E'\n%s chargers_near con 100 kW (%s)', case when n = 1 then 'OK' else 'FALLO' end, n);

  begin
    insert into public.fuel_stations (id, location) values (1, 'POINT(0 0)');
    res := res || E'\nFALLO anon pudo escribir en fuel_stations';
  exception when others then res := res || E'\nOK anon no escribe en fuel_stations';
  end;
  begin
    perform public.import_fuel_batch('[]'::jsonb, now());
    res := res || E'\nFALLO anon pudo llamar a import_fuel_batch';
  exception when others then res := res || E'\nOK anon no puede importar';
  end;
  begin
    insert into public.parking_prices (parking_id, kind, amount) values ('osm:node/999', 'hour', 2);
    res := res || E'\nFALLO anon pudo aportar un precio';
  exception when others then res := res || E'\nOK anon no aporta precios';
  end;
  begin
    select count(*) into n from public.import_runs;
    res := res || format(E'\n%s anon no lee import_runs (%s)', case when n = 0 then 'OK' else 'FALLO' end, n);
  exception when others then res := res || E'\nOK anon no lee import_runs';
  end;

  -- ---------------------------------------------------------- usuarios A y B
  perform set_config('role', 'postgres', true);
  insert into auth.users (id, email, raw_user_meta_data, aud, role)
  values (u_a, 'test-a@example.com', '{"full_name":"Ana Test"}', 'authenticated', 'authenticated'),
         (u_b, 'test-b@example.com', '{}', 'authenticated', 'authenticated');
  select count(*) into n from public.profiles where id in (u_a, u_b);
  res := res || format(E'\n%s perfiles creados por el trigger (%s)', case when n = 2 then 'OK' else 'FALLO' end, n);
  select (display_name = 'Ana Test') into ok from public.profiles where id = u_a;
  res := res || format(E'\n%s nombre de Google/Apple en el perfil', case when ok then 'OK' else 'FALLO' end);

  -- A aporta
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', u_a, 'role', 'authenticated')::text, true);
  insert into public.parking_prices (parking_id, kind, amount, user_id) values ('osm:node/999', 'hour', 2.5, u_b);
  select count(*) into n from public.parking_prices where parking_id = 'osm:node/999' and user_id = u_a;
  res := res || format(E'\n%s el autor lo pone el servidor aunque se mande otro (%s)', case when n = 1 then 'OK' else 'FALLO' end, n);
  insert into public.parking_reviews (parking_id, rating, comment) values ('osm:node/999', 4, 'Bien') returning id into rid;
  begin
    insert into public.parking_reviews (parking_id, rating) values ('osm:node/999', 5);
    res := res || E'\nFALLO dos opiniones del mismo usuario';
  exception when unique_violation then res := res || E'\nOK una opinión por persona';
  end;
  begin
    insert into public.parking_prices (parking_id, kind, amount) values ('osm:node/999', 'hour', 5000);
    res := res || E'\nFALLO importe absurdo aceptado';
  exception when check_violation then res := res || E'\nOK importe fuera de rango rechazado';
  end;
  begin
    insert into public.parking_photos (parking_id, storage_path)
    values ('osm:node/999', u_b::text || '/' || gen_random_uuid()::text || '.jpg');
    res := res || E'\nFALLO foto en la carpeta de otro';
  exception when check_violation then res := res || E'\nOK foto solo en la carpeta propia';
  end;
  insert into public.reports (target_type, target_id, reason) values ('review', rid::text, 'spam');
  res := res || E'\nOK denunciar';

  -- B intenta tocar lo de A
  perform set_config('request.jwt.claims', json_build_object('sub', u_b, 'role', 'authenticated')::text, true);
  update public.parking_reviews set rating = 1 where id = rid;
  get diagnostics n = row_count;
  res := res || format(E'\n%s B no edita la opinión de A (%s filas)', case when n = 0 then 'OK' else 'FALLO' end, n);
  delete from public.parking_prices where parking_id = 'osm:node/999';
  get diagnostics n = row_count;
  res := res || format(E'\n%s B no borra precios de A (%s filas)', case when n = 0 then 'OK' else 'FALLO' end, n);
  begin
    select count(*) into n from public.reports;
    res := res || format(E'\n%s B no lee denuncias (%s)', case when n = 0 then 'OK' else 'FALLO' end, n);
  exception when others then res := res || E'\nOK B no lee denuncias';
  end;
  insert into public.user_blocks (blocked_id) values (u_a);
  select count(*) into n from public.user_blocks;
  res := res || format(E'\n%s B bloquea a A y solo ve sus bloqueos (%s)', case when n = 1 then 'OK' else 'FALLO' end, n);
  begin
    update public.profiles set display_name = 'Hackeado' where id = u_a;
    get diagnostics n = row_count;
    res := res || format(E'\n%s B no cambia el nombre de A (%s filas)', case when n = 0 then 'OK' else 'FALLO' end, n);
  exception when others then res := res || E'\nOK B no cambia el nombre de A';
  end;

  -- A edita su opinión: el servidor conserva el autor
  perform set_config('request.jwt.claims', json_build_object('sub', u_a, 'role', 'authenticated')::text, true);
  update public.parking_reviews set rating = 5 where id = rid;
  get diagnostics n = row_count;
  res := res || format(E'\n%s A edita su opinión (%s)', case when n = 1 then 'OK' else 'FALLO' end, n);

  -- A borra su cuenta: se va todo en cascada
  perform public.delete_my_account();
  perform set_config('role', 'postgres', true);
  select count(*) into n from public.parking_reviews where id = rid;
  res := res || format(E'\n%s borrar cuenta borra sus opiniones (%s)', case when n = 0 then 'OK' else 'FALLO' end, n);

  raise exception 'RESULTADO (todo se deshace):%', res;
end;
$$;
