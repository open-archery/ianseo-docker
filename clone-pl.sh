#!/bin/sh
# Clone the Polish rule set into the directory docker-compose.yml mounts for it.
# Usage: ./clone-pl.sh
# Override with PL_REPO= / PL_DIR= for a fork or a scratch checkout.
set -eu

PL_REPO="${PL_REPO:-git@github.com:open-archery/ianseo-polish-rules.git}"
PL_DIR="${PL_DIR:-ianseo/Modules/Sets/PL}"

# Anything already there stops us. Cloning over a checkout that has unpushed
# work is not worth the convenience of not having to move it aside by hand.
if [ -d "$PL_DIR" ] && [ -n "$(ls -A "$PL_DIR" 2>/dev/null)" ]; then
  echo "$PL_DIR already has something in it:"
  ls -A "$PL_DIR" | head -n 5 | sed 's/^/  /'
  [ "$(ls -A "$PL_DIR" | wc -l)" -gt 5 ] && echo "  ..."
  echo "Move it aside first if you want a fresh clone. Nothing was changed."
  exit 1
fi

# Compose creates this path as an empty directory when the stack starts without
# it, and on Linux that leaves it owned by root. git's error for that case is
# not obvious, so check first.
if [ -d "$PL_DIR" ] && [ ! -w "$PL_DIR" ]; then
  echo "$PL_DIR is not writable - Docker probably created it as root."
  echo "Remove the empty directory and run this again."
  exit 1
fi

git clone --branch main "$PL_REPO" "$PL_DIR"

echo
echo "cloned $PL_REPO"
echo "  into $PL_DIR on branch $(git -C "$PL_DIR" branch --show-current)"
echo "It is bind-mounted, so the app serves it on the next request."
