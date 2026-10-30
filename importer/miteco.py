"""Importa los precios de las gasolineras del MITECO (~12 MB, cada 30 min).

Lo mismo que la Edge Function import-fuel (parse.ts), pero desde GitHub Actions:
el servidor del MITECO solo acepta el cifrado TLS 1.2 AES256-GCM-SHA384 (sin
ECDHE), que las Edge Functions (rustls) no admiten (ver CLAUDE.md).

Uso:
    python -I importer/miteco.py --dry-run     # descarga y guarda las filas en data/raw/miteco_rows.json
    python -I importer/miteco.py --offline ... # usa data/raw/miteco.json ya descargado
    python -I importer/miteco.py               # sube a Supabase (SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY)
"""

import argparse
import json
import ssl
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import RAW, clean, download, es_float, in_spain, log, run_import  # noqa: E402

MITECO_URL = "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/"

# Campo del MITECO -> clave normalizada (las mismas que FUELS en parse.ts y fuelKeys en la app).
FUELS = {
    "Precio Gasolina 95 E5": "gasolina_95_e5",
    "Precio Gasolina 95 E10": "gasolina_95_e10",
    "Precio Gasolina 95 E5 Premium": "gasolina_95_e5_premium",
    "Precio Gasolina 98 E5": "gasolina_98_e5",
    "Precio Gasolina 98 E10": "gasolina_98_e10",
    "Precio Gasoleo A": "gasoleo_a",
    "Precio Gasoleo Premium": "gasoleo_premium",
    "Precio Gasoleo B": "gasoleo_b",
    "Precio Diésel Renovable": "diesel_renovable",
    "Precio Gasolina Renovable": "gasolina_renovable",
    "Precio Gases licuados del petróleo": "glp",
    "Precio Gas Natural Comprimido": "gnc",
    "Precio Gas Natural Licuado": "gnl",
    "Precio Hidrogeno": "hidrogeno",
    "Precio Adblue": "adblue",
}


def miteco_tls():
    """Contexto TLS normal (verifica el certificado) que además admite el único
    cifrado que acepta el MITECO; Python 3.10+ ya no lo ofrece por defecto."""
    ctx = ssl.create_default_context()
    ctx.set_ciphers("DEFAULT:AES256-GCM-SHA384")
    return ctx


def parse_station(s):
    """Una gasolinera del MITECO -> fila para import_fuel_batch (o None si no vale)."""
    try:
        station_id = int(str(s.get("IDEESS", "")).strip())
    except ValueError:
        return None
    lat, lon = es_float(s.get("Latitud")), es_float(s.get("Longitud (WGS84)"))
    if station_id <= 0 or not in_spain(lat, lon):
        return None
    prices = {}
    for field, key in FUELS.items():
        p = es_float(s.get(field))
        # precios absurdos (0 o > 10 €) se descartan: los rechazaría la tabla
        if p is not None and 0 < p < 10:
            prices[key] = p
    postcode = clean(s.get("C.P."))
    return {
        "id": station_id,
        "brand": clean(s.get("Rótulo")),
        "address": clean(s.get("Dirección")),
        "municipality": clean(s.get("Municipio")),
        "province": clean(s.get("Provincia")),
        "province_id": clean(s.get("IDProvincia")),
        "postcode": postcode.zfill(5) if postcode else None,
        "lat": lat,
        "lon": lon,
        "opening_hours": clean(s.get("Horario")),
        "sale_type": clean(s.get("Tipo Venta")),
        "prices": prices,
    }


def parse_file(path):
    data = json.loads(path.read_bytes().decode("utf-8-sig"))
    if data.get("ResultadoConsulta") != "OK":
        raise RuntimeError(f"MITECO: {data.get('ResultadoConsulta')}")
    rows, skipped = [], 0
    for s in data.get("ListaEESSPrecio") or []:
        row = parse_station(s)
        if row:
            rows.append(row)
        else:
            skipped += 1
    return rows, skipped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="no subir: guardar las filas en data/raw/")
    ap.add_argument("--offline", action="store_true", help="no descargar: usar el JSON de data/raw/")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    log("== Importar gasolineras (MITECO) ==")
    path = RAW / "miteco.json"
    if not args.offline:
        download(MITECO_URL, path, timeout=120, context=miteco_tls())
    rows, skipped = parse_file(path)
    log(f"  {len(rows)} gasolineras válidas, {skipped} descartadas")
    run_import("miteco", rows, "import_fuel_batch", 1000, args.dry_run, min_rows=5000,
               finish_rpc="import_fuel_finish")


if __name__ == "__main__":
    main()
