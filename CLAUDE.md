# CLAUDE.md: app de gasolineras, cargadores y parkings de España

Este archivo resume lo esencial para trabajar en el proyecto. Parte de lo aprendido en **Deepslate** (`C:\Users\aleja\Documents\PROYECTO`, ver su `CLAUDE.md`): mismo usuario, mismo PC, mismas herramientas.

## Regla de mantenimiento (IMPORTANTE)

**Cada vez que se encuentre un fallo** (bug, error de compilación, problema de configuración, algo que no funciona en una plataforma, error en el plan...), **actualizar la sección "Fallos conocidos y lecciones"** de este archivo con:
- Fecha (AAAA-MM-DD)
- Qué falló y en qué plataforma
- Causa
- Solución o estado (resuelto / pendiente)

Si el fallo cambia una decisión del plan, actualizar también la sección correspondiente de este archivo.

**Si algo queda incierto** (una decisión de diseño, un dato que no se puede comprobar, una preferencia), **preguntar al usuario antes de seguir** y guardar la pregunta y la respuesta en la sección "Decisiones tomadas".

**Antes de escribir algo nuevo, buscar si ya existe** en el proyecto y reutilizarlo (una sola fuente de verdad para límites, colores, mensajes, diálogos y URLs).

## Objetivo

Aplicación para **web, Android e iOS** que muestra en un mapa y en una lista, para **toda España** (península, Baleares, Canarias, Ceuta y Melilla; ampliado el 2026-10-27, al principio era solo Tenerife):

1. **Gasolineras** con sus precios actualizados (gasolina 95/98, diésel, GLP...), para ordenarlas por precio o por distancia.
2. **Puntos de carga** para coches eléctricos e híbridos enchufables (ubicación, potencia, conectores y, cuando el operador lo publica, estado libre/ocupado y precio).
3. **Parkings**: **solo la ubicación** a partir de datos abiertos. **Los precios y los comentarios los aporta la comunidad** (usuarios registrados). Decidido por el usuario el 2026-10-27: no hay fuente pública de precios de parkings.

## Stack (heredado de Deepslate, ya probado en este PC)

| Parte | Tecnología | Por qué |
|---|---|---|
| App (web + Android + iOS) | **Flutter** (Dart), un solo código | Ya instalado y dominado (Flutter 3.47, Android SDK 36) |
| Estado | **Riverpod** | Igual que Deepslate |
| Mapa | **`flutter_map`** (OpenStreetMap); los grupos de puntos los calcula el servidor (`map_points`) | Gratis, sin clave de Google, funciona en las 3 plataformas |
| Backend | **Supabase** (Postgres + PostGIS + Auth + RLS + Storage) | Datos en caché, aportaciones de la comunidad, cuentas |
| Recogida de datos | **Python en GitHub Actions**: MITECO cada 30 min, DGT diario, OSM mensual (la Edge Function `import-fuel` no puede conectar con el MITECO) | Ver "Decisiones tomadas" y "Fallos conocidos" |
| Web | **Flutter web** en **Vercel** | Mismo flujo que deepslatenotes.com |
| iOS sin Mac | GitHub Actions (macOS) → `.ipa` / Codemagic + TestFlight | Ver "iOS sin Mac" |

**Principio clave:** la app **nunca** llama directamente a las fuentes externas (MITECO, DGT...). Un proceso del servidor las descarga, las normaliza y las guarda en Supabase; la app solo lee de Supabase. Así:
- La web no choca con CORS (la API del MITECO no está pensada para el navegador).
- Una sola descarga sirve a todos los usuarios (no saturamos al ministerio).
- Si una fuente se cae, la app sigue mostrando los últimos datos con su fecha ("Actualizado hace 25 min").

## Fuentes de datos

### Gasolineras: API del MITECO (pública, sin clave)
- Toda España en una sola llamada (~12.000 gasolineras):
  `https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/`
  (por provincia: `.../EstacionesTerrestres/FiltroProvincia/<código>`, útil para pruebas).
- Devuelve JSON con dirección, municipio, provincia, coordenadas, horario y precios. **Ojo:** los números vienen con **coma decimal** (`"1,459"`) y las coordenadas también: convertir al importar. Campos vacíos = ese combustible no se vende.
- Canarias (IGIC), Ceuta y Melilla tienen otra fiscalidad y precios muy distintos a la península: comparar y hacer medias **por zona**, no a nivel nacional.
- Se actualiza varias veces al día: descargar cada **30 min** basta. Guardar también el **histórico de precios** (permite gráficas de evolución en el futuro).
- Reutilización legal citando la fuente (Ley 37/2007): poner "Fuente: Ministerio para la Transición Ecológica" en la app.

### Cargadores eléctricos
- **Principal: Punto de Acceso Nacional de la DGT (nap.dgt.es)**, dataset "Puntos de recarga eléctrica para vehículos":
  `https://nap.dgt.es/datex2/v3/miterd/EnergyInfrastructureTablePublication/electrolineras.xml`
  (la URL antigua `infocar.dgt.es/...` da **502**). XML DATEX II v3 de ~83 MB, **sin registro**, licencia **CC BY** (citar a la DGT), se actualiza **cada 24 h**. Leer con `iterparse` (no cargar entero). Trae nombre, dirección (en líneas "Dirección: ...", "Municipio: ...", "Provincia: ..."), coordenadas, operador, horario (texto), y por punto los conectores con tipo, modo, potencia (en **W**), voltaje e intensidad. **No trae precio ni estado libre/ocupado** (es una tabla estática); no se encontró una publicación dinámica en el NAP: volver a buscarla más adelante. El código postal pierde el 0 inicial (`7011` = 07011): rellenar a 5 cifras.
- **Complemento: Open Charge Map** (API gratuita con clave; datos colaborativos, sin estado en tiempo real). La clave va en el servidor, nunca en la app.
- **Complemento: OpenStreetMap** (Overpass, `amenity=charging_station`).
- Unir las fuentes eliminando duplicados por distancia (p. ej. < 30 m y mismo operador).
- **No** hacer scraping de Electromaps / Chargemap (sin API pública; condiciones de uso).

### Parkings
- **Ubicación:** OpenStreetMap. Para toda España hay **cientos de miles** de `amenity=parking` (incluidos aparcamientos privados y de supermercado): no usar Overpass para todo el país (límites de uso); pedir España **por zonas** (18: rejilla 4×4 de la península + Canarias + Ceuta/Melilla) y solo los que interesan (ver `importer/osm.py`). Geofabrik queda como alternativa si Overpass falla mucho. Complementar con datos abiertos de ayuntamientos grandes si los hay. Importar cada pocas semanas (cambian poco).
- **Escala:** con toda España, la app **solo pide lo que se ve en el mapa** (consulta por caja de coordenadas / cercanía + clustering), nunca la lista entera.
- **Precios y comentarios:** de la comunidad (ver "Aportaciones de la comunidad").

### Resultados de la prueba de fuentes (2026-10-27)
- **MITECO:** 11.424 gasolineras en 52 provincias, descarga de 12 MB en ~6 s. **5 con coordenadas `0,000000`** (Barcelona, Piélagos, Valdemoro...): no mostrarlas en el mapa (o geocodificar la dirección). 498 en Canarias, 22 en Ceuta y Melilla. Medianas: gasóleo A 1,935 € (península) / 1,709 € (Canarias); gasolina 95 1,765 € / 1,559 €. Combustibles con más datos: gasóleo A, gasolina 95 E5, gasóleo premium, gasolina 98 E5, AdBlue, gasóleo B (agrícola: no es para coches, ocultarlo por defecto), diésel renovable. El AdBlue tiene valores raros (máx. 3,4 €): no usarlo para "la más barata" sin filtrar.
- **DGT:** 12.080 ubicaciones, 35.697 puntos de carga, 42.876 conectores, 159 operadores, 51 provincias; todas las coordenadas dentro de España. Conectores: Tipo 2 (27.292), CCS Combo (10.462), CHAdeMO (3.742), Schuko (1.169). Potencia: 18.477 semirrápidos (7,5-22 kW), 10.914 rápidos, 7.866 lentos, 5.619 ultrarrápidos (≥100 kW). Actualizadas en 2025-2026 la mayoría (596 sin cambios desde 2023).
- **OpenStreetMap (Overpass):** 5.315 cargadores (menos de la mitad que la DGT: la DGT es la fuente principal; OSM solo para completar). **120.877 parkings** en total, 8.164 con nombre y 4.680 de pago. La consulta de subterráneos/varias plantas dio 502 (Overpass saturado; cada consulta de toda España tarda 50-100 s): confirma que para el importador hay que usar el extracto de Geofabrik. Criterio provisional para mostrar: con nombre **o** de pago **o** subterráneo/varias plantas.

## Estructura del proyecto (2026-10-27)

```
CLAUDE.md
tool/probe_sources.py           prueba de fuentes (data/probe_report.json)
tool/deploy_web.sh              publicar la web en Vercel (solo si el usuario lo pide)
tool/setup_fuel_import.ps1      lo ejecuta el usuario: secretos (Vault + CRON_SECRET), publica import-fuel, 003 y primera importación
importer/                       importadores en Python (solo biblioteca estándar)
  common.py                     utilidades + llamadas RPC con la service_role
  miteco.py                     gasolineras y precios (cada 30 min en GitHub Actions; TLS especial, ver "Fallos")
  dgt.py                        cargadores (DATEX II, iterparse)
  osm.py                        parkings (Overpass por zonas, reintentos con límite)
  tests/test_parsers.py         python -I -m unittest discover -s importer/tests
supabase/
  migrations/001_init.sql       tablas importadas, RLS solo lectura, map_points/fuel_near/chargers_near/data_freshness, import_*
  migrations/002_community.sql  profiles, parking_prices/reviews/photos, bucket parking-photos, reports, user_blocks, delete_my_account
  migrations/003_schedule.sql   pg_cron: import-fuel cada 30 min (secretos en Vault) + limpieza diaria
  functions/import-fuel/        Edge Function (Deno). parse.ts sin dependencias; tests: node --test supabase/functions/import-fuel/parse.test.ts
  tests/001_002_test.sql        prueba de permisos/RLS/importación (se deshace sola; todo debe salir OK)
app/                            Flutter (web, Android, iOS). Comandos dentro de app/
  lib/config.dart               nombre (PROVISIONAL), env.json, URLs, teselas, vista inicial
  lib/data/models.dart          modelos + claves de combustibles (fuelKeys)
  lib/data/repository.dart      ÚNICA puerta a Supabase (la UI no usa Supabase.instance)
  lib/providers.dart            Riverpod: capa, combustible, potencia, idioma (SharedPreferences), vista del mapa, datos
  lib/ui/map_page.dart          mapa, capas, filtros, marcadores, mi ubicación
  lib/ui/details.dart           fichas (gasolinera, cargador, parking) en hoja inferior
  lib/ui/nearby_sheet.dart      "Más baratas cerca" / "Cargadores cerca"
  lib/ui/account_page.dart      cuenta, nombre, bloqueados, idioma, legal, borrar cuenta
  lib/ui/format.dart, messages.dart, theme.dart
  lib/auth/login_page.dart      email + código (sin contraseña), Google, Apple
  lib/community/                precios/opiniones/fotos, diálogos, denunciar/bloquear, photo_processing (sin EXIF)
  lib/l10n/app_es.arb, app_en.arb   textos (es = plantilla). Tras cambiarlos: flutter gen-l10n
  web/index.html, vercel.json   CSP, cabeceras de seguridad
.github/workflows/              ci.yml (push), import_fuel.yml (cada 30 min), import_dgt.yml (diario), import_osm.yml (mensual), ios.yml (manual)
```

- Datos importados: `fuel_stations`, `fuel_prices` (último precio), `fuel_daily_stats` (resumen diario por provincia; **no** se guarda el histórico por gasolinera: no cabe en el plan gratis), `chargers` (conectores en jsonb), `parkings`, `import_runs`. Lo que deja de salir en la fuente se marca `active = false` (no se borra). Si una fuente devuelve < 5000 filas, la importación falla en vez de desactivar todo.
- Mapa: `map_points(kind, caja, zoom, ...)` agrupa en rejilla con zoom < 13 (count > 1 = grupo) y devuelve como mucho 3000 filas.
- Comandos de la app: `flutter gen-l10n`, `flutter analyze`, `flutter test` (17 tests). **Ver la web:** `flutter build web --release --no-web-resources-cdn --dart-define-from-file=env.json` + `python -m http.server 8765` en `app/build/web` (`flutter run -d chrome` sale en negro: la CSP de `web/index.html` bloquea el modo debug, ver "Fallos").
- Probar la web sin usar la pantalla: `python -m http.server 8765` en `app/build/web` + Playwright sin ventana (`NODE_PATH=~/.claude/skills/playwright-skill/node_modules`).

