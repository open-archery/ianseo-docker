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

# Download in full and verify before unpacking, so a truncated transfer cannot
# leave half a release behind.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

echo "Downloading $IANSEO_URL"
curl -fL --progress-bar -o "$tmp" "$IANSEO_URL"
unzip -tq "$tmp" >/dev/null 2>&1 || { echo "the download is not a valid zip archive."; exit 1; }

mkdir -p "$IANSEO_DIR"
unzip -q "$tmp" -d "$IANSEO_DIR"

echo
echo "unpacked into $IANSEO_DIR ($(ls -A "$IANSEO_DIR" | wc -l | tr -d ' ') entries)"
echo "Next: docker compose up -d      (seeds the volume and starts IANSEO)"
echo "      ./clone-pl.sh             (only if you want the Polish rule set)"
