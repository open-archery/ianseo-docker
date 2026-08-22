#!/bin/sh
# Restore a database backup into the running db service.
# Usage: ./restore.sh [backups/ianseo-YYYY-MM-DD_HHMM.sql.gz]   (default: newest)
set -eu

f="${1:-$(ls -1t backups/ianseo-*.sql.gz 2>/dev/null | head -n1)}"
[ -n "$f" ] && [ -f "$f" ] || { echo "no backup file found"; exit 1; }

# Sanity-check the archive before touching the live database.
gzip -t "$f"

printf 'Restore %s into database "ianseo"? This REPLACES all current data. [y/N] ' "$f"
read -r a
case "$a" in
  y|Y) ;;
  *) echo "aborted"; exit 1 ;;
esac

gunzip -c "$f" | docker compose exec -T db \
  mysql -u ianseo -pianseo --default-character-set=utf8mb4 ianseo
echo "restored from $f"