## Aportaciones de la comunidad (parkings)

- Para aportar hace falta **cuenta**; para ver, no.
- Validar en la app **y** en el servidor: importe razonable (p. ej. 0–50 €/h), longitud del comentario, valoración 1–5.
- Mostrar la **fecha** de cada precio aportado ("hace 3 meses") y, cuando haya varios, el más reciente o la mediana.
- **Moderación** (requisito de Google Play y App Store para contenido generado por usuarios): **denunciar** y **bloquear** usuarios, **condiciones de uso** y **página para borrar la cuenta**. Reutilizar el diseño de Deepslate (migración `012_block_report.sql`).
- Límite de aportaciones por usuario y día para evitar spam.

## Lecciones de Deepslate que aplican aquí

### Supabase
- La **anon key** es la única clave en la app (en `env.json`, fuera de git; en el CI desde GitHub Secrets). **La `service_role` nunca en la app**: solo en la Edge Function / GitHub Secrets.
- **Proyecto nuevo de Supabase**, separado de Deepslate (`xfcolledxhvlcyfwevaq`). El plan gratis permite 2 proyectos activos por organización; un proyecto gratis se **pausa tras 7 días sin actividad** (la importación periódica lo mantiene activo).
- En el modo automático de Claude Code, `apply_migration` / `execute_sql` con cambios **suelen rechazarse**: el usuario ejecuta la migración en el SQL Editor y Claude la verifica en solo lectura con el MCP. No intentar saltarse el bloqueo.
- Ejecutar la migración **antes** de publicar la versión de la app que usa columnas nuevas.
- Truco para probar RLS sin dejar datos: `set_config('role','authenticated',true)` + `set_config('request.jwt.claims', ...)` dentro de un `do $$ ... $$` que termina en `raise exception` con el resultado.
- `anon` sin permisos de escritura en ninguna tabla. Funciones con `search_path=''` y sin SQL dinámico.
- **Facturas:** plan gratis sin tarjeta (limita, no cobra). **No añadir nada que se llame a sí mismo o reintente sin límite** (la importación: como mucho una ejecución cada X minutos, sin reintentos en bucle).
- CAPTCHA (Cloudflare Turnstile): si se activa en Supabase, lo exige en **todas** las plataformas (`signUp`, `signInWithPassword`, `resend`, `recover`). Ver el diseño de Deepslate (`captcha.html` + `webview_flutter`) antes de activarlo. Las apps antiguas sin el reto dejan de poder entrar.

### Flutter / plataformas
- **Desarrollo en Windows nativo, sin WSL.** Shell: PowerShell (Git Bash para scripts).
- En la web no existe `dart:io`: nada de `Platform.isX` (usar `kIsWeb` y `defaultTargetPlatform`).
- **Android:** añadir el permiso **INTERNET** en `android/app/src/main/AndroidManifest.xml` (Flutter solo lo pone en debug). Comprobar con una build release.
- **Ubicación** (centrar el mapa en el usuario, ordenar por distancia): permisos en Android (`ACCESS_FINE_LOCATION`/`COARSE`) e iOS (`NSLocationWhenInUseUsageDescription` en `Info.plist`); en la web, `Permissions-Policy` debe permitir `geolocation=(self)` (en Deepslate estaba desactivada). La app debe funcionar si el usuario la deniega (mapa centrado en Tenerife).
- **No usar `flutter install`** (desinstala la app y borra los datos): `adb install -r`.
- Emulador: `Medium_Phone_API_36.0`. El usuario **no tiene móvil Android**. Abrir la app con `adb shell am start -n <id>/.MainActivity` (no `monkey`).
- **Preguntar SIEMPRE al usuario antes de cualquier prueba que use la pantalla** (emulador, clics, capturas que activan ventanas): puede estar usando el PC. Tests, analyze, builds y consultas no necesitan permiso. Captura antes de cada clic.
- Elegir el **identificador** (`applicationId` / bundle id) **antes de publicar** y no cambiarlo después.
- Riverpod 3: lo que deba funcionar en segundo plano no se escucha desde un widget. No usar `ref` tras cerrar una pantalla.
- Antes de `flutter build ... --release`, si salen iconos invisibles, borrar `build/flutter_assets` (recorte de fuentes de iconos reutilizado).
- Imágenes subidas por otros usuarios (si se permiten fotos de parkings): comprobar tamaño en cabecera antes de decodificar ("bombas" de imagen), solo JPEG/PNG, bucket privado con límite.

