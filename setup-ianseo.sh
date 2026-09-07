#!/bin/sh
# Download a packaged IANSEO release and unpack it into the ianseo directory.
# Usage: ./setup-ianseo.sh
# Override with IANSEO_URL= / IANSEO_DIR= for another release or target.
set -eu

IANSEO_URL="${IANSEO_URL:-https://www.ianseo.net/Release/Ianseo_20250210.zip}"
IANSEO_DIR="${IANSEO_DIR:-ianseo}"

for tool in curl unzip; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required but not installed."; exit 1; }
done

# Anything already there stops us, so this can never unpack over an existing
# install. The placeholder this repository ships does not count as content.
if [ -d "$IANSEO_DIR" ]; then
  contents=$(ls -A "$IANSEO_DIR" 2>/dev/null | grep -vx -e '.gitignore' -e '.gitkeep' || true)
  if [ -n "$contents" ]; then
    echo "$IANSEO_DIR already has something in it:"
    echo "$contents" | head -n 5 | sed 's/^/  /'
    [ "$(echo "$contents" | wc -l)" -gt 5 ] && echo "  ..."
    echo "Move it aside first if you want a fresh release. Nothing was changed."
    exit 1
  fi
fi

# Check the nearest existing ancestor: when the directory does not exist yet it
# has to be created in its parent, and on Linux Compose leaves directories it
# creates owned by root.
writable="$IANSEO_DIR"
while [ ! -e "$writable" ]; do
  parent=$(dirname "$writable")
  [ "$parent" = "$writable" ] && break
  writable="$parent"
done
if [ ! -w "$writable" ]; then
  echo "$writable is not writable - Docker probably created it as root."
  echo "Fix its ownership and run this again."
  exit 1
fi

# The release is ~70MB and the transfer does fall over on some connections
# (TLS record errors part-way through, for one). The server sends
# Accept-Ranges: bytes, so keep the partial download under a name derived from
# the URL and resume into it: retries within this run continue where they left
# off, and so does running the script again.
part=".download-$(basename "$IANSEO_URL")"

# --retry-all-errors is what makes curl retry a mid-transfer TLS failure rather
# than give up, but it only exists in curl 7.71 and later.
retry="--retry 5 --retry-delay 2"
curl --help all 2>/dev/null | grep -q -- '--retry-all-errors' && retry="$retry --retry-all-errors"

echo "Downloading $IANSEO_URL"
if ! curl -fL --progress-bar $retry -C - -o "$part" "$IANSEO_URL"; then
  echo
  echo "Download failed. The part that arrived is kept in $part,"
  echo "so running this again resumes rather than starting over."
  echo "If it keeps failing, download the zip by hand and point the script at it:"
  echo "  IANSEO_URL=file:///path/to/$(basename "$IANSEO_URL") ./setup-ianseo.sh"
  exit 1
fi

# Verify before unpacking, so a corrupt transfer cannot leave half a release
# behind. A bad archive is deleted: resuming onto it would never come good.
if ! unzip -tq "$part" >/dev/null 2>&1; then
  rm -f "$part"
  echo "the download is not a valid zip archive - discarded it, try again."
  exit 1
fi

tmp="$part"
trap 'rm -f "$tmp"' EXIT

mkdir -p "$IANSEO_DIR"
unzip -q "$tmp" -d "$IANSEO_DIR"

echo
echo "unpacked into $IANSEO_DIR ($(ls -A "$IANSEO_DIR" | wc -l | tr -d ' ') entries)"
echo "Next: docker compose up -d      (seeds the volume and starts IANSEO)"
echo "      ./clone-pl.sh             (only if you want the Polish rule set)"
