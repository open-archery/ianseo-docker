# 🏹 Open Archery \ IANSEO Docker

Unofficial Docker setup for IANSEO.

![License](https://img.shields.io/github/license/open-archery/ianseo-docker)

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