### Web (Vercel)
- Compilar con `--no-web-resources-cdn` y `--dart-define-from-file=env.json`. Publicar con un script (como `tool/deploy_web.sh` de Deepslate) que copia el build **fuera del repositorio** (Vercel bloquea desplegar desde dentro si el autor del commit no es el dueño) y pone un `BUILD_ID` para avisar de versión nueva a las pestañas abiertas.
- **CSP:** añadir los servidores de teselas del mapa (p. ej. `tile.openstreetmap.org` o el proveedor elegido) y Supabase. Si se añade un servicio externo nuevo, añadirlo a la CSP.
- Brave (navegador del usuario) con modo oscuro forzado duplicaba los placeholders: `<meta name="color-scheme" content="dark light">` y `::placeholder` transparente.
- Redirigir `*.vercel.app` al dominio propio; 404 propia, Open Graph, `robots.txt`, `sitemap.xml`, favicon. **Para esta app el SEO sí importa** (búsquedas tipo "gasolinera más barata Tenerife"): valorar páginas estáticas por municipio además de la app.
- No publicar en Vercel sin que el usuario lo pida.

### Mapas
- Las teselas de `tile.openstreetmap.org` **no se pueden usar en una app con muchos usuarios** (política de uso de OSM). Para producción, usar un proveedor con plan gratis (MapTiler, Stadia Maps, Protomaps autoalojado...) y **atribución "© OpenStreetMap contributors"** visible.
- Con cientos de marcadores, usar **clustering** (agrupar al alejar).

### iOS sin Mac
- **Inicio (gratis):** GitHub Actions `flutter build ios --no-codesign` → `.ipa` → Sideloadly (caduca a los 7 días).
- **Publicar:** Apple Developer (99 €/año) + Codemagic (firma) + TestFlight → App Store.
- Comprobar en cada paquete que soporta iOS; `SafeArea`; versión mínima en el `Podfile`; si algo falla solo en iOS, mirar los logs del CI.
- CI en Linux para analyze y tests (los minutos de macOS cuentan ×10); iOS solo manual. `permissions: contents: read` en los workflows.

### Google Play
- Ver `C:\Users\aleja\Documents\PROYECTO\PUBLICAR_GOOGLE_PLAY.md`. Resumen: AAB, API 36, clave de subida propia (no la de debug), política de privacidad, página de borrar cuenta, moderación de contenido de usuarios, **prueba cerrada con 12 testers durante 14 días** (cuenta personal), y verificar con un **móvil Android físico** (el usuario no tiene).
- Declarar en la ficha el uso de **ubicación**.
- Anuncios con cuenta personal = dirección completa pública: empezar **gratis y sin anuncios**.

### Legal
- Política de privacidad (ubicación: explicar que solo se usa en el dispositivo para ordenar por distancia, si es así), condiciones de uso (contenido de la comunidad), edad mínima **14** (consentimiento de datos en España), atribución de fuentes (MITECO, DGT, OpenStreetMap, Open Charge Map).
- Sin analítica con cookies → no hace falta aviso de cookies (Vercel Web Analytics no usa cookies).
- **No usar el correo personal del usuario** para nada de la app: usar un correo del dominio (Cloudflare Email Routing) y un SMTP transaccional (Resend) para los emails de Supabase.

## Seguridad

- Claves en **GitHub Secrets** / variables de entorno, **nunca en el código**.
- Solo la anon key en la app; `service_role` y claves de APIs externas (Open Charge Map, mapas con clave privada) solo en el servidor.
- Validar todo lo que escribe el usuario en la app **y** en el servidor (restricciones y triggers en Postgres).
- Consultas parametrizadas siempre (constructor de consultas / `rpc`), nunca SQL con texto del usuario.
- Repetir una auditoría de seguridad (skill `security-audit`) antes de publicar.

