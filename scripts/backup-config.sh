#!/usr/bin/env bash
# Back up the app configuration (databases, settings, API keys) - NOT the media.
# Stops the stack briefly so SQLite databases are consistent, then restarts it.
#
# Usage:  sudo ./scripts/backup-config.sh [destination-dir]   (default: ./backups)
# Keeps the newest 14 archives. Schedule it with cron/systemd, e.g. weekly.
set -euo pipefail

cd "$(dirname "$0")/.."

DEST="${1:-./backups}"
KEEP=14
getenv() { grep -E "^$1=" .env 2>/dev/null | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//'; }
CONFIG_ROOT="$(getenv CONFIG_ROOT)"; CONFIG_ROOT="${CONFIG_ROOT:-./config}"

mkdir -p "$DEST"
STAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$DEST/mediastack-config-$STAMP.tar.gz"

echo "Stopping stack..."
docker compose stop

# Plex's Cache and Media (thumbnails) folders are large and regenerable - skip them.
echo "Archiving $CONFIG_ROOT -> $ARCHIVE"
tar -czf "$ARCHIVE" \
  --exclude='*/Plex Media Server/Cache' \
  --exclude='*/Plex Media Server/Media' \
  --exclude='*/Plex Media Server/Crash Reports' \
  --exclude='*/logs' --exclude='*/log_archive' \
  -C "$(dirname "$CONFIG_ROOT")" "$(basename "$CONFIG_ROOT")" \
  -C "$PWD" .env docker-compose.yml

echo "Starting stack..."
docker compose up -d

chmod 600 "$ARCHIVE"   # contains API keys and the .env
ls -1t "$DEST"/mediastack-config-*.tar.gz | tail -n +$((KEEP + 1)) | xargs -r rm --
echo "Backup complete: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"
