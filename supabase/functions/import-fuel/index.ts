// Edge Function: descarga los precios del MITECO y los guarda en la base de datos.
// La llama pg_cron cada 30 min (migración 003) con la cabecera x-cron-secret.
// Desplegar con:  supabase functions deploy import-fuel --no-verify-jwt
// (sin JWT porque se autentica con el secreto; SUPABASE_URL y
// SUPABASE_SERVICE_ROLE_KEY las pone Supabase solas).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { chunk, parseMiteco } from "./parse.ts";

const MITECO_URL =
  "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/";
const BATCH = 1000;

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  const secret = Deno.env.get("CRON_SECRET") ?? "";
  const given = req.headers.get("x-cron-secret") ?? "";
  if (secret.length < 32 || !timingSafeEqual(secret, given)) {
    return new Response("forbidden", { status: 403 });
  }

  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const startedAt = new Date().toISOString();

  try {
    const res = await fetch(MITECO_URL, {
      headers: { "User-Agent": "Tinerfuel/0.1 (importador)" },
      signal: AbortSignal.timeout(60_000),
    });
    if (!res.ok) throw new Error(`MITECO respondió ${res.status}`);
    const data = await res.json();
    if (data.ResultadoConsulta !== "OK") throw new Error(`MITECO: ${data.ResultadoConsulta}`);

    const { rows, skipped } = parseMiteco(data);
    // Si la fuente viene casi vacía, no desactivar todo: mejor fallar.
    if (rows.length < 5000) throw new Error(`Solo ${rows.length} gasolineras: respuesta sospechosa`);

    const runAt = new Date().toISOString();
    let total = 0;
    for (const part of chunk(rows, BATCH)) {
      const { data: n, error } = await db.rpc("import_fuel_batch", { rows: part, run_at: runAt });
      if (error) throw new Error(`import_fuel_batch: ${error.message}`);
      total += n ?? 0;
    }
    const { error } = await db.rpc("import_fuel_finish", {
      run_at: runAt,
      started_at: startedAt,
      total,
    });
    if (error) throw new Error(`import_fuel_finish: ${error.message}`);

    return Response.json({ ok: true, rows: total, skipped });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    await db.rpc("import_failed", { source: "miteco", started_at: startedAt, error: msg });
    return Response.json({ ok: false, error: msg }, { status: 500 });
  }
});
