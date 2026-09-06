#!/usr/bin/env bash
set -euo pipefail

OUT="images/splash/medidata_branding.png"
FONT_DIR="${HOME}/.local/share/fonts"
FONT_PATH="${FONT_DIR}/ComicRelief-Bold.ttf"
FONT_URL="https://github.com/gen2brain/crtaci/raw/master/frontend/android/Crtaci/src/main/assets/fonts/ComicRelief-Bold.ttf"

mkdir -p "$(dirname "$OUT")" "$FONT_DIR"

if [[ ! -f "$FONT_PATH" ]]; then
  echo "Downloading Comic Relief Bold..."
  curl -L --fail --retry 3 "$FONT_URL" -o "$FONT_PATH"
fi

if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
fi

if ! command -v convert >/dev/null 2>&1 && ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required to generate splash branding." >&2
  exit 1
fi

CONVERT_BIN="$(command -v magick || command -v convert)"

"$CONVERT_BIN" \
  -size 800x320 xc:none \
  -font "$FONT_PATH" \
  -pointsize 68 \
  -fill "#C9A227" \
  -gravity center \
  -kerning 0.5 \
  -annotate +0+0 "MediData App" \
  "$OUT"

echo "Generated $OUT (800x320, transparent, Comic Relief Bold, #C9A227)."
