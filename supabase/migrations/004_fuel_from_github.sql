-- 004_fuel_from_github.sql: los precios del MITECO ya no los descarga la Edge
-- Function import-fuel sino GitHub Actions (.github/workflows/import_fuel.yml).
--
-- El servidor del MITECO solo acepta el cifrado TLS 1.2 AES256-GCM-SHA384 (sin
-- ECDHE) y las Edge Functions (rustls) no lo admiten: cada llamada acababa en
-- "Connection reset by peer". Se quita la tarea de pg_cron que la llamaba.
-- La limpieza diaria (cleanup-logs) de 003 se queda.

select cron.unschedule('import-fuel')
where exists (select 1 from cron.job where jobname = 'import-fuel');
