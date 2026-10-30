"""Prueba de las fuentes de datos de Tinerfuel (toda España).

Descarga las fuentes reales, las analiza y escribe un resumen en pantalla y en
data/probe_report.json. Solo usa la biblioteca estándar de Python.

Uso (desde la raíz del proyecto):
    python -I tool/probe_sources.py            # descarga y analiza
    python -I tool/probe_sources.py --offline  # reutiliza lo ya descargado en data/raw/
    python -I tool/probe_sources.py --no-osm   # sin las consultas a Overpass (lentas)
"""

import argparse
import json
import statistics
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
REPORT = ROOT / "data" / "probe_report.json"

MITECO_URL = (
    "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/"
    "PreciosCarburantes/EstacionesTerrestres/"
)
DGT_URL = (
    "https://nap.dgt.es/datex2/v3/miterd/"
    "EnergyInfrastructureTablePublication/electrolineras.xml"
)
OVERPASS_URL = "https://overpass-api.de/api/interpreter"
USER_AGENT = "Tinerfuel-probe/0.1 (prueba de fuentes)"

# Cajas aproximadas (lat_min, lat_max, lon_min, lon_max) para comprobar coordenadas.
BOXES = {
    "peninsula_baleares": (35.9, 43.9, -9.4, 4.4),
    "canarias": (27.6, 29.5, -18.2, -13.3),
    "ceuta": (35.86, 35.93, -5.39, -5.27),
    "melilla": (35.26, 35.32, -2.97, -2.92),
}
CANARIAS_PROV = {"35", "38"}
CEUTA_MELILLA_PROV = {"51", "52"}


def log(msg=""):
    print(msg, flush=True)


def download(url, dest, timeout=300):
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as resp, open(dest, "wb") as f:
        while chunk := resp.read(1 << 16):
            f.write(chunk)
    secs = time.time() - t0
    size = dest.stat().st_size
    log(f"  descargado {dest.name}: {size / 1e6:.1f} MB en {secs:.1f} s")
    return {"bytes": size, "seconds": round(secs, 1)}


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
        return None
    for name, (a, b, c, d) in BOXES.items():
        if a <= lat <= b and c <= lon <= d:
            return name
    return None


def price_stats(values):
    if not values:
        return None
    values = sorted(values)
    return {
        "n": len(values),
        "min": values[0],
        "mediana": round(statistics.median(values), 3),
        "max": values[-1],
    }


# ---------------------------------------------------------------- MITECO


def probe_miteco(offline):
    log("\n== Gasolineras (MITECO) ==")
    path = RAW / "miteco_estaciones.json"
    info = {"url": MITECO_URL}
    if not offline:
        info["descarga"] = download(MITECO_URL, path)
    data = json.loads(path.read_text(encoding="utf-8-sig"))

    stations = data.get("ListaEESSPrecio", [])
    info["fecha_fuente"] = data.get("Fecha")
    info["resultado"] = data.get("ResultadoConsulta")
    info["total"] = len(stations)

    by_prov = Counter()
    zones = Counter()
    bad_coords = []
    prices = {}  # combustible -> {"peninsula": [...], "canarias": [...], ...}
    fields = Counter()

    for s in stations:
        fields.update(s.keys())
        prov_id = s.get("IDProvincia", "")
        by_prov[s.get("Provincia", "?")] += 1
        lat = es_float(s.get("Latitud"))
        lon = es_float(s.get("Longitud (WGS84)"))
        zone = in_spain(lat, lon)
        zones[zone or "FUERA"] += 1
        if zone is None:
            bad_coords.append(
                {
                    "id": s.get("IDEESS"),
                    "rotulo": s.get("Rótulo"),
                    "municipio": s.get("Municipio"),
                    "lat": s.get("Latitud"),
                    "lon": s.get("Longitud (WGS84)"),
                }
            )

        if prov_id in CANARIAS_PROV:
            area = "canarias"
        elif prov_id in CEUTA_MELILLA_PROV:
            area = "ceuta_melilla"
        else:
            area = "peninsula_baleares"

        for key, value in s.items():
            if key.startswith("Precio "):
                p = es_float(value)
                if p is not None:
                    prices.setdefault(key[len("Precio ") :], {}).setdefault(area, []).append(p)

    info["campos"] = sorted(fields)
    info["por_zona_coordenadas"] = dict(zones)
    info["coordenadas_fuera_de_espana"] = bad_coords[:20]
    info["n_coordenadas_fuera"] = len(bad_coords)
    info["por_provincia"] = dict(by_prov.most_common())
    info["precios"] = {
        fuel: {area: price_stats(v) for area, v in areas.items()}
        for fuel, areas in sorted(prices.items(), key=lambda kv: -sum(map(len, kv[1].values())))
    }

    log(f"  fecha de la fuente: {info['fecha_fuente']}  ({info['resultado']})")
    log(f"  gasolineras: {info['total']}  en {len(by_prov)} provincias")
    log(f"  coordenadas: {dict(zones)}")
    if bad_coords:
        log(f"  ejemplos fuera de España: {bad_coords[:3]}")
    log("  precios (n / mín / mediana / máx) por zona:")
    for fuel, areas in list(info["precios"].items())[:8]:
        parts = []
        for area, st in areas.items():
            parts.append(f"{area}: {st['n']} / {st['min']} / {st['mediana']} / {st['max']}")
        log(f"    {fuel}: " + " | ".join(parts))
    return info