## Entorno del PC (heredado de Deepslate, comprobar con `flutter doctor`)

- Flutter 3.47, Android SDK 36, Android Studio, Visual Studio 2022 con C++, VS Code, Git, Node.js 24, `gh` con sesión en la cuenta `asosvi`, Vercel CLI con sesión (`npx vercel`).
- Modo de desarrollador de Windows activado.
- Skills de diseño y Playwright en `~/.claude/skills` (sirven de guía; casi todas son para webs/React).

## Próximos pasos

1. [ ] Responder las preguntas abiertas (abajo).
2. [x] Prueba de las fuentes (2026-10-27): `python -I tool/probe_sources.py` (opciones `--offline` y `--no-osm`). Pendiente: Open Charge Map (necesita clave) y datos abiertos municipales de parkings.
3. [x] Migraciones escritas (001, 002, 003) + prueba `supabase/tests/001_002_test.sql`. **No ejecutadas** (falta el proyecto de Supabase): las ejecuta el usuario y Claude las verifica.
4. [x] Importadores: Edge Function `import-fuel` (parser probado con los datos reales: 11.419 filas, 5 descartadas), `importer/dgt.py` (en seco: 12.080 cargadores), `importer/osm.py` (en seco solo Canarias: 473 parkings, 55 s). **No probados contra Supabase.**
5. [x] App Flutter (2026-10-27): mapa con capas, filtros, grupos, fichas, lista de cercanos, login (email + código, Google, Apple), aportaciones con fotos, denunciar/bloquear, borrar cuenta, español/inglés. `flutter analyze` limpio y 16 tests. Web compilada y probada sin ventana (Playwright): arranca sin errores y avisa de que falta el servidor. **No probado:** con datos reales, Android, iOS, login.
6. [x] CI y workflows programados escritos (no subidos: el repo aún no está en GitHub; sin commits todavía).
7. [x] Proyecto Supabase **"gas tracker"** (ref `uzxxnomzoosfarrdiwyb`, región eu-north-1, creado el 2026-10-29) ✔, 001-004 ejecutadas, prueba OK ✔. Repo público `asosvi/tinerfuel` con secretos `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` (clave `sb_secret_`) ✔. MITECO importado desde GitHub Actions el 2026-10-30: 11.419 gasolineras, 42.544 precios; la app lo lee con la clave pública ✔. DGT: 12.084 cargadores ✔. OSM: 9.517 parkings ✔ (4 zonas necesitaron reintento). Web probada por el usuario con datos reales ✔ (2026-10-30). Sin probar aún: login, aportaciones, Android, iOS. **Cuidado:** la cuenta tiene también el proyecto de Deepslate (`xfcolledxhvlcyfwevaq`): poner siempre `--project-ref uzxxnomzoosfarrdiwyb`.
8. [ ] Google y Apple como proveedores en Supabase (usuario; Apple necesita Apple Developer).
9. [ ] Proveedor de teselas del mapa para producción.
10. [ ] Páginas legales (privacidad, condiciones, borrar cuenta) y dominio (cuando haya nombre).
11. [ ] Icono/logo y nombre definitivo; cambiar `com.example.tinerfuel` por el identificador definitivo.
12. [ ] CAPTCHA (Turnstile) antes de publicar, como en Deepslate.
13. [ ] Publicación en Google Play y App Store (solo con toda España funcionando).

## Preguntas abiertas (preguntar al usuario)

- Nombre definitivo de la app, identificador (`com.xxx.app`) y dominio (de momento, placeholder **Tinerfuel**). Candidatos sugeridos: Parada, Arcén, Desvío, Llenito, Reposta, Tanko, Rutea.
- Proveedor de teselas del mapa para producción (MapTiler, Stadia, Protomaps...).

## Decisiones tomadas

