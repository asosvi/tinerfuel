-- 003_schedule.sql: importar los precios del MITECO cada 30 minutos.
--
-- pg_cron llama a la Edge Function `import-fuel` con pg_net. La URL del
-- proyecto y el secreto compartido se guardan en Vault (no en este archivo).
-- ANTES de ejecutar esta migración, en el SQL Editor:
--   select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--   select vault.create_secret('<secreto largo aleatorio>', 'cron_secret');
-- y el mismo secreto en la función:  supabase secrets set CRON_SECRET=<secreto>
--
-- Una sola ejecución cada 30 min, sin reintentos: si falla, la siguiente lo
-- vuelve a intentar (regla: nada que se relance solo en bucle).

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'import-fuel',
  '7,37 * * * *',   -- a los :07 y :37 de cada hora
  $$
  select net.http_post(
    url     := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/import-fuel',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body    := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);

-- Limpieza: borrar el historial de ejecuciones de import_runs de más de 90 días
-- y el de pg_cron de más de 7 días (si no, crecen sin límite).
select cron.schedule(
  'cleanup-logs',
  '30 4 * * *',
  $$
  delete from public.import_runs where started_at < now() - interval '90 days';
  delete from cron.job_run_details where end_time < now() - interval '7 days';
  delete from public.fuel_daily_stats where day < current_date - interval '3 years';
  $$
);
