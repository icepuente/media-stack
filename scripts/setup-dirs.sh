#!/usr/bin/env bash
# Create the data + config folder tree with the right ownership.
# Reads PUID, PGID, DATA_ROOT, CONFIG_ROOT, TRANSCODE_DIR from ../.env
#
# Usage:  sudo ./scripts/setup-dirs.sh            (sudo needed if DATA_ROOT is outside your home)
#         sudo ./scripts/setup-dirs.sh --dry-run  (print what would be done)
set -euo pipefail

cd "$(dirname "$0")/.."

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

if [[ ! -f .env ]]; then
  echo "No .env found. Run: cp .env.example .env  (then edit it)" >&2
  exit 1
fi

# Read only the variables we need; do not execute the file.
getenv() { grep -E "^$1=" .env | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//'; }
PUID="$(getenv PUID)";               PUID="${PUID:-1000}"
PGID="$(getenv PGID)";               PGID="${PGID:-1000}"
DATA_ROOT="$(getenv DATA_ROOT)";     DATA_ROOT="${DATA_ROOT:-/data}"
CONFIG_ROOT="$(getenv CONFIG_ROOT)"; CONFIG_ROOT="${CONFIG_ROOT:-./config}"
TRANSCODE_DIR="$(getenv TRANSCODE_DIR)"; TRANSCODE_DIR="${TRANSCODE_DIR:-./transcode}"

run() { if (( DRY_RUN )); then echo "+ $*"; else "$@"; fi; }

DATA_DIRS=(
  "$DATA_ROOT/torrents/movies"
  "$DATA_ROOT/torrents/tv"
  "$DATA_ROOT/torrents/books"
  "$DATA_ROOT/torrents/incomplete"
  "$DATA_ROOT/media/movies"
  "$DATA_ROOT/media/tv"
  "$DATA_ROOT/media/books"
  "$DATA_ROOT/books-ingest"
)
CONFIG_DIRS=(plex seerr radarr sonarr prowlarr transmission cwa shelfmark gluetun)

echo "Owner:       $PUID:$PGID"
echo "Data root:   $DATA_ROOT"
echo "Config root: $CONFIG_ROOT"
echo "Transcode:   $TRANSCODE_DIR"
echo

for d in "${DATA_DIRS[@]}"; do run mkdir -p "$d"; done
for d in "${CONFIG_DIRS[@]}"; do run mkdir -p "$CONFIG_ROOT/$d"; done
run mkdir -p "$TRANSCODE_DIR"

# Ownership: only the folders we manage. Existing media is not touched recursively
# unless it is empty, to avoid a very long chown over a large library.
run chown "$PUID:$PGID" "$DATA_ROOT" "$DATA_ROOT/torrents" "$DATA_ROOT/media" "${DATA_DIRS[@]}"
run chown -R "$PUID:$PGID" "$CONFIG_ROOT" "$TRANSCODE_DIR"
# 775/664-style permissions so the group can manage files too
run chmod 2775 "$DATA_ROOT" "$DATA_ROOT/torrents" "$DATA_ROOT/media" "${DATA_DIRS[@]}"

echo
echo "Done. Layout:"
if command -v tree >/dev/null 2>&1; then
  tree -d -L 2 "$DATA_ROOT" || true
else
  find "$DATA_ROOT" -maxdepth 2 -type d | sort
fi
