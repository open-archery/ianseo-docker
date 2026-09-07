#!/bin/sh
# Download a packaged IANSEO release and unpack it into the ianseo directory.
# Usage: ./setup-ianseo.sh
# Override with IANSEO_URL= / IANSEO_DIR= for another release or target.
set -eu

DEFAULT_URL="https://www.ianseo.net/Release/Ianseo_20250210.zip"
# SHA-256 of the release at DEFAULT_URL. Recorded when it was added here, so it
# catches a corrupted download and any later change to the published file - not
# a signature, and no help if the file was already wrong when it was pinned.
# Update both lines together when moving to a newer release.
DEFAULT_SHA256="a70a4acc1aebb1f9d01860e5e5dc15bcc949cf4488f1c44f72cc1a57d528f341"

IANSEO_URL="${IANSEO_URL:-$DEFAULT_URL}"
IANSEO_DIR="${IANSEO_DIR:-ianseo}"
# Checked against the download. Defaults to the pin above for the release this
# script ships with, and to nothing for a URL the caller chose - pass
# IANSEO_SHA256= to check one of those too.
if [ "$IANSEO_URL" = "$DEFAULT_URL" ]; then
  IANSEO_SHA256="${IANSEO_SHA256:-$DEFAULT_SHA256}"
else
  IANSEO_SHA256="${IANSEO_SHA256:-}"
fi
# Extra curl flags for a connection that needs coaxing; see the failure message
# below. Defaulted because `set -u` would otherwise abort on the unset name.
CURL_OPTS="${CURL_OPTS:-}"

for tool in curl unzip; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required but not installed."; exit 1; }
done

# sha256sum on Linux, shasum on macOS. Prints the digest, or nothing if neither
# is available.
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Anything already there stops us, so this can never unpack over an existing
# install. The placeholder this repository ships does not count as content.
# `find -print -quit` rather than parsing ls, so a newline in a filename cannot
# masquerade as two allowed entries.
if [ -d "$IANSEO_DIR" ] && [ -n "$(find "$IANSEO_DIR" -mindepth 1 -maxdepth 1 \
     ! -name '.gitignore' ! -name '.gitkeep' -print -quit 2>/dev/null)" ]; then
  echo "$IANSEO_DIR already has something in it:"
  find "$IANSEO_DIR" -mindepth 1 -maxdepth 1 ! -name '.gitignore' ! -name '.gitkeep' \
    -exec basename {} \; 2>/dev/null | head -n 5 | sed 's/^/  /'
  echo "Move it aside first if you want a fresh release. Nothing was changed."
  exit 1
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

# The release is ~70MB and on some connections the transfer dies every few
# hundred KB - TLS "bad record mac" from an inspecting proxy or antivirus, for
# one. The server sends Accept-Ranges: bytes, so download into a partial file
# named after the URL and resume into it.
part=".download-$(basename "$IANSEO_URL")"

size_of() { [ -f "$1" ] && wc -c < "$1" | tr -d ' ' || echo 0; }

# Each attempt is a *fresh* curl. curl works out its -C - resume offset once at
# startup, so its own --retry restarts from that same offset and throws away
# whatever it had just fetched; only a new process picks up what is on disk.
attempts="${DOWNLOAD_ATTEMPTS:-100}"
echo "Downloading $IANSEO_URL"
n=0
stalled=0
ok=""
while [ "$n" -lt "$attempts" ]; do
  before=$(size_of "$part")
  # The timeouts come before $CURL_OPTS so a caller can override them. Without
  # them a connection that goes quiet without closing would hang here for good:
  # the loop below only counts an attempt once curl has exited.
  # shellcheck disable=SC2086
  if curl -fL --http1.1 --progress-bar -C - -o "$part" \
       --connect-timeout 30 --speed-limit 1024 --speed-time 30 \
       $CURL_OPTS "$IANSEO_URL"; then
    ok=1
    break
  fi
  after=$(size_of "$part")
  n=$((n + 1))
  if [ "$after" -gt "$before" ]; then
    stalled=0
    echo "  interrupted at $after bytes - resuming (attempt $n)"
  else
    stalled=$((stalled + 1))
    # Three attempts that fetched nothing at all is a broken URL or a dead
    # link, not a flaky one. Stop rather than hammer the server.
    if [ "$stalled" -ge 3 ]; then
      echo "  three attempts in a row made no progress - giving up"
      break
    fi
    echo "  no progress - retrying (attempt $n)"
  fi
  sleep 2
done

if [ -z "$ok" ]; then
  got=$(size_of "$part")
  echo
  if [ "$got" -gt 0 ]; then
    echo "Download failed. What arrived is kept in $part ($got bytes),"
    echo "so running this again carries on from there."
  else
    # Nothing came through at all, so there is nothing to resume from.
    rm -f "$part"
    echo "Download failed - nothing was transferred. Check the URL and the network."
  fi
  echo
  echo "A TLS error every few hundred KB usually means something is inspecting the"
  echo "connection - antivirus HTTPS scanning, a VPN, or a corporate proxy."
  echo "Things that help:"
  echo "  CURL_OPTS='--tlsv1.2 --tls-max 1.2' ./setup-ianseo.sh   force TLS 1.2"
  echo "  CURL_OPTS='--limit-rate 1M' ./setup-ianseo.sh           slow it down"
  echo "Or fetch the zip any other way and point the script at your copy:"
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

if [ -n "$IANSEO_SHA256" ]; then
  got=$(sha256_of "$part")
  if [ -z "$got" ]; then
    echo "warning: no sha256sum or shasum available, cannot check the archive." >&2
  elif [ "$got" != "$IANSEO_SHA256" ]; then
    rm -f "$part"
    echo "the archive does not match the expected SHA-256 - discarded it."
    echo "  expected $IANSEO_SHA256"
    echo "  got      $got"
    echo "Either the published release changed, or the download was tampered with."
    exit 1
  fi
fi

staging="$IANSEO_DIR.unpacking.$$"
# Unpack into a staging directory and move it into place afterwards. Unzipping
# straight into the target would, on a failure part-way, leave a half-release
# there - which the guard above would then read as an existing install and
# refuse to touch on the next run.
trap 'rm -rf "$staging"' EXIT
rm -rf "$staging"
mkdir -p "$staging"
unzip -q "$part" -d "$staging"

mkdir -p "$IANSEO_DIR"
find "$staging" -mindepth 1 -maxdepth 1 -exec mv {} "$IANSEO_DIR/" \;
rmdir "$staging"
rm -f "$part"
trap - EXIT

echo
echo "unpacked into $IANSEO_DIR ($(ls -A "$IANSEO_DIR" | wc -l | tr -d ' ') entries)"
echo "Next: docker compose up -d      (seeds the volume and starts IANSEO)"
echo "      ./clone-pl.sh             (only if you want the Polish rule set)"
