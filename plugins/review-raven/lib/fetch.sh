#!/usr/bin/env bash
# Ensure the review raven binary for this platform is in the cache, and print
# its path on stdout.
#
# Both entry points call this: bin/review-raven before exec'ing the binary, and
# hooks/prefetch.sh to warm the cache ahead of first use. Keeping the download
# in one place means the launcher and the hook cannot disagree about where the
# binary lives or whether it is trustworthy.
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

# Target triples match the artefact names the release workflow uploads. An
# unlisted platform is a hard stop with its identity named, because the next
# thing the user has to do is tell us what to build.
EXE=""
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
        TRIPLE="x86_64-pc-windows-msvc"; EXE=".exe" ;;
    *) die "no binary for $(uname -s) $(uname -m)" ;;
esac

ASSET="review-raven-${TRIPLE}${EXE}"
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
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT INT TERM

URL="https://github.com/$REPO/releases/download/v$VERSION/$ASSET"
TMP="$CACHE/.download.$$"

echo "review-raven: fetching $VERSION for $TRIPLE" >&2
if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 2 -o "$TMP" "$URL" || { rm -f "$TMP"; die "download failed: $URL"; }
elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$TMP" "$URL" || { rm -f "$TMP"; die "download failed: $URL"; }
else
    die "neither curl nor wget is available to download the binary"
fi

GOT="$(sha256_of "$TMP")" || { rm -f "$TMP"; die "no SHA-256 tool available to verify the download"; }
if [ "$GOT" != "$WANT" ]; then
    rm -f "$TMP"
    die "checksum mismatch for $ASSET (expected $WANT, got $GOT); refusing to run it"
fi

chmod +x "$TMP"
# The binary becomes visible at its final name only once it is complete and
# verified, so an interrupted download can never be picked up as a cache hit.
mv -f "$TMP" "$BIN" || { rm -f "$TMP"; die "cannot install the binary into $CACHE"; }

echo "$BIN"
