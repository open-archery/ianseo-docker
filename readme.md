# 🏹 Open Archery \ IANSEO Docker

Unofficial Docker setup for IANSEO.

![Version](https://img.shields.io/github/v/release/open-archery/ianseo-docker) ![License](https://img.shields.io/github/license/open-archery/ianseo-docker)

## How to use

1. Clone this repository.
2. Download the latest IANSEO release from official website, and extract it to `ianseo` directory.
3. Run `docker-compose up -d`.
4. Open `http://localhost` in your browser.

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

### Restore

    docker compose stop app
    ./restore.sh                                         # newest backup
    ./restore.sh backups/ianseo-2026-08-22_1700.sql.gz    # a specific one
    docker compose start app

Clean restore (also wipes tables that are not in the dump):

    docker compose exec db mysql -u root -pianseo -e 'drop database ianseo; create database ianseo;'
    ./restore.sh

Manual equivalent, if you prefer no script:

    gunzip -c backups/ianseo-2026-08-22_1700.sql.gz | docker compose exec -T db mysql -u ianseo -pianseo ianseo
