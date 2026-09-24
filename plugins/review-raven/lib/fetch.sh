#!/usr/bin/env bash
# Ensure the review raven binary for this platform is in the cache, and print
# its path on stdout.
#
# Both POSIX entry points call this: bin/review-raven before exec'ing the
# binary, and hooks/prefetch.sh to warm the cache ahead of first use. Keeping
# the download in one place means the launcher and the hook cannot disagree
# about where the binary lives or whether it is trustworthy.
#
# THIS FILE HAS A TWIN: bin/review-raven.ps1 does all of the below again in
# PowerShell, because Windows has to work without bash and no code can be
# shared across the two languages. A change here is a change there. What the
# two must agree on:
#
#   - the cache directory, which on Windows is the user profile's .cache
#   - the asset name, its archive format, the binary's name inside it, and the
#     checksum file's format
#   - the rule that a binary is only run once its digest matches
#   - the lock's name, its location, and when it is considered stale
#
# Changing one alone does not fail any test; it splits users across two caches
# or, worse, leaves one platform verifying nothing.
#
# Everything except the final path goes to stderr, so a caller can capture the
# path with a plain command substitution.
#
# Exit status is 0 with the path on stdout, or non-zero with a diagnostic on
# stderr. Callers decide whether a failure is fatal: it is for the launcher,
# which has nothing to run, and it is not for the prefetch hook, which is an
# optimisation over the launcher's own download.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="karottenreibe/review-raven-marketplace"

die() { echo "review-raven: $*" >&2; exit 1; }

[ -f "$ROOT/VERSION.txt" ] || die "VERSION.txt is missing from the plugin; the installation is incomplete"
VERSION="$(tr -d ' \t\r\n' < "$ROOT/VERSION.txt")"
[ -n "$VERSION" ] || die "VERSION.txt is empty; the installation is incomplete"

# Target triples and archive formats match the assets the release workflow
# builds. An unlisted platform is a hard stop with its identity named, because
# the next thing the user has to do is tell us what to build.
EXE=""
ARCHIVE="tar.gz"
case "$(uname -s)" in
    Linux)
        case "$(uname -m)" in
            x86_64|amd64) TRIPLE="x86_64-unknown-linux-musl" ;;
            *) die "no binary for Linux $(uname -m); supported: x86_64" ;;
        esac ;;
    Darwin)
        case "$(uname -m)" in
            arm64|aarch64) TRIPLE="aarch64-apple-darwin" ;;
            *) die "no binary for macOS $(uname -m); supported: arm64 (Apple Silicon)" ;;
        esac ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
        TRIPLE="x86_64-pc-windows-msvc"; EXE=".exe"; ARCHIVE="zip" ;;
    *) die "no binary for $(uname -s) $(uname -m)" ;;
esac

ASSET="review-raven-${TRIPLE}.${ARCHIVE}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/review-raven/$VERSION"
BIN="$CACHE/review-raven$EXE"

# A cache hit is the overwhelmingly common case and does no work beyond this
# test, which is what makes running on every session start acceptable.
if [ -x "$BIN" ]; then
    echo "$BIN"
    exit 0
fi

# The expected digest ships with the plugin over git rather than being fetched
# alongside the binary, so a tampered download cannot also supply the hash that
# would clear it.
[ -f "$ROOT/checksums.txt" ] || die "checksums.txt is missing from the plugin; the installation is incomplete"
WANT="$(awk -v a="$ASSET" '$2 == a || $2 == "*" a { print $1 }' "$ROOT/checksums.txt" | head -n 1)"
[ -n "$WANT" ] || die "checksums.txt has no entry for $ASSET; this plugin build does not support your platform"

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 "$1" | awk '{print $NF}'
    else return 1
    fi
}

mkdir -p "$CACHE" || die "cannot create the cache directory $CACHE"

# mkdir is atomic on every filesystem worth supporting, which makes it a lock
# that several sessions starting at once cannot all win. The loser waits for
# the winner rather than starting a second download of the same file.
LOCK="$CACHE/.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    # A lock left behind by a killed process would otherwise block the download
    # forever, so one older than five minutes is taken as abandoned.
    if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then
        rmdir "$LOCK" 2>/dev/null || true
        mkdir "$LOCK" 2>/dev/null || die "another process is downloading the binary; try again shortly"
    else
        # Wait out the holder, then use whatever it produced.
        n=0
        while [ -d "$LOCK" ] && [ "$n" -lt 120 ]; do sleep 1; n=$((n + 1)); done
        [ -x "$BIN" ] || die "another process is downloading the binary; try again shortly"
        echo "$BIN"
        exit 0
    fi
fi
URL="https://github.com/$REPO/releases/download/v$VERSION/$ASSET"
TMP="$CACHE/.download.$$.$ARCHIVE"
UNPACKED="$CACHE/.download.$$"
# The archive and its extracted contents are scratch space; only the verified
# binary moved to $BIN outlives this script, whichever way it exits.
trap 'rm -rf "$TMP" "$UNPACKED"; rmdir "$LOCK" 2>/dev/null || true' EXIT INT TERM

echo "review-raven: fetching $VERSION for $TRIPLE" >&2
if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 2 -o "$TMP" "$URL" || die "download failed: $URL"
elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$TMP" "$URL" || die "download failed: $URL"
else
    die "neither curl nor wget is available to download the binary"
fi

GOT="$(sha256_of "$TMP")" || die "no SHA-256 tool available to verify the download"
[ "$GOT" = "$WANT" ] || die "checksum mismatch for $ASSET (expected $WANT, got $GOT); refusing to run it"

# Extraction happens only after the digest matched, so no unverified archive is
# ever unpacked. Git Bash ships unzip in most installations; PowerShell is the
# fallback because it is present on every Windows machine.
mkdir -p "$UNPACKED" || die "cannot create $UNPACKED"
case "$ARCHIVE" in
    tar.gz) tar -xzf "$TMP" -C "$UNPACKED" || die "cannot extract $ASSET" ;;
    zip)
        if command -v unzip >/dev/null 2>&1; then
            unzip -q "$TMP" -d "$UNPACKED" || die "cannot extract $ASSET"
        else
            powershell.exe -NoProfile -Command \
                "Expand-Archive -LiteralPath '$(cygpath -w "$TMP")' -DestinationPath '$(cygpath -w "$UNPACKED")'" \
                || die "cannot extract $ASSET"
        fi ;;
esac
[ -f "$UNPACKED/review-raven$EXE" ] || die "$ASSET does not contain review-raven$EXE"

chmod +x "$UNPACKED/review-raven$EXE"
# The binary becomes visible at its final name only once it is complete and
# verified, so an interrupted download can never be picked up as a cache hit.
mv -f "$UNPACKED/review-raven$EXE" "$BIN" || die "cannot install the binary into $CACHE"

echo "$BIN"
