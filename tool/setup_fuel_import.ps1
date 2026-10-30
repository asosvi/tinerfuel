# Pone en marcha la importación de precios del MITECO (una sola vez, o para
# cambiar el secreto). Lo ejecuta el usuario, no Claude:
#   powershell -ExecutionPolicy Bypass -File tool/setup_fuel_import.ps1
#
# 1. Genera un secreto aleatorio (no se muestra ni se guarda en el repo).
# 2. Lo guarda en Vault (project_url, cron_secret) y en la Edge Function (CRON_SECRET).
# 3. Publica la Edge Function import-fuel.
# 4. Ejecuta supabase/migrations/003_schedule.sql (pg_cron cada 30 min).
# 5. Lanza la primera importación.

$ErrorActionPreference = 'Stop'
$ref = 'uzxxnomzoosfarrdiwyb'
$url = "https://$ref.supabase.co"
if ($PSScriptRoot) { Set-Location (Split-Path $PSScriptRoot -Parent) }
if (-not (Test-Path supabase/migrations/003_schedule.sql)) { throw 'Ejecutar desde la carpeta del proyecto' }

function Run([string]$what) {
  Write-Host "`n== $what" -ForegroundColor Cyan
}
function Check {
  if ($LASTEXITCODE -ne 0) { throw "Ha fallado el paso anterior (código $LASTEXITCODE)" }
}

$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$secret = -join ($bytes | ForEach-Object { $_.ToString('x2') })   # 64 caracteres

Run 'Guardando los secretos en Vault'
$sql = Join-Path $env:TEMP "tinerfuel_vault_$PID.sql"
@"
do `$`$
declare sid uuid;
begin
  select id into sid from vault.secrets where name = 'project_url';
  if sid is null then perform vault.create_secret('$url', 'project_url');
  else perform vault.update_secret(sid, '$url'); end if;
  select id into sid from vault.secrets where name = 'cron_secret';
  if sid is null then perform vault.create_secret('$secret', 'cron_secret');
  else perform vault.update_secret(sid, '$secret'); end if;
end
`$`$;
"@ | Set-Content -Encoding ascii $sql
try {
  npx.cmd supabase db query --linked --project-ref $ref -f $sql; Check
} finally {
  Remove-Item $sql -Force -ErrorAction SilentlyContinue
}

Run 'Guardando CRON_SECRET en la Edge Function'
npx.cmd supabase secrets set --project-ref $ref "CRON_SECRET=$secret"; Check

Run 'Publicando la Edge Function import-fuel'
npx.cmd supabase functions deploy import-fuel --project-ref $ref --no-verify-jwt --use-api; Check

Run 'Programando la importación cada 30 min (003_schedule.sql)'
npx.cmd supabase db query --linked --project-ref $ref -f supabase/migrations/003_schedule.sql; Check

Run 'Primera importación (tarda unos 30 s)'
$r = Invoke-WebRequest -UseBasicParsing -Method Post -Uri "$url/functions/v1/import-fuel" `
  -Headers @{ 'x-cron-secret' = $secret; 'Content-Type' = 'application/json' } -Body '{}' -TimeoutSec 150
Write-Host "Respuesta ($($r.StatusCode)): $($r.Content)"
Write-Host "`nListo." -ForegroundColor Green
