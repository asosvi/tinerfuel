"""Utilidades compartidas por los importadores (solo biblioteca estándar)."""

import json
import os
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
USER_AGENT = "Tinerfuel/0.1 (importador)"

# Cajas aproximadas de España (lat_min, lat_max, lon_min, lon_max).
SPAIN_BOXES = (
    (35.9, 43.9, -9.4, 4.4),  # península y Baleares
    (27.6, 29.5, -18.2, -13.3),  # Canarias
    (35.86, 35.93, -5.39, -5.27),  # Ceuta
    (35.26, 35.32, -2.97, -2.92),  # Melilla
)


def log(msg=""):
    print(msg, flush=True)


def now_iso():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def es_float(text):
    """'1,459' -> 1.459; '' o None -> None."""
    if text is None:
        return None
    text = str(text).strip().replace(",", ".")
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def in_spain(lat, lon):
    if lat is None or lon is None:
        return False
    return any(a <= lat <= b and c <= lon <= d for a, b, c, d in SPAIN_BOXES)


def clean(text):
    if text is None:
        return None
    text = " ".join(str(text).split())
    return text or None


def chunks(items, size):
    for i in range(0, len(items), size):
        yield items[i : i + size]


def download(url, dest, timeout=300, data=None, context=None):
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, data=data, headers={"User-Agent": USER_AGENT})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout, context=context) as resp, open(dest, "wb") as f:
        while chunk := resp.read(1 << 16):
            f.write(chunk)
    log(f"  descargado {dest.name}: {dest.stat().st_size / 1e6:.1f} MB en {time.time() - t0:.1f} s")


class Supabase:
    """Llamadas RPC a PostgREST con la service_role (solo en el servidor / CI)."""

    def __init__(self, url=None, key=None):
        self.url = (url or os.environ["SUPABASE_URL"]).rstrip("/")
        self.key = key or os.environ["SUPABASE_SERVICE_ROLE_KEY"]

    def rpc(self, name, payload, timeout=120):
        headers = {"apikey": self.key, "Content-Type": "application/json", "User-Agent": USER_AGENT}
        # La service_role antigua es un JWT; la clave nueva (sb_secret_...) no lo
        # es y basta con 'apikey'.
        if self.key.startswith("eyJ"):
            headers["Authorization"] = f"Bearer {self.key}"
        req = urllib.request.Request(
            f"{self.url}/rest/v1/rpc/{name}",
            data=json.dumps(payload).encode(),
            method="POST",
            headers=headers,
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                body = resp.read()
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"{name}: HTTP {e.code} {e.read()[:500]!r}") from None
        return json.loads(body) if body else None


def run_import(source, rows, batch_rpc, batch_size, dry_run, min_rows, finish_rpc="import_finish"):
    """Sube las filas por lotes y cierra la importación (o la marca como fallida).

    finish_rpc: import_finish (dgt, osm) o import_fuel_finish (miteco, sin 'source').
    """
    started_at = now_iso()
    if dry_run:
        out = RAW / f"{source}_rows.json"
        out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
        log(f"  --dry-run: {len(rows)} filas guardadas en {out.relative_to(ROOT)} (no se sube nada)")
        return
    db = Supabase()
    try:
        # Si la fuente viene casi vacía, no desactivar todo lo que hay: fallar.
        if len(rows) < min_rows:
            raise RuntimeError(f"solo {len(rows)} filas (mínimo {min_rows}): respuesta sospechosa")
        run_at = now_iso()
        total = 0
        for part in chunks(rows, batch_size):
            total += db.rpc(batch_rpc, {"rows": part, "run_at": run_at}) or 0
        finish = {"run_at": run_at, "started_at": started_at, "total": total}
        if finish_rpc == "import_finish":
            finish["source"] = source
        db.rpc(finish_rpc, finish)
        log(f"  subidas {total} filas")
    except Exception as e:
        db.rpc("import_failed", {"source": source, "started_at": started_at, "error": str(e)})
        raise
