#!/usr/bin/env bash
# Push books added on the Pi up to Google Drive.
#
# Manual and deliberate. The timer only pulls (bookorbit-sync.sh), so a book
# added here is never touched by a scheduled run until you push it yourself.
#
#   ~/docker_compose/bookorbit/scripts/bookorbit-push.sh            # real run
#   ~/docker_compose/bookorbit/scripts/bookorbit-push.sh --dry-run  # preview only
set -euo pipefail

REMOTE_PATH="GDrive:Backups/BookOrbit/Calibre Library"
LOCAL_PATH="/home/rsukumar/books"

[ -d "$LOCAL_PATH" ] || { echo "ERROR: $LOCAL_PATH missing" >&2; exit 1; }

echo "Pushing $LOCAL_PATH -> $REMOTE_PATH"
exec rclone copy "$LOCAL_PATH" "$REMOTE_PATH" \
  --fast-list \
  --transfers 4 \
  --checkers 8 \
  --exclude 'metadata.db*' \
  --drive-use-trash \
  --stats 30s \
  "$@"