"""Importa parkings de OpenStreetMap (Overpass, por zonas) — una vez al mes.

Solo los que interesan a un conductor: con nombre, de pago, o subterráneos /
de varias plantas; nunca los privados. Se pide España por trozos para que
Overpass no dé 502 (una consulta de todo el país tarda 100 s y falla a menudo).

Uso:
    python -I importer/osm.py --dry-run               # todas las zonas, sin subir
    python -I importer/osm.py --dry-run --only canarias
    python -I importer/osm.py                         # sube a Supabase
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import USER_AGENT, clean, in_spain, log, run_import  # noqa: E402

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# Zonas (sur, oeste, norte, este). La península va en una rejilla de 4×4;
# el filtro area.es quita Portugal, Francia y Marruecos.
ZONES = {"canarias": (27.6, -18.2, 29.5, -13.3), "ceuta_melilla": (35.2, -5.4, 35.95, -2.9)}
_LAT = [35.9, 37.9, 39.9, 41.9, 43.9]
_LON = [-9.4, -5.95, -2.5, 0.95, 4.4]
for i in range(4):
    for j in range(4):
        ZONES[f"peninsula_{i}{j}"] = (_LAT[i], _LON[j], _LAT[i + 1], _LON[j + 1])

FILTER = '["amenity"="parking"]["access"!~"^(private|no|customers|permissive|delivery)$"]'
KINDS = ("surface", "underground", "multi-storey", "rooftop", "lane", "street_side", "layby")


def query_for(bbox):
    s, w, n, e = bbox
    b = f"({s},{w},{n},{e})"
    return (
        '[out:json][timeout:240];area["ISO3166-1"="ES"][admin_level=2]->.es;('
        f'nwr{FILTER}["name"](area.es){b};'
        f'nwr{FILTER}["fee"="yes"](area.es){b};'
        f'nwr{FILTER}["parking"~"^(underground|multi-storey)$"](area.es){b};'
        ");out center tags;"
    )


def fetch_zone(name, bbox, attempts=3):
    body = urllib.parse.urlencode({"data": query_for(bbox)}).encode()
    for attempt in range(1, attempts + 1):  # reintentos con límite (nunca en bucle)
        try:
            req = urllib.request.Request(OVERPASS_URL, data=body, headers={"User-Agent": USER_AGENT})
            t0 = time.time()
            with urllib.request.urlopen(req, timeout=300) as resp:
                data = json.load(resp)
            log(f"  {name}: {len(data.get('elements', []))} elementos ({time.time() - t0:.0f} s)")
            return data.get("elements", [])
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            log(f"  {name}: intento {attempt} falló ({e})")
            if attempt == attempts:
                raise
            time.sleep(30 * attempt)


def to_bool(value):
    if value is None:
        return None
    value = value.strip().lower()
    if value in ("yes", "true", "1"):
        return True
    if value in ("no", "false", "0"):
        return False
    return None  # "interval", horarios...: no se sabe


def parse_element(el):
    """Elemento de Overpass -> fila para import_parkings_batch (o None)."""
    if el.get("type") == "node":
        lat, lon = el.get("lat"), el.get("lon")
    else:
        center = el.get("center") or {}
        lat, lon = center.get("lat"), center.get("lon")
    if not in_spain(lat, lon):
        return None
    tags = el.get("tags", {})
    capacity = tags.get("capacity", "")
    kind = tags.get("parking")
    return {
        "id": f"osm:{el['type']}/{el['id']}",
        "name": clean(tags.get("name")),
        "operator": clean(tags.get("operator")),
        "kind": kind if kind in KINDS else None,
        "fee": to_bool(tags.get("fee")),
        "capacity": int(capacity) if capacity.isdigit() and int(capacity) < 100000 else None,
        "access": clean(tags.get("access")),
        "lat": round(lat, 7),
        "lon": round(lon, 7),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="no subir: guardar las filas en data/raw/")
    ap.add_argument("--only", help="solo una zona (p. ej. canarias), para probar")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    # --only no debe desactivar el resto del país al subir
    if args.only and not args.dry_run:
        sys.exit("--only solo se puede usar con --dry-run")
    zones = {args.only: ZONES[args.only]} if args.only else ZONES
    log(f"== Importar parkings (OSM, {len(zones)} zonas) ==")
    rows = {}
    for name, bbox in zones.items():
        for el in fetch_zone(name, bbox):
            row = parse_element(el)
            if row:
                rows[row["id"]] = row  # las zonas se tocan en los bordes: sin duplicados
        time.sleep(10)  # no saturar el servidor público
    rows = list(rows.values())
    log(f"  {len(rows)} parkings")
    run_import("osm", rows, "import_parkings_batch", 2000, args.dry_run, min_rows=5000)


if __name__ == "__main__":
    main()
