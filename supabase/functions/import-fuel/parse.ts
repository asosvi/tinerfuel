// Convierte la respuesta del MITECO en filas para import_fuel_batch.
// Sin dependencias: se usa en la Edge Function (Deno) y en los tests (Node).

export type MitecoStation = Record<string, string | undefined>;

export interface FuelRow {
  id: number;
  brand: string | null;
  address: string | null;
  municipality: string | null;
  province: string | null;
  province_id: string | null;
  postcode: string | null;
  lat: number;
  lon: number;
  opening_hours: string | null;
  sale_type: string | null;
  prices: Record<string, number>;
}

// Nombre del campo del MITECO ("Precio Gasoleo A") -> clave normalizada.
// Solo los combustibles que se muestran en la app; el resto se ignora.
export const FUELS: Record<string, string> = {
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
};

// Cajas aproximadas de España (lat_min, lat_max, lon_min, lon_max).
const SPAIN_BOXES: [number, number, number, number][] = [
  [35.9, 43.9, -9.4, 4.4], // península y Baleares
  [27.6, 29.5, -18.2, -13.3], // Canarias
  [35.86, 35.93, -5.39, -5.27], // Ceuta
  [35.26, 35.32, -2.97, -2.92], // Melilla
];

/** "1,459" -> 1.459; vacío o no numérico -> null. */
export function esNumber(text: string | undefined | null): number | null {
  if (text == null) return null;
  const t = String(text).trim().replace(",", ".");
  if (t === "") return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

export function inSpain(lat: number, lon: number): boolean {
  return SPAIN_BOXES.some(([a, b, c, d]) => lat >= a && lat <= b && lon >= c && lon <= d);
}

function clean(text: string | undefined): string | null {
  const t = (text ?? "").replace(/\s+/g, " ").trim();
  return t === "" ? null : t;
}

/** Filas válidas y número de descartadas (sin id, coordenadas fuera de España...). */
export function parseMiteco(data: { ListaEESSPrecio?: MitecoStation[] }): {
  rows: FuelRow[];
  skipped: number;
} {
  const rows: FuelRow[] = [];
  let skipped = 0;
  for (const s of data.ListaEESSPrecio ?? []) {
    const id = Number(s["IDEESS"]);
    const lat = esNumber(s["Latitud"]);
    const lon = esNumber(s["Longitud (WGS84)"]);
    if (!Number.isInteger(id) || id <= 0 || lat == null || lon == null || !inSpain(lat, lon)) {
      skipped++;
      continue;
    }
    const prices: Record<string, number> = {};
    for (const [field, key] of Object.entries(FUELS)) {
      const p = esNumber(s[field]);
      // precios absurdos (0 o > 10 €) se descartan: los rechazaría la tabla
      if (p != null && p > 0 && p < 10) prices[key] = p;
    }
    const cp = clean(s["C.P."]);
    rows.push({
      id,
      brand: clean(s["Rótulo"]),
      address: clean(s["Dirección"]),
      municipality: clean(s["Municipio"]),
      province: clean(s["Provincia"]),
      province_id: clean(s["IDProvincia"]),
      postcode: cp ? cp.padStart(5, "0") : null,
      lat,
      lon,
      opening_hours: clean(s["Horario"]),
      sale_type: clean(s["Tipo Venta"]),
      prices,
    });
  }
  return { rows, skipped };
}

export function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}
