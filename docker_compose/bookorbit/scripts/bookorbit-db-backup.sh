#!/usr/bin/env bash
# Back up the BookOrbit Postgres database.
#
# The database holds everything that cannot be regenerated from the book files:
# metadata edits, covers, reading progress, annotations, collections, user
# accounts. A lost SD card means losing all of it, and nothing else restores it.
#
# Plain SQL, not a pg_dump of the whole cluster -- one database, plus a checksum
# so a truncated or corrupt file is detectable.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/home/rsukumar/backups}"
KEEP_DAYS="${KEEP_DAYS:-14}"
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$BACKUP_DIR/bookorbit-$STAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

# --clean --if-exists makes the dump restorable over an existing database.
# No --create: we want the objects, not a second cluster on restore.
docker exec bookorbit-db pg_dump \
  --username=bookorbit \
  --dbname=bookorbit \
  --clean --if-exists --no-owner --no-privileges \
| gzip -9 > "$OUT"

# An empty or truncated dump is worse than none -- it looks like a valid backup
# right up until you need it. Verify before keeping it.
SIZE=$(stat -c %s "$OUT")
if [ "$SIZE" -lt 1024 ]; then
  echo "ERROR: dump is only $SIZE bytes; treating as failed" >&2
  rm -f "$OUT"
  exit 1
fi

gzip -t "$OUT" || { echo "ERROR: gzip integrity check failed" >&2; rm -f "$OUT"; exit 1; }

# Confirm the dump actually contains the schema, not just an empty database.
# Use grep -c rather than grep -q: -q exits on the first match, which SIGPIPEs
# zcat and makes the whole pipeline report failure under `set -e`.
TABLE_COUNT=$(zcat "$OUT" | grep -cE "^CREATE TABLE" || true)
if [ "$TABLE_COUNT" -lt 1 ]; then
  echo "ERROR: dump contains no CREATE TABLE statements" >&2
  rm -f "$OUT"
  exit 1
fi

sha256sum "$OUT" > "$OUT.sha256"

echo "$(date -Is)  bookorbit backup OK: $OUT ($SIZE bytes, $TABLE_COUNT tables)"

# Retention: prune by mtime so we never accumulate unbounded backups on a
# 29 GB card. KEEP_DAYS=0 disables pruning.
if [ "$KEEP_DAYS" -gt 0 ]; then
  find "$BACKUP_DIR" -name 'bookorbit-*.sql.gz*' -type f -mtime "+$KEEP_DAYS" -delete
fi