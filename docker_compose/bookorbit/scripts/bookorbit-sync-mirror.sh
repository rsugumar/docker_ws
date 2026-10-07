#!/usr/bin/env bash
# Mirror the Google Drive library down with rclone sync, behind a confirmation gate.
#
# Unlike bookorbit-sync.sh (which uses `copy` and never deletes), this uses `sync`
# so deletions on Drive DO propagate. That makes it destructive, hence:
#
#   1. Always dry-run first, and print what would change
#   2. Refuse to proceed if the deletion count exceeds SAFETY_MAX_DELETES
#   3. Require an interactive confirmation
#   4. Move deletions to a quarantine directory instead of destroying them
#
# Usage:
#   ./bookorbit-sync-mirror.sh            # dry-run, then prompt
#   ./bookorbit-sync-mirror.sh --yes      # skip the prompt (for cron; still dry-runs)
#   ./bookorbit-sync-mirror.sh --no-quarantine   # delete instead of quarantining
#
# The ONLY way this can lose data is if the quarantine dir is also deleted.
# ---------------------------------------------------------------------------
set -euo pipefail

REMOTE_PATH="GDrive:Backups/BookOrbit/Calibre Library"
LOCAL_PATH="/home/rsukumar/books"
QUARANTINE="/home/rsukumar/books-quarantine"

# Refuse to proceed if more than this many files would be deleted in one run.
# A large number almost always means a wrong path or an incomplete upload,
# not a deliberate cleanup. Raise deliberately, never reflexively.
SAFETY_MAX_DELETES="${SAFETY_MAX_DELETES:-25}"

# Same excludes as the pull script: Calibre's SQLite DB is per-machine and
# conflict-prone, so it is never mirrored.
COMMON_FLAGS=(
  --fast-list
  --transfers 4
  --checkers 8
  --exclude 'metadata.db*'
)

ASSUME_YES=0
USE_QUARANTINE=1
for arg in "$@"; do
  case "$arg" in
    --yes|-y)             ASSUME_YES=1 ;;
    --no-quarantine)      USE_QUARANTINE=0 ;;
    --help|-h)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2 ;;
  esac
done

[ -d "$LOCAL_PATH" ] || { echo "ERROR: $LOCAL_PATH missing" >&2; exit 1; }

echo "=== Source : $REMOTE_PATH"
echo "=== Target : $LOCAL_PATH"
echo "=== Deletes allowed up to: $SAFETY_MAX_DELETES"
[ "$USE_QUARANTINE" -eq 1 ] && echo "=== Deletions will be MOVED to: $QUARANTINE"
echo

# --- Step 1: dry-run, always ---
#
# The dry-run deliberately OMITS --backup-dir. rclone reports zero deletions when
# --backup-dir is combined with --dry-run, which would silently disable the safety
# gate below. Verified: 30 pending deletions report as 0 with the flag present,
# and as 30 without it. So quarantine is applied only to the real run.
echo "=== Dry run ==="
DRY_OUT=$(mktemp)
trap 'rm -f "$DRY_OUT"' EXIT

rclone sync "$REMOTE_PATH" "$LOCAL_PATH" \
  "${COMMON_FLAGS[@]}" \
  --dry-run > "$DRY_OUT" 2>&1 || {
    echo "ERROR: dry-run failed. Nothing was changed." >&2
    tail -20 "$DRY_OUT" >&2
    exit 1
  }

DEL_COUNT=$(grep -c "Skipped delete as --dry-run" "$DRY_OUT" || true)
NEW_COUNT=$(grep -cE "Skipped copy as --dry-run" "$DRY_OUT" || true)
UPD_COUNT=$(grep -cE "Skipped.*as --dry-run \(size" "$DRY_OUT" || true)

echo
echo "Would transfer/update : $NEW_COUNT"
echo "Would delete         : $DEL_COUNT"
echo

if [ "$DEL_COUNT" -eq 0 ]; then
  echo "No deletions proposed - nothing will be removed."
else
  echo "Files that would be deleted:"
  grep "Skipped delete as --dry-run" "$DRY_OUT" | sed 's/^/  /' | head -50
  [ "$DEL_COUNT" -gt 50 ] && echo "  ... and $((DEL_COUNT - 50)) more"
  echo
fi

# --- Step 2: safety gate ---
if [ "$DEL_COUNT" -gt "$SAFETY_MAX_DELETES" ]; then
  cat >&2 <<EOF

REFUSING TO PROCEED.

$DEL_COUNT deletions proposed, above the limit of $SAFETY_MAX_DELETES.

This usually means a wrong source path, not a real cleanup. Check that:
  - "$REMOTE_PATH" is the correct Drive folder
  - the source has not been partially uploaded or interrupted

Re-run with an explicit override only if you are certain:
  SAFETY_MAX_DELETES=$DEL_COUNT $0
EOF
  exit 1
fi

# --- Step 3: confirmation ---
if [ "$ASSUME_YES" -eq 0 ]; then
  if [ ! -t 0 ]; then
    echo "Not a terminal and --yes not given; stopping after dry-run." >&2
    exit 1
  fi
  echo "Proceed with the real sync? [y/N] "
  read -r reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted. Nothing was changed."; exit 0 ;;
  esac
fi

# --- Step 4: real run ---
echo
echo "=== Applying ==="
rclone sync "$REMOTE_PATH" "$LOCAL_PATH" \
  "${COMMON_FLAGS[@]}" \
  ${USE_QUARANTINE:+--backup-dir "$QUARANTINE"} \
  --stats 30s

echo
echo "Done."
if [ "$USE_QUARANTINE" -eq 1 ] && [ "$DEL_COUNT" -gt 0 ]; then
  echo "Deleted files were moved to: $QUARANTINE"
  echo "Review and delete that directory once you are satisfied."
fi