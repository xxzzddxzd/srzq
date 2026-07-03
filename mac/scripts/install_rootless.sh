#!/bin/sh
set -eu

if [ "$#" -lt 1 ]; then
    echo "usage: $0 root@device [ssh_port]" >&2
    exit 2
fi

TARGET="$1"
PORT="${2:-22}"
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DYLIB="$PROJECT_DIR/.theos/obj/debug/SoccerAppBypass.dylib"
PLIST="$PROJECT_DIR/SoccerAppBypass.plist"
REMOTE_DIR="/var/jb/Library/MobileSubstrate/DynamicLibraries"
AUTO_BUILD="${AUTO_BUILD:-1}"

if [ ! -f "$PLIST" ]; then
    echo "missing $PLIST" >&2
    exit 1
fi

needs_build() {
    if [ ! -f "$DYLIB" ]; then
        return 0
    fi
    if [ "$PROJECT_DIR/Makefile" -nt "$DYLIB" ]; then
        return 0
    fi
    for source in "$PROJECT_DIR"/Sources/*; do
        if [ -e "$source" ] && [ "$source" -nt "$DYLIB" ]; then
            return 0
        fi
    done
    return 1
}

if needs_build; then
    if [ "$AUTO_BUILD" = "0" ]; then
        echo "dylib is missing or stale; run scripts/build.sh first, or unset AUTO_BUILD=0" >&2
        exit 1
    fi
    "$PROJECT_DIR/scripts/build.sh"
fi

ssh -p "$PORT" "$TARGET" "mkdir -p '$REMOTE_DIR'"
scp -P "$PORT" "$DYLIB" "$TARGET:$REMOTE_DIR/SoccerAppBypass.dylib"
scp -P "$PORT" "$PLIST" "$TARGET:$REMOTE_DIR/SoccerAppBypass.plist"
ssh -p "$PORT" "$TARGET" "chmod 755 '$REMOTE_DIR/SoccerAppBypass.dylib'; chmod 644 '$REMOTE_DIR/SoccerAppBypass.plist'; killall SoccerApp 2>/dev/null || true"
echo "installed $REMOTE_DIR/SoccerAppBypass.dylib"
echo "installed $REMOTE_DIR/SoccerAppBypass.plist"
ssh -p "$PORT" "$TARGET" "if command -v sha256sum >/dev/null 2>&1; then sha256sum '$REMOTE_DIR/SoccerAppBypass.dylib' '$REMOTE_DIR/SoccerAppBypass.plist'; elif command -v shasum >/dev/null 2>&1; then shasum -a 256 '$REMOTE_DIR/SoccerAppBypass.dylib' '$REMOTE_DIR/SoccerAppBypass.plist'; elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 -r '$REMOTE_DIR/SoccerAppBypass.dylib' '$REMOTE_DIR/SoccerAppBypass.plist'; else echo 'remote sha256 unavailable: no sha256sum/shasum/openssl'; fi" || true