# ---------------------------------------------------------------- DGT

NS = {
    "com": "http://datex2.eu/schema/3/common",
    "loc": "http://datex2.eu/schema/3/locationReferencing",
    "locx": "http://datex2.eu/schema/3/locationExtension",
    "fac": "http://datex2.eu/schema/3/facilities",
    "egi": "http://datex2.eu/schema/3/energyInfrastructure",
}
SITE_TAG = f"{{{NS['egi']}}}energyInfrastructureSite"


def probe_dgt(offline):
    log("\n== Puntos de carga (DGT, DATEX II) ==")
    path = RAW / "dgt_electrolineras.xml"
    info = {"url": DGT_URL}
    if not offline:
        info["descarga"] = download(DGT_URL, path)

    sites = 0
    points = 0
    connectors = Counter()
    power_buckets = Counter()
    operators = Counter()
    provinces = Counter()
    zones = Counter()
    years = Counter()
    site_types = Counter()
    bad_coords = []
    publication_time = None

    for event, elem in ET.iterparse(path, events=("end",)):
        if elem.tag == f"{{{NS['com']}}}publicationTime" and publication_time is None:
            publication_time = elem.text
        if elem.tag != SITE_TAG:
            continue
        sites += 1
        lat = es_float(elem.findtext(".//loc:coordinatesForDisplay/loc:latitude", namespaces=NS))
        lon = es_float(elem.findtext(".//loc:coordinatesForDisplay/loc:longitude", namespaces=NS))
        zone = in_spain(lat, lon)
        zones[zone or "FUERA"] += 1
        if zone is None and len(bad_coords) < 20:
            bad_coords.append({"id": elem.get("id"), "lat": lat, "lon": lon})

        for line in elem.iterfind(".//locx:addressLine/locx:text/com:values/com:value", NS):
            if line.text and line.text.startswith("Provincia: "):
                provinces[line.text[len("Provincia: ") :]] += 1

        op = elem.findtext("fac:operator/fac:name/com:values/com:value", namespaces=NS)
        operators[op or "?"] += 1
        site_types[elem.findtext("egi:typeOfSite", namespaces=NS) or "?"] += 1
        updated = elem.findtext("fac:lastUpdated", namespaces=NS)
        years[(updated or "????")[:4]] += 1

        for rp in elem.iterfind(".//egi:refillPoint", NS):
            points += 1
        for c in elem.iterfind(".//egi:connector", NS):
            connectors[c.findtext("egi:connectorType", namespaces=NS) or "?"] += 1
            w = es_float(c.findtext("egi:maxPowerAtSocket", namespaces=NS))
            if w is None:
                power_buckets["?"] += 1
            elif w < 7_500:
                power_buckets["<7,5 kW (lenta)"] += 1
            elif w < 23_000:
                power_buckets["7,5-22 kW (semirrápida)"] += 1
            elif w < 100_000:
                power_buckets["23-99 kW (rápida)"] += 1
            else:
                power_buckets[">=100 kW (ultrarrápida)"] += 1
        elem.clear()

    info.update(
        {
            "fecha_publicacion": publication_time,
            "ubicaciones": sites,
            "puntos_de_recarga": points,
            "conectores": dict(connectors.most_common()),
            "potencia": dict(power_buckets.most_common()),
            "por_zona_coordenadas": dict(zones),
            "coordenadas_fuera_de_espana": bad_coords,
            "por_provincia": dict(provinces.most_common()),
            "operadores_top20": dict(operators.most_common(20)),
            "n_operadores": len(operators),
            "tipo_de_sitio": dict(site_types.most_common()),
            "ultima_actualizacion_por_anio": dict(sorted(years.items())),
        }
    )
    log(f"  publicación: {publication_time}")
    log(f"  ubicaciones: {sites}  puntos: {points}  conectores: {sum(connectors.values())}")
    log(f"  coordenadas: {dict(zones)}")
    log(f"  provincias: {len(provinces)}  operadores: {len(operators)}")
    log(f"  conectores: {dict(connectors.most_common(5))}")
    log(f"  potencia: {dict(power_buckets.most_common())}")
    log(f"  última actualización (año): {dict(sorted(years.items()))}")
    return info


