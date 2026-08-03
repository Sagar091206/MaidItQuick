#!/usr/bin/env bash
# Syncs the admin SPA (frontend/) into the jar's static resources so the
# merged server serves the admin UI from a single artifact. Run after editing
# the frontend and before `mvn package`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
rsync -a --exclude 'Dockerfile' --exclude 'package.json' --exclude 'server.js' \
  "$ROOT/frontend/" "$ROOT/server/src/main/resources/static/"
echo "Admin frontend synced into server/src/main/resources/static"
