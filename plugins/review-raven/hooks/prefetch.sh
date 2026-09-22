#!/usr/bin/env bash
# Warm the binary cache so the first review of a session does not wait for a
# download.
#
# This is an optimisation and never a prerequisite: bin/review-raven downloads
# the binary itself when it is missing, so every failure here is silent and
# costs nothing but the wait it was meant to save.
#
# Two properties matter more than doing the job:
#
#   Silence. On exit 0 a SessionStart hook's stdout is added to the model's
#   context as plain text, so a stray line of progress output would be read as
#   an instruction. Nothing is written to either stream.
#
#   Never failing. The exit status is always 0. Session startup continues
#   regardless, and a non-zero status would only produce a message about a
#   condition the launcher already handles.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/review-raven"
STAMP="$CACHE_ROOT/.prefetch-failed"

# A machine that is offline, behind a proxy or pointed at a missing release
# would otherwise retry on every session start. One attempt an hour is frequent
# enough to recover on its own once the cause is gone.
if [ -f "$STAMP" ] && [ -z "$(find "$STAMP" -maxdepth 0 -mmin +60 2>/dev/null)" ]; then
    exit 0
fi

if "$ROOT/lib/fetch.sh" >/dev/null 2>&1; then
    rm -f "$STAMP" 2>/dev/null || true
else
    mkdir -p "$CACHE_ROOT" 2>/dev/null && : > "$STAMP" 2>/dev/null || true
fi

exit 0
