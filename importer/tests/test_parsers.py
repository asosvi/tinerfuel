"""Tests de los importadores:  python -I -m unittest discover -s importer/tests"""

import sys
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from common import es_float, in_spain  # noqa: E402
from dgt import parse_site  # noqa: E402
from miteco import FUELS, parse_station  # noqa: E402
from osm import ZONES, parse_element, query_for, to_bool  # noqa: E402

SITE = """<egi:energyInfrastructureSite id="S1" version=""
  xmlns:egi="http://datex2.eu/schema/3/energyInfrastructure"
  xmlns:fac="http://datex2.eu/schema/3/facilities"
  xmlns:com="http://datex2.eu/schema/3/common"
  xmlns:loc="http://datex2.eu/schema/3/locationReferencing"
  xmlns:locx="http://datex2.eu/schema/3/locationExtension">
  <fac:name><com:values><com:value lang="es">Cargador Test</com:value></com:values></fac:name>
  <fac:lastUpdated>2025-01-02T03:04:05.000+01:00</fac:lastUpdated>
  <fac:locationReference>
    <loc:_locationReferenceExtension><loc:facilityLocation><locx:address>
      <locx:postcode>7011</locx:postcode>
      <locx:addressLine order="1"><locx:text><com:values><com:value lang="es">Dirección: Calle Mayor 1</com:value></com:values></locx:text></locx:addressLine>
      <locx:addressLine order="2"><locx:text><com:values><com:value lang="es">Municipio: Palma</com:value></com:values></locx:text></locx:addressLine>
      <locx:addressLine order="3"><locx:text><com:values><com:value lang="es">Provincia: Balears, Illes</com:value></com:values></locx:text></locx:addressLine>
    </locx:address></loc:facilityLocation></loc:_locationReferenceExtension>
    <loc:coordinatesForDisplay><loc:latitude>39.59</loc:latitude><loc:longitude>2.63</loc:longitude></loc:coordinatesForDisplay>
  </fac:locationReference>
  <fac:operator><fac:name><com:values><com:value lang="es">Operador SL</com:value></com:values></fac:name></fac:operator>
  <egi:energyInfrastructureStation id="S1_1">
    <egi:refillPoint id="P1">
      <egi:connector><egi:connectorType>iec62196T2</egi:connectorType><egi:chargingMode>mode3AC3p</egi:chargingMode><egi:maxPowerAtSocket>22000.0</egi:maxPowerAtSocket></egi:connector>
      <egi:connector><egi:connectorType>iec62196T2COMBO</egi:connectorType><egi:chargingMode>mode4DC</egi:chargingMode><egi:maxPowerAtSocket>150000.0</egi:maxPowerAtSocket></egi:connector>
    </egi:refillPoint>
    <egi:refillPoint id="P2">
      <egi:connector><egi:connectorType>iec62196T2</egi:connectorType><egi:chargingMode>mode3AC3p</egi:chargingMode><egi:maxPowerAtSocket>22000.0</egi:maxPowerAtSocket></egi:connector>
    </egi:refillPoint>
  </egi:energyInfrastructureStation>
</egi:energyInfrastructureSite>"""


class CommonTest(unittest.TestCase):
    def test_es_float(self):
        self.assertEqual(es_float("1,459"), 1.459)
        self.assertIsNone(es_float(""))
        self.assertIsNone(es_float(None))

    def test_in_spain(self):
        self.assertTrue(in_spain(28.46, -16.25))
        self.assertFalse(in_spain(0.0, 0.0))
        self.assertFalse(in_spain(None, None))


class DgtTest(unittest.TestCase):
    def test_parse_site(self):
        row = parse_site(ET.fromstring(SITE))
        self.assertEqual(row["id"], "S1")
        self.assertEqual(row["address"], "Calle Mayor 1")
        self.assertEqual(row["municipality"], "Palma")
        self.assertEqual(row["postcode"], "07011")
        self.assertEqual(row["operator"], "Operador SL")
        self.assertEqual(row["points"], 2)
        self.assertEqual(row["max_power_kw"], 150.0)
        # agrupado por tipo/modo/potencia, de más a menos potencia
        self.assertEqual(row["connectors"][0], {"type": "ccs2", "mode": "mode4DC", "power_kw": 150.0, "count": 1})
        self.assertEqual(row["connectors"][1]["count"], 2)

    def test_site_outside_spain_is_skipped(self):
        xml = SITE.replace("<loc:latitude>39.59", "<loc:latitude>0").replace("<loc:longitude>2.63", "<loc:longitude>0")
        self.assertIsNone(parse_site(ET.fromstring(xml)))


