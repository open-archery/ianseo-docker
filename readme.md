# 🏹 Open Archery \ IANSEO Docker

Unofficial Docker setup for IANSEO.

![Version](https://img.shields.io/github/v/release/open-archery/ianseo-docker) ![License](https://img.shields.io/github/license/open-archery/ianseo-docker)

## How to use

1. Clone this repository.
2. Download the latest IANSEO release from official website, and extract it to `ianseo` directory.
3. Run `docker-compose up -d`.
4. Open `http://localhost` in your browser.

## How the app files are served

The `ianseo` directory is not mounted into the container directly. `docker compose
up` first copies it into a volume on the container filesystem (about 20 seconds),
and the app is served from there.

The reason is that IANSEO calls `file_exists()` in loops — one page load makes
around 220 file syscalls, 64 of them on the same language file. Those are free on
a native filesystem, but a Docker Desktop bind mount to a Windows or macOS
directory charges roughly 1 ms per call, which turns a 10 ms page into a 280 ms
one. Serving from the volume removes that per-call cost.

So after changing anything under `ianseo`, run `docker compose up -d` to resync —
with two exceptions, which are mounted from the host and are live immediately.

### Live directories

`ianseo/Modules/Custom` is mounted straight from the host. It is IANSEO's own
extension point, the directory meant to hold your code and survive updates, so
edits there take effect on the next request with no resync.

To keep another directory live — a module you develop in place, say — create a
`docker-compose.override.yml` next to `docker-compose.yml`:

```yaml
services:
  app:
    volumes:
      - ./ianseo/Modules/Sets/PL:/var/www/html/Modules/Sets/PL
```

Compose picks that file up automatically and appends to the mount list. Keep it
to directories you actually edit: each one pays the bind mount's file access cost
again, which is invisible for a small module and very much not for the whole tree.

### Consequences

- Files IANSEO writes into its own tree (the `TV/Photos` cache, generated ID cards
  and scorecards) live in the volume, not in `ianseo`. They are rebuilt from the
  database, so nothing is lost — but do not look for them on the host.
- The resync wipes the volume before copying, so a stale file from a previous
  IANSEO release cannot survive an upgrade.

## Database connection data

- **Host:** `db`
- Username: `ianseo`
- Password: `ianseo`
- Database name: `ianseo`

Same for Write and Read server. You don't need to provide root password.

## Adminer

If you need to access database directly, you can use Adminer. It's available at `http://localhost:8080`.

## Backups

Database dumps land in `./backups` every 30 minutes; the 3 newest are kept.
Tune with `BACKUP_INTERVAL` (seconds) and `BACKUP_KEEP` in a `.env` file — see `.env.example`.
Both must be positive integers; the backup service refuses to start otherwise.

Dumps contain the entire database and are written owner-readable only. If the host
holds personal data, keep `./backups` on an encrypted disk or restrict access to it.

### Restore

    docker compose stop app
    ./restore.sh                                         # newest backup
    ./restore.sh backups/ianseo-2026-08-22_170000.sql.gz  # a specific one
    docker compose start app

Clean restore (also wipes tables that are not in the dump):

    docker compose exec db mysql -u root -pianseo -e 'drop database ianseo; create database ianseo;'
    ./restore.sh

Manual equivalent, if you prefer no script:

    gunzip -c backups/ianseo-2026-08-22_170000.sql.gz > /tmp/dump.sql
    docker compose exec -T db mysql -u ianseo -pianseo ianseo < /tmp/dump.sql
