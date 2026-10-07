#!/usr/bin/env bash
# Write an rclone authorize JSON blob into a remote's token, without the token
# ever appearing in shell history or the process list.
#
# Usage: set-rclone-token.sh <remote> < json_blob
set -euo pipefail

REMOTE="${1:?usage: set-rclone-token.sh <remote> < json_blob}"
BLOB=$(cat)

if [ -z "$BLOB" ]; then
  echo "ERROR: no JSON blob on stdin" >&2
  exit 1
fi

# Validate it looks like rclone's authorize output before touching the config.
case "$BLOB" in
  *'"refresh_token"'*) ;;
  *) echo "ERROR: blob does not look like an rclone authorize payload" >&2; exit 1 ;;
esac

rclone config update "$REMOTE" token "$BLOB"
echo "Token written to [$REMOTE]"