# 🏹 Open Archery \ IANSEO Docker

Unofficial Docker setup for IANSEO.

![Version](https://img.shields.io/github/v/release/open-archery/ianseo-docker) ![License](https://img.shields.io/github/license/open-archery/ianseo-docker)

## How to use

1. Clone this repository.
2. Run `./setup-ianseo.sh` to fetch a packaged IANSEO release into the `ianseo`
   directory. (Or download one from the official website and extract it there
   yourself.)
3. Run `docker compose up -d`.
4. Open `http://localhost` in your browser and complete the IANSEO installer.

Want the Polish rule set as well? Run `./clone-pl.sh` — it is not part of the
release and `setup-ianseo.sh` does not fetch it.

### Getting an IANSEO release

    ./setup-ianseo.sh

Downloads the release archive, checks it really is a zip, and unpacks it into
`ianseo`. Needs `curl` and `unzip`.

It stops if `ianseo` already holds anything other than the `.gitignore` this
repository ships, so it can never unpack over an existing install — move your
tree aside first if you want a clean release. `ianseo` is left untouched unless
the whole thing succeeds: the archive is unpacked into a staging directory and
moved into place only once that worked.

The archive is checked against a SHA-256 recorded in the script, which catches a
corrupted download and any later change to the published file. It is a pin, not
a signature — it says the file is the one that was there when it was pinned.
A URL you supply yourself is not checked unless you pass `IANSEO_SHA256=`.

The release is about 70 MB and the transfer does fail on some connections. The
script retries, and keeps whatever arrived in a `.download-*` file so a retry —
or another run of the script — resumes instead of starting over. If it keeps
failing, fetch the zip however you like and point the script at your copy:

    IANSEO_URL=file:///path/to/Ianseo_20250210.zip ./setup-ianseo.sh

`IANSEO_URL=` picks a different release, `IANSEO_DIR=` a different target. The
version it defaults to is pinned in the script; bump it there when a newer
release comes out.

If the stack has already been started once, the volume was seeded from whatever
was in `ianseo` at the time, so run `docker compose run --rm ianseo-push` after
unpacking a new release. See below.

## How the app files are served

The `ianseo` directory is not mounted into the container directly. On first start
it is copied into a volume on the container filesystem, and the app is served
from there.

The reason is that IANSEO calls `file_exists()` in loops — one page load makes
around 220 file syscalls, 64 of them on the same language file. Those are free on
a native filesystem, but a Docker Desktop bind mount to a Windows or macOS
directory charges roughly 1 ms per call, which turns a 10 ms page into a 280 ms
one. Serving from the volume removes that per-call cost.

That first copy is the only one that happens on its own. The volume is what the
app actually runs on, and IANSEO writes to it — the installer's `config.inc.php`,
handheld score files, tournament exports, and every file its built-in updater
downloads or deletes. So after the initial seed, **copying only happens when you
ask for it**. Restarting the stack never overwrites what IANSEO has done to its
own tree, and `docker compose up -d` on a running stack no longer interrupts it.

Two commands move files between `ianseo` and the volume:

| Command | Direction | When |
|---|---|---|
| `docker compose run --rm ianseo-push` | `ianseo` → volume | after extracting a new IANSEO release into `ianseo` |
| `docker compose run --rm ianseo-export` | volume → `ianseo` | after updating IANSEO from inside the app |

`ianseo-push` copies over the top and never deletes, so it cannot destroy what
IANSEO wrote. `ianseo-export` mirrors instead — including deletions, because the
updater removes files too — so after an in-app update, `ianseo` matches what is
actually being served. It prints what it will change and asks for nothing, so run
`docker compose run --rm -e DRY_RUN=1 ianseo-export` first if you want to look
before it writes. It never touches the live directories below.

### Live directories

Two directories are mounted straight from the host, so edits there take effect on
the next request with no push:

- `ianseo/Modules/Custom` — IANSEO's own extension point, the directory meant to
  hold your code and survive updates.
- `ianseo/Modules/Sets/PL` — the Polish rule set,
  [open-archery/ianseo-polish-rules](https://github.com/open-archery/ianseo-polish-rules),
  developed in place against this setup. IANSEO ships no module at that path, so
  put one there with `./clone-pl.sh` (below).

#### Getting the Polish rule set

    ./clone-pl.sh

Clones `main` into `ianseo/Modules/Sets/PL` over SSH, so the checkout is ready to
push from. Run it on a fresh setup, and again if an IANSEO update removes the
module — the updater's file scan skips `Modules/Custom` but not this path.

It never overwrites anything: if the directory already has something in it, the
script says so and stops. Move your checkout aside first if you really want a
fresh clone.

An empty directory is fine — that is what Compose leaves behind when the stack
starts without the module present — as long as you can write to it. On Linux
Compose creates it as root, in which case remove the empty directory and run the
script again.

`PL_REPO=` points at a fork. `PL_DIR=` changes where the clone lands, but the app
only serves what `docker-compose.yml` mounts, so a different path needs a
matching `docker-compose.override.yml` (see above) or the container will carry on
serving `ianseo/Modules/Sets/PL`.

The directory is bind-mounted, so the app serves the clone on the next request —
no restart, and nothing to push into the volume.

To keep another directory live — another rule set you develop in place, say —
create a `docker-compose.override.yml` next to `docker-compose.yml`:

```yaml
services:
  app:
    volumes:
      - ./ianseo/Modules/Sets/SE:/var/www/html/Modules/Sets/SE
```

Compose picks that file up automatically and appends to the mount list. Keep it
to directories you actually edit: each one pays the bind mount's file access cost
again, which is invisible for a small module and very much not for the whole tree.

### What lives in the volume

IANSEO writes into its own tree, and everything it writes lands in the volume
rather than in `ianseo`. Some of it is a cache the database can rebuild — the
`TV/Photos` pictures, the cached flag images. Some of it is not:

- `HHT/Files` — score files collected from handheld terminals
- `Tournament/TmpDownload` — tournament exports, until you download them
- `Common/config.inc.php` — written by the installer on first run
- anything IANSEO's own updater patched, and per-module config such as
  `Modules/Average/conf.php`

Run `docker compose run --rm ianseo-export` to bring all of it onto the host —
worth doing after an IANSEO update, and worth knowing about before you delete the
volume. The backup service in this repository dumps the database only; it does
not cover the volume.

To start from a genuinely clean tree, delete the volume and let the next start
refill it from `ianseo`:

    docker compose down
    docker volume rm ianseo-docker_ianseo_app
    docker compose up -d

That discards everything in the list above, so export first if you need it. It
does not touch the database — that is a separate volume.

### Updating IANSEO from inside the app

IANSEO's own updater (the `Update` page) replaces and deletes files in the tree
it is served from, which is the volume. That works, and it survives restarts.
Run `docker compose run --rm ianseo-export` afterwards so `ianseo` on the host
matches.

One thing to know first: the updater's file scan skips `Modules/Custom`, but it
does **not** skip `Modules/Sets/PL`. That directory is mounted from the host, so
an update can rewrite or delete files inside your working copy of it. It is a git
repository, so `git status` will show what happened and `git checkout` will undo
it — but commit or stash before you run an update.

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
