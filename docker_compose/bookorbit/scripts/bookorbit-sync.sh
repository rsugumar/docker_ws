#!/usr/bin/env bash
# Sync the Google Drive Calibre library into the local BookOrbit library.
#
# Pull-only (Drive -> local). This runs on a timer; pushing books added on the
# Pi is a separate, manual step so a timer can never race an unpushed book.
#
# rclone copy never propagates deletions, so a mistake here can duplicate files
# but cannot destroy them. Drive remains the archive.
set -euo pipefail

# Single source of truth for the Drive path, shared with the push script.
REMOTE_PATH="GDrive:Backups/BookOrbit/Calibre Library"
LOCAL_PATH="/home/rsukumar/books"

# Safety: never write outside the intended local library.
[ -d "$LOCAL_PATH" ] || { echo "ERROR: $LOCAL_PATH missing" >&2; exit 1; }

# --fast-list trades memory for one listing pass instead of per-directory calls.
# --exclude metadata.db* keeps Calibre's SQLite DB out of the two-machine sync:
# BookOrbit ignores it, and it is the most conflict-prone file to share.
exec rclone copy "$REMOTE_PATH" "$LOCAL_PATH" \
  --fast-list \
  --transfers 4 \
  --checkers 8 \
  --exclude 'metadata.db*' \
  --drive-use-trash \
  --stats 30s \
  "$@"