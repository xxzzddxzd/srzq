#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
THEOS=${THEOS:-$HOME/theos}
export THEOS
export THEOS_PACKAGE_SCHEME=rootless
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.theos/module-cache"

cd "$PROJECT_DIR"
python3 scripts/verify_finish_offsets.py
make clean all

if command -v dpkg-deb >/dev/null 2>&1; then
    make package
else
    echo "dpkg-deb not found; built dylib and filter plist only."
fi
