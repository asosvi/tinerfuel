"""Importa los puntos de carga de la DGT (DATEX II v3, ~83 MB, cada 24 h).

Uso:
    python -I importer/dgt.py --dry-run     # descarga y guarda las filas en data/raw/dgt_rows.json
    python -I importer/dgt.py --offline ... # usa data/raw/dgt_electrolineras.xml ya descargado
    python -I importer/dgt.py               # sube a Supabase (SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY)
"""

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import RAW, clean, download, es_float, in_spain, log, run_import  # noqa: E402

DGT_URL = "https://nap.dgt.es/datex2/v3/miterd/EnergyInfrastructureTablePublication/electrolineras.xml"

NS = {
    "com": "http://datex2.eu/schema/3/common",
    "loc": "http://datex2.eu/schema/3/locationReferencing",
    "locx": "http://datex2.eu/schema/3/locationExtension",
    "fac": "http://datex2.eu/schema/3/facilities",
    "egi": "http://datex2.eu/schema/3/energyInfrastructure",
}
SITE_TAG = f"{{{NS['egi']}}}energyInfrastructureSite"

# Tipos de conector de DATEX II -> nombre corto que muestra la app.
CONNECTORS = {
    "iec62196T2": "type2",
    "iec62196T2COMBO": "ccs2",
    "chademo": "chademo",
    "domesticF": "schuko",
    "domesticE": "schuko",
    "iec62196T1": "type1",
    "iec62196T1COMBO": "ccs1",
    "iec60309x2single16": "cee16",
    "iec60309x2three32": "cee32",
}


def parse_site(elem):
    """Un energyInfrastructureSite -> fila para import_chargers_batch (o None si no vale)."""
    lat = es_float(elem.findtext(".//loc:coordinatesForDisplay/loc:latitude", namespaces=NS))
    lon = es_float(elem.findtext(".//loc:coordinatesForDisplay/loc:longitude", namespaces=NS))
    site_id = elem.get("id")
    if not site_id or not in_spain(lat, lon):
        return None

    # Las líneas de dirección vienen como "Dirección: ...", "Municipio: ...", "Provincia: ...".
    parts = {}
    for line in elem.iterfind(".//locx:addressLine/locx:text/com:values/com:value", NS):
        label, sep, value = (clean(line.text) or "").partition(": ")
        if sep:
            parts[label] = clean(value)
    address, municipality, province = parts.get("Dirección"), parts.get("Municipio"), parts.get("Provincia")
    postcode = clean(elem.findtext(".//locx:postcode", namespaces=NS))
    if postcode and postcode.isdigit():
        postcode = postcode.zfill(5)

    # Conectores agrupados por (tipo, modo, potencia) con su número.
    groups = {}
    points = 0
    for _ in elem.iterfind(".//egi:refillPoint", NS):
        points += 1
    for c in elem.iterfind(".//egi:connector", NS):
        raw_type = c.findtext("egi:connectorType", namespaces=NS) or "other"
        watts = es_float(c.findtext("egi:maxPowerAtSocket", namespaces=NS))
        kw = round(watts / 1000, 1) if watts else None
        key = (CONNECTORS.get(raw_type, "other"), c.findtext("egi:chargingMode", namespaces=NS), kw)
        groups[key] = groups.get(key, 0) + 1
    connectors = [
        {"type": t, "mode": m, "power_kw": kw, "count": n}
        for (t, m, kw), n in sorted(groups.items(), key=lambda kv: -(kv[0][2] or 0))
    ]
    powers = [c["power_kw"] for c in connectors if c["power_kw"]]

    return {
        "id": site_id,
        "name": clean(elem.findtext("fac:name/com:values/com:value", namespaces=NS)),
        "operator": clean(elem.findtext("fac:operator/fac:name/com:values/com:value", namespaces=NS)),
        "address": address,
        "municipality": municipality,
        "province": province,
        "postcode": postcode,
        "lat": lat,
        "lon": lon,
        "opening_hours": clean(elem.findtext("fac:operatingHours/fac:label", namespaces=NS)),
        "points": points,
        "max_power_kw": max(powers) if powers else None,
        "connectors": connectors,
        "source_updated": clean(elem.findtext("fac:lastUpdated", namespaces=NS)),
    }


def parse_file(path):
    rows, skipped = [], 0
    for _, elem in ET.iterparse(path, events=("end",)):
        if elem.tag != SITE_TAG:
            continue
        row = parse_site(elem)
        if row:
            rows.append(row)
        else:
            skipped += 1
        elem.clear()
    return rows, skipped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="no subir: guardar las filas en data/raw/")
    ap.add_argument("--offline", action="store_true", help="no descargar: usar el XML de data/raw/")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    log("== Importar cargadores (DGT) ==")
    path = RAW / "dgt_electrolineras.xml"
    if not args.offline:
        download(DGT_URL, path)
    rows, skipped = parse_file(path)
    log(f"  {len(rows)} ubicaciones válidas, {skipped} descartadas")
    run_import("dgt", rows, "import_chargers_batch", 1000, args.dry_run, min_rows=5000)


if __name__ == "__main__":
    main()
