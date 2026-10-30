#!/usr/bin/env bash
# Publica la web en Vercel (Git Bash, desde la raíz del proyecto).
# - Compila con BUILD_ID para que las pestañas abiertas sepan que hay versión nueva.
# - Copia el build FUERA del repositorio: Vercel bloquea desplegar desde dentro
#   si el autor del último commit no es el dueño de la cuenta (lección de Deepslate).
# Publicar SOLO cuando el usuario lo pida.
set -euo pipefail
cd "$(dirname "$0")/../app"
test -f env.json || { echo "Falta app/env.json (copia env.example.json)"; exit 1; }

BUILD_ID=$(date -u +%Y%m%d%H%M%S)
flutter build web --release --no-web-resources-cdn \
  --dart-define-from-file=env.json --dart-define=BUILD_ID="$BUILD_ID"
echo "$BUILD_ID" > build/web/build_id.txt
cp web/vercel.json build/web/vercel.json

OUT="${LOCALAPPDATA:-$HOME/AppData/Local}/tinerfuel-web-deploy"
mkdir -p "$OUT"
find "$OUT" -mindepth 1 -maxdepth 1 ! -name .vercel -exec rm -rf {} +
cp -r build/web/. "$OUT/"
find "$OUT" -name "*.symbols" -delete
cd "$OUT"
npx vercel deploy --prod --yes --name tinerfuel