- **2026-10-30: correo con Resend, como Deepslate** (pedido por el usuario: "mira como esta hecho en deepslate... tengo resend"). SMTP en Supabase: `smtp.resend.com`, puerto 465, usuario `resend`, contraseña = una API key de Resend **nueva y solo para esta app** (solo en Supabase, nunca en el chat ni en el proyecto). **Provisional:** remitente `Tinerfuel <tinerfuel@deepslatenotes.com>` (el único dominio verificado en Resend); cambiarlo al dominio propio cuando haya nombre. No usar el correo personal del usuario.
- **2026-10-30: repositorio de GitHub público** (pedido por el usuario): minutos de Actions gratis e ilimitados, necesarios para importar el MITECO cada 30 min desde GitHub Actions (ver "Fallos conocidos").
- **2026-10-27: importación (decidido por Claude; el usuario pidió "haz todo lo que puedas"):** MITECO con **Edge Function + pg_cron cada 30 min** (12 MB, cabe de sobra; no gasta minutos de GitHub Actions, que se comparten con Deepslate). DGT (83 MB, diario) y OSM (lento, mensual) con **Python en GitHub Actions** (una Edge Function tiene poca memoria y tiempo para 83 MB). Todos llaman a funciones `import_*` que solo puede ejecutar la `service_role`.
- **2026-10-27: parkings de OSM por Overpass en 18 zonas** (en vez del extracto de Geofabrik): con el filtro (con nombre / de pago / subterráneo o varias plantas, sin privados) la respuesta es pequeña y no hace falta procesar 1 GB. Probado con Canarias.
- **2026-10-27: login por email sin contraseña** (código de un solo uso: `signInWithOtp` + `verifyOTP(type: email)`), además de Google y Apple por redirección a `tinerfuel://login-callback`. Si la App Store pide el botón nativo de Apple en iOS, cambiar a `sign_in_with_apple` + `signInWithIdToken`. La plantilla "Magic Link" de Supabase debe llevar `{{ .Token }}`.
- **2026-10-27: identificador provisional `com.example.tinerfuel`** a propósito: Google Play rechaza `com.example`, así que es imposible publicar sin cambiarlo antes.
- **2026-10-27: fotos de parkings en bucket público** (se ven sin cuenta), máx. 2 MB, JPEG/PNG, subida solo en la carpeta propia y sin política de listar. La app las reduce a 1600 px y quita el EXIF.

- **2026-10-27: plataformas:** **web, Android e iOS** (pedido por el usuario).
- **2026-10-27: ámbito:** **toda España** (pedido por el usuario; antes solo Tenerife). Nombre de la app neutral, sin referencias a una isla o región.
- **2026-10-27: lanzamiento:** **no se publica hasta que funcione en toda España** (nada de lanzar por zonas).
- **2026-10-27: idiomas:** **castellano e inglés** (los textos de la interfaz en archivos de traducción desde el principio, p. ej. `flutter_localizations` + ARB; nada de textos escritos directamente en los widgets). Catalán, euskera y gallego: quizá en el futuro.
- **2026-10-27: nombre:** aún sin decidir. **Placeholder: "Tinerfuel"** (proyecto Flutter `tinerfuel`). **No crear el identificador definitivo de las tiendas ni comprar dominio con este nombre**: cambiarlo antes de publicar es fácil; después, no. Tener el nombre visible en un solo sitio (constante + ARB) para cambiarlo de una vez.
- **2026-10-27: parkings:** solo la **ubicación** de fuentes abiertas; **precios y comentarios los aporta la comunidad** (pedido por el usuario).
- **2026-10-27: fotos en las aportaciones de parkings:** **sí** (pedido por el usuario). Bucket privado de Supabase Storage con límite de tamaño, solo JPEG/PNG, compresión en el dispositivo (como Deepslate: lado mayor 1600 px, JPEG 80), comprobación de "bombas" de imagen y **quitar EXIF** (la ubicación GPS de la foto no debe publicarse). Las fotos se pueden denunciar como el resto del contenido.
- **2026-10-27: login:** **las tres opciones**: email + código, **Google** y **Apple** (pedido por el usuario). Requisitos: Google → cliente OAuth en Google Cloud Console (Android, iOS y web); Apple → **cuenta de Apple Developer (99 €/año)** con Services ID y clave de "Sign in with Apple" (también para usarlo en la web y Android); App Store exige "Iniciar sesión con Apple" si hay login con Google. Ver la app sin cuenta sigue siendo posible.
- **2026-10-27: stack:** Flutter + Supabase + Vercel, el mismo que Deepslate (propuesto por Claude: un solo código para las 3 plataformas, ya instalado y probado en este PC). Pendiente de confirmar por el usuario.