class MitecoTest(unittest.TestCase):
    STATION = {
        "IDEESS": "4375", "Rótulo": " REPSOL ", "Dirección": "AVENIDA  TRES DE MAYO, 5",
        "Municipio": "Santa Cruz de Tenerife", "Provincia": "SANTA CRUZ DE TENERIFE", "IDProvincia": "38",
        "C.P.": "38005", "Latitud": "28,460722", "Longitud (WGS84)": "-16,256111",
        "Horario": "L-D: 24H", "Tipo Venta": "P",
        "Precio Gasolina 95 E5": "1,559", "Precio Gasoleo A": "1,409", "Precio Gasolina 98 E5": "",
        "Precio Adblue": "0,000",
    }

    def test_parse_station(self):
        row = parse_station(self.STATION)
        self.assertEqual(row["id"], 4375)
        self.assertEqual(row["brand"], "REPSOL")
        self.assertEqual(row["address"], "AVENIDA TRES DE MAYO, 5")
        self.assertAlmostEqual(row["lat"], 28.460722)
        # vacío y 0 no son precios
        self.assertEqual(row["prices"], {"gasolina_95_e5": 1.559, "gasoleo_a": 1.409})

    def test_bad_stations_are_skipped(self):
        self.assertIsNone(parse_station({**self.STATION, "Latitud": "0,000000", "Longitud (WGS84)": "0,000000"}))
        self.assertIsNone(parse_station({**self.STATION, "IDEESS": ""}))

    def test_postcode_is_padded(self):
        self.assertEqual(parse_station({**self.STATION, "C.P.": "7011"})["postcode"], "07011")

    def test_same_fuels_as_edge_function(self):
        ts = (Path(__file__).resolve().parents[2] / "supabase/functions/import-fuel/parse.ts").read_text("utf-8")
        for field, key in FUELS.items():
            self.assertIn(f'"{field}": "{key}"', ts)


class OsmTest(unittest.TestCase):
    def test_parse_way_uses_center(self):
        row = parse_element({
            "type": "way", "id": 5, "center": {"lat": 28.47, "lon": -16.25},
            "tags": {"amenity": "parking", "name": " Parking  Centro ", "fee": "yes",
                     "parking": "underground", "capacity": "250"},
        })
        self.assertEqual(row["id"], "osm:way/5")
        self.assertEqual(row["name"], "Parking Centro")
        self.assertTrue(row["fee"])
        self.assertEqual(row["kind"], "underground")
        self.assertEqual(row["capacity"], 250)

    def test_bad_values(self):
        row = parse_element({"type": "node", "id": 1, "lat": 40.4, "lon": -3.7,
                             "tags": {"capacity": "approx 50", "fee": "Mo-Fr 08:00-20:00", "parking": "weird"}})
        self.assertIsNone(row["capacity"])
        self.assertIsNone(row["fee"])
        self.assertIsNone(row["kind"])
        self.assertIsNone(parse_element({"type": "node", "id": 2, "lat": 48.8, "lon": 2.3, "tags": {}}))

    def test_to_bool(self):
        self.assertTrue(to_bool("yes"))
        self.assertFalse(to_bool("no"))
        self.assertIsNone(to_bool(None))

    def test_zones_cover_spain(self):
        self.assertEqual(len(ZONES), 18)
        for city, (lat, lon) in {"Madrid": (40.42, -3.70), "Barcelona": (41.39, 2.17), "A Coruña": (43.36, -8.41),
                                 "Palma": (39.57, 2.65), "Cádiz": (36.53, -6.29), "Tenerife": (28.46, -16.25),
                                 "Ceuta": (35.89, -5.32), "Melilla": (35.29, -2.94)}.items():
            self.assertTrue(any(s <= lat <= n and w <= lon <= e for s, w, n, e in ZONES.values()), city)

    def test_query_excludes_private(self):
        q = query_for(ZONES["canarias"])
        self.assertIn('"access"!~"^(private|no|customers', q)
        self.assertIn("out center tags", q)


if __name__ == "__main__":
    unittest.main()
