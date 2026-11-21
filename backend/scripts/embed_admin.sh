#!/bin/sh
# Rebuild the researcher console into backend/admin_dist for the API image.
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "$ROOT/admin"
VITE_BASE="${VITE_BASE:-/console/}" npm run build
rm -rf "$ROOT/backend/admin_dist"
cp -a dist "$ROOT/backend/admin_dist"
echo "Wrote $ROOT/backend/admin_dist"
