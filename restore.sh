#!/bin/sh
# Restore a database backup into the running db service.
# Usage: ./restore.sh [backups/ianseo-YYYY-MM-DD_HHMMSS.sql.gz]   (default: newest)
set -eu

f="${1:-$(ls -1t backups/ianseo-*.sql.gz 2>/dev/null | head -n1)}"
[ -n "$f" ] && [ -f "$f" ] || { echo "no backup file found"; exit 1; }

printf 'Restore %s into database "ianseo"? This REPLACES all current data. [y/N] ' "$f"
read -r a
case "$a" in
  y|Y) ;;
  *) echo "aborted"; exit 1 ;;
esac

# Decompress fully before importing. Piping straight into mysql would hide a
# gunzip failure (no pipefail in POSIX sh) and could leave a half-imported
# database; gzip -t alone does not catch every damaged archive.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
gunzip -c "$f" > "$tmp"

docker compose exec -T db \
  mysql -u ianseo -pianseo --default-character-set=utf8mb4 ianseo < "$tmp"
echo "restored from $f"
