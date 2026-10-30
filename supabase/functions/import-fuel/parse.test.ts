// Tests del parser (Node 24: node --test supabase/functions/import-fuel/parse.test.ts)
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import { chunk, esNumber, FUELS, inSpain, parseMiteco } from "./parse.ts";

test("esNumber convierte comas decimales", () => {
  assert.equal(esNumber("1,459"), 1.459);
  assert.equal(esNumber(" 28,4567 "), 28.4567);
  assert.equal(esNumber(""), null);
  assert.equal(esNumber(undefined), null);
  assert.equal(esNumber("abc"), null);
});

test("inSpain: península, Canarias y fuera", () => {
  assert.ok(inSpain(40.4, -3.7)); // Madrid
  assert.ok(inSpain(28.46, -16.25)); // Santa Cruz de Tenerife
  assert.ok(!inSpain(0, 0));
  assert.ok(!inSpain(48.85, 2.35)); // París
});

test("parseMiteco descarta coordenadas 0,0 y normaliza", () => {
  const { rows, skipped } = parseMiteco({
    ListaEESSPrecio: [
      { IDEESS: "1", Latitud: "28,463", "Longitud (WGS84)": "-16,251", "C.P.": "3801",
        "Rótulo": "  REPSOL ", "Precio Gasoleo A": "1,709", "Precio Gasolina 95 E5": "",
        "Precio Adblue": "0,000" },
      { IDEESS: "2", Latitud: "0,000000", "Longitud (WGS84)": "0,000000" },
      { IDEESS: "x", Latitud: "40,0", "Longitud (WGS84)": "-3,0" },
    ],
  });
  assert.equal(skipped, 2);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].brand, "REPSOL");
  assert.equal(rows[0].postcode, "03801");
  assert.deepEqual(rows[0].prices, { gasoleo_a: 1.709 });
});

test("chunk", () => {
  assert.deepEqual(chunk([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
});

const real = new URL("../../../data/raw/miteco_estaciones.json", import.meta.url);
test("datos reales del MITECO (si están descargados)", { skip: !existsSync(real) }, () => {
  const data = JSON.parse(readFileSync(real, "utf-8").replace(/^﻿/, ""));
  const { rows, skipped } = parseMiteco(data);
  assert.ok(rows.length > 10000, `solo ${rows.length}`);
  assert.ok(skipped < 50, `descartadas ${skipped}`);
  const keys = new Set(rows.flatMap((r) => Object.keys(r.prices)));
  // todos los combustibles de FUELS existen en la fuente (detecta renombres)
  const fields = new Set(Object.keys(data.ListaEESSPrecio[0]));
  for (const f of Object.keys(FUELS)) assert.ok(fields.has(f), `falta el campo ${f}`);
  assert.ok(keys.has("gasoleo_a") && keys.has("gasolina_95_e5"));
  console.log(`  ${rows.length} filas, ${skipped} descartadas, combustibles: ${[...keys].join(", ")}`);
});