## Fallos conocidos y lecciones

### 2026-10-30: puesta en marcha de Supabase (Windows)
- **`npx` en la terminal de VS Code da "running scripts is disabled"** (política de ejecución de PowerShell). Solución: usar `npx.cmd` (sin cambiar la política). Scripts `.ps1`: `powershell -ExecutionPolicy Bypass -File ...`.
- **El modo automático bloquea `supabase db query -f <migración>`** (cambia la base de datos). Solución: el usuario lo ejecuta en su terminal con `npx.cmd supabase db query --linked --project-ref uzxxnomzoosfarrdiwyb -f <archivo>` (sin copiar y pegar en el panel) y Claude verifica en solo lectura con el mismo comando. `--project-ref` exige `--linked`.
- Ejecutar una migración dos veces da `relation ... already exists` y no cambia nada (no son idempotentes, a propósito).
- 001 y 002 ejecutadas; la prueba `001_002_test.sql` salió con las 25 líneas OK.
- **La API del MITECO corta la conexión desde la Edge Function de Supabase** (`Connection reset by peer (os error 104)`) **y desde Python 3.14 en el PC** (`WinError 10054`), pero curl, Node y `openssl s_client` funcionan. **Causa:** el servidor del MITECO solo acepta **TLS 1.2 con `AES256-GCM-SHA384`** (intercambio RSA, sin ECDHE); Python 3.10+ no ofrece ese cifrado por defecto y rustls (Deno, Edge Functions) no lo admite nunca. No es un bloqueo de IPs (aunque en datos.gob.es otros lo achacan a eso). El 2026-10-27 funcionaba: el ministerio cambió la configuración después. **Solución:** `importer/miteco.py` en GitHub Actions cada 30 min (`import_fuel.yml`) con un contexto TLS que añade ese cifrado solo para el MITECO (sigue verificando el certificado). La Edge Function `import-fuel` queda publicada pero sin uso; la migración `004_fuel_from_github.sql` quita su tarea de pg_cron. Si el MITECO vuelve a cambiar el TLS, probar con `openssl s_client -connect sedeaplicaciones.minetur.gob.es:443` qué cifrado da.
- **Web: `flutter run -d chrome` se queda en negro.** La CSP de `web/index.html` (`script-src 'self' 'wasm-unsafe-eval'`) bloquea lo que usa el modo debug: CanvasKit desde `www.gstatic.com` y un script inline. No se relaja la CSP: para ver la web, build release con `--no-web-resources-cdn` + `http.server` (ver "Estructura"). Diagnóstico sin pantalla: Playwright escuchando `console`/`pageerror`.
- **Web: el mapa salía vacío en pantallas grandes** (`map_points` → 400 "caja demasiado grande"): con zoom 4,9 y 1280 px la caja visible mide ~65° de ancho y la función acepta 40°. Solución: la app recorta la caja a la zona con datos (`clampToSpain` en `repository.dart`, límites en `config.dart`). Resuelto.
- **Supabase no deja editar las plantillas de email sin SMTP propio** (plan gratis, 2026). La plantilla por defecto manda un **enlace**, no el código, y el email por defecto solo llega a miembros del proyecto. Primero se probó que la app aceptara el enlace; el usuario prefirió hacerlo **como Deepslate**: SMTP de **Resend** y plantillas con `{{ .Token }}` (copias en `supabase/email/`: `confirm_signup.html` para "Confirm signup" y `magic_link.html` para "Magic Link"; los usuarios nuevos reciben la primera). Solo código, sin enlace.
- **`.gitignore` con `data/` ignoraba también `app/lib/data/`** (modelos y repositorio de la app). Cambiado a `/data/`. Lección: antes del primer commit, revisar `git status --ignored`.

### 2026-10-27: prueba de fuentes
- **La URL de la DGT que sale en buscadores y noticias (`infocar.dgt.es/datex2/...`) da 502.** La buena es la de la ficha del dataset en nap.dgt.es (`nap.dgt.es/datex2/...`). Si vuelve a fallar, mirar la ficha del dataset.
- **Overpass (OSM) devuelve 502 con consultas de toda España** cuando está cargado. Resuelto para la prueba: se apunta el error y se sigue. Para el importador: extracto de Geofabrik, no Overpass.