# ---------------------------------------------------------------- OpenStreetMap


def overpass_count(selector):
    query = (
        '[out:json][timeout:300];area["ISO3166-1"="ES"][admin_level=2]->.es;'
        f"({selector});out count;"
    )
    body = urllib.parse.urlencode({"data": query}).encode()
    req = urllib.request.Request(OVERPASS_URL, data=body, headers={"User-Agent": USER_AGENT})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=360) as resp:
        data = json.load(resp)
    tags = data["elements"][0]["tags"]
    return {k: int(v) for k, v in tags.items()}, round(time.time() - t0, 1)


def probe_osm():
    log("\n== OpenStreetMap (Overpass, solo recuentos) ==")
    queries = {
        "cargadores (amenity=charging_station)": 'nwr["amenity"="charging_station"](area.es);',
        "parkings (amenity=parking, todos)": 'nwr["amenity"="parking"](area.es);',
        "parkings con nombre": 'nwr["amenity"="parking"]["name"](area.es);',
        "parkings de pago (fee=yes)": 'nwr["amenity"="parking"]["fee"="yes"](area.es);',
        "parkings subterráneos o de varias plantas": 'nwr["amenity"="parking"]["parking"~"^(underground|multi-storey)$"](area.es);',
    }
    info = {}
    for label, selector in queries.items():
        try:
            counts, secs = overpass_count(selector)
            info[label] = counts
            log(f"  {label}: {counts.get('total')}  ({secs} s)")
        except Exception as e:  # Overpass falla a menudo por carga: se apunta y se sigue
            info[label] = {"error": str(e)}
            log(f"  {label}: ERROR {e}")
        time.sleep(5)  # no saturar el servidor público
    return info


# ----------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--offline", action="store_true", help="usar data/raw/ sin descargar")
    ap.add_argument("--no-osm", action="store_true", help="saltar las consultas a Overpass")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    report = {"generado": datetime.now(timezone.utc).isoformat(timespec="seconds")}
    for name, fn in (("miteco", lambda: probe_miteco(args.offline)), ("dgt", lambda: probe_dgt(args.offline))):
        try:
            report[name] = fn()
        except Exception as e:
            report[name] = {"error": repr(e)}
            log(f"  ERROR: {e!r}")
    if not args.no_osm:
        report["osm"] = probe_osm()

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"\nInforme completo en {REPORT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
