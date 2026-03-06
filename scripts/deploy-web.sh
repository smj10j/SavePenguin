#!/usr/bin/env bash
# Deploys the static website + API worker to Cloudflare Pages.
# Requires: npm install -g wrangler && wrangler login
#
# The wrangler.toml at the project root configures the Pages project name,
# build output dir (web/dist), and D1 database binding.
#
# Run from the project root.

set -e

if [ ! -f "web/dist/index.html" ]; then
  echo "Error: web/dist/index.html not found. Run scripts/convert-images.sh first."
  exit 1
fi

echo "Deploying to Cloudflare Pages (project: savepenguin) ..."
wrangler pages deploy web/dist --project-name savepenguin --branch main --commit-dirty=true

echo ""
echo "Deployed! Live at: https://savepenguin.pages.dev"
echo "  Website: https://savepenguin.pages.dev/"
echo "  API:     https://savepenguin.pages.dev/server"
