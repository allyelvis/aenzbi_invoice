#!/usr/bin/env bash
set -e
CACHE_DIR="$HOME/.pub-cache/hosted/pub.dev"
mkdir -p "$CACHE_DIR"

PKGS=(
  "vector_math-2.1.4" "material_color_utilities-0.5.0" "characters-1.3.0"
  "meta-1.10.0" "collection-1.18.0" "async-2.11.0" "web-0.3.0"
  "cupertino_icons-1.0.8" "boolean_selector-2.1.1" "clock-1.1.1"
  "fake_async-1.3.1" "flutter_lints-2.0.3" "lints-2.1.1"
  "matcher-0.12.16" "path-1.8.3" "source_span-1.10.0"
  "stack_trace-1.11.1" "stream_channel-2.1.2" "string_scanner-1.2.0"
  "term_glyph-1.2.1" "test_api-0.6.1"
)

MISSING=0
for PKG in "${PKGS[@]}"; do
  [ -d "$CACHE_DIR/$PKG" ] || MISSING=1
done

if [ "$MISSING" = "1" ]; then
  echo "Restoring pub cache..."
  for PKG in "${PKGS[@]}"; do
    NAME="${PKG%-*}"; VER="${PKG##*-}"; DEST="$CACHE_DIR/$PKG"
    [ -d "$DEST" ] && continue
    mkdir -p "$DEST"
    curl -sL "https://pub.dev/packages/$NAME/versions/$VER.tar.gz" \
      -o /tmp/pkg.tar.gz --max-time 30 \
      && tar -xzf /tmp/pkg.tar.gz -C "$DEST" \
      && echo "  OK $PKG" || echo "  FAIL $PKG"
  done
  echo "Running flutter pub get..."
  flutter pub get --offline
fi

echo "Building Flutter web..."
flutter build web

echo "Serving on port 5000..."
npx --yes serve build/web -p 5000 -s
