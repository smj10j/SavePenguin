#!/usr/bin/env bash
# Converts website PNG source images to WebP and copies other assets into web/dist/.
# Run this when source images in web/subdomains/www/images/ have changed.
# Requires: brew install webp
#
# NOTE: Does NOT wipe web/dist/ — only updates images and static assets.
# The _worker.js and other dist files are preserved.

set -e

SRC="$(dirname "$0")/../web/subdomains/www"
DIST="$(dirname "$0")/../web/dist"

echo "Syncing static assets to $DIST ..."

mkdir -p "$DIST/images" "$DIST/css" "$DIST/privacy_files"

# Copy non-image assets
cp "$SRC/css/style.css"   "$DIST/css/"
cp "$SRC/privacy.htm"     "$DIST/"
cp -r "$SRC/privacy_files/." "$DIST/privacy_files/"
cp "$SRC/images/favicon.ico" "$DIST/images/"

# Convert PNGs to WebP
for f in "$SRC/images/"*.png; do
  name=$(basename "$f" .png)
  echo "  Converting $name.png -> $name.webp"
  cwebp -q 85 "$f" -o "$DIST/images/$name.webp"
done

echo "Done. Run scripts/deploy-web.sh to publish."
