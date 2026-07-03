#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAYCOVER_APPS="${PLAYCOVER_APPS:-$HOME/Library/Containers/io.playcover.PlayCover/Applications}"
APP_ID="${APP_ID:-}"
APP_EXECUTABLE_NAME="${APP_EXECUTABLE_NAME:-}"
SRC_APP="${SRC_APP:-}"
SRC_ZIP="${SRC_ZIP:-}"
BUILD_DYLIB="${BUILD_DYLIB:-1}"
INJECT_PLAYTOOLS="${INJECT_PLAYTOOLS:-0}"
ALLOW_RUNNING_REPLACE="${ALLOW_RUNNING_REPLACE:-0}"
FAST_DYLIB_ONLY="${FAST_DYLIB_ONLY:-auto}"

DYLIB_SRC="$SCRIPT_DIR/build/mac/SoccerAppBypass.dylib"
DYLIB_LOAD_PATH="@executable_path/Frameworks/SoccerAppBypass.dylib"
PLAYTOOLS="${PLAYTOOLS:-$HOME/Library/Frameworks/PlayTools.framework/PlayTools}"
INJECTOR="$SCRIPT_DIR/tools/inject_load_dylib.py"
TMP_SRC_DIR=""

cleanup() {
  if [ -n "$TMP_SRC_DIR" ] && [ -d "$TMP_SRC_DIR" ]; then
    rm -rf "$TMP_SRC_DIR"
  fi
}
trap cleanup EXIT

is_macho() {
  file "$1" | grep -q 'Mach-O'
}

require_file() {
  local path="$1"
  local message="$2"
  if [ ! -f "$path" ]; then
    echo "error: $message: $path" >&2
    exit 1
  fi
}

require_dir() {
  local path="$1"
  local message="$2"
  if [ ! -d "$path" ]; then
    echo "error: $message: $path" >&2
    exit 1
  fi
}

choose_default_target() {
  if [ -n "$APP_ID" ]; then
    return
  fi

  if [ -d "$PLAYCOVER_APPS/jp.co.level5.inazumacross.app" ]; then
    APP_ID="jp.co.level5.inazumacross"
    APP_EXECUTABLE_NAME="${APP_EXECUTABLE_NAME:-SoccerApp}"
    return
  fi

  if [ -d "$PLAYCOVER_APPS/local.srzq.SoccerUnityShell.app" ]; then
    APP_ID="local.srzq.SoccerUnityShell"
    APP_EXECUTABLE_NAME="${APP_EXECUTABLE_NAME:-SoccerUnityShell}"
    echo "warning: defaulting to local.srzq.SoccerUnityShell because jp.co.level5.inazumacross is not installed" >&2
    return
  fi

  APP_ID="jp.co.level5.inazumacross"
  APP_EXECUTABLE_NAME="${APP_EXECUTABLE_NAME:-SoccerApp}"
}

resolve_executable_name() {
  local app_bundle="$1"
  if [ -n "$APP_EXECUTABLE_NAME" ]; then
    return
  fi

  if [ -f "$app_bundle/Info.plist" ]; then
    APP_EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_bundle/Info.plist" 2>/dev/null || true)"
  fi
  if [ -z "$APP_EXECUTABLE_NAME" ]; then
    APP_EXECUTABLE_NAME="SoccerApp"
  fi
}

resolve_source_app() {
  if [ -n "$SRC_APP" ] && [ -d "$SRC_APP" ]; then
    return
  fi

  if [ -n "$SRC_ZIP" ]; then
    require_file "$SRC_ZIP" "source zip missing"
    TMP_SRC_DIR="$(mktemp -d /tmp/srzq_src.XXXXXX)"
    echo "==> Extracting source app: $SRC_ZIP"
    unzip -q "$SRC_ZIP" "Payload/*.app/*" -d "$TMP_SRC_DIR"
    SRC_APP="$(find "$TMP_SRC_DIR/Payload" -maxdepth 1 -type d -name '*.app' | head -n 1)"
    if [ -n "$SRC_APP" ] && [ -d "$SRC_APP" ]; then
      return
    fi
  fi

  SRC_APP=""
}

ensure_not_running() {
  if [ "$ALLOW_RUNNING_REPLACE" = "1" ]; then
    return
  fi

  local matches
  matches="$(ps -axo pid=,command= | awk -v bundle="$APP_BUNDLE/" -v exe="/$APP_EXECUTABLE_NAME" '
    /awk -v bundle/ { next }
    /prepare_playcover_mac.sh/ { next }
    index($0, bundle) > 0 { print }
    $0 ~ exe "$" { print }
  ' || true)"

  if [ -n "$matches" ]; then
    echo "error: target app appears to be running; not patching bundle." >&2
    echo "$matches" >&2
    echo "hint: quit the app first, or set ALLOW_RUNNING_REPLACE=1 if you know this is safe." >&2
    exit 1
  fi
}

if [ "$BUILD_DYLIB" = "1" ]; then
  echo "==> Building Mac Catalyst tweak dylib"
  make -C "$SCRIPT_DIR" embedded-mac-dylib
fi

choose_default_target
APP_BUNDLE="$PLAYCOVER_APPS/$APP_ID.app"

if [ -z "$SRC_APP" ]; then
  SRC_APP="$APP_BUNDLE"
fi
resolve_source_app

if [ -n "$SRC_APP" ]; then
  resolve_executable_name "$SRC_APP"
else
  resolve_executable_name "$APP_BUNDLE"
fi

APP_EXECUTABLE="$APP_BUNDLE/$APP_EXECUTABLE_NAME"
DYLIB_DST="$APP_BUNDLE/Frameworks/SoccerAppBypass.dylib"

require_file "$DYLIB_SRC" "embedded dylib missing"
require_file "$INJECTOR" "load-command injector missing"
if [ "$INJECT_PLAYTOOLS" = "1" ]; then
  require_file "$PLAYTOOLS" "PlayTools missing"
fi

ensure_not_running

app_has_load_command() {
  otool -l "$APP_EXECUTABLE" 2>/dev/null | grep -F "$DYLIB_LOAD_PATH" >/dev/null
}

app_is_maccatalyst() {
  vtool -show-build "$APP_EXECUTABLE" 2>/dev/null | grep -F 'platform MACCATALYST' >/dev/null
}

should_fast_dylib_only() {
  if [ "$FAST_DYLIB_ONLY" = "1" ]; then
    return 0
  fi
  if [ "$FAST_DYLIB_ONLY" = "0" ]; then
    return 1
  fi
  app_has_load_command && app_is_maccatalyst
}

if [ -n "$SRC_APP" ] && [ -d "$SRC_APP" ] && [ "$(cd "$SRC_APP" && pwd -P)" != "$(dirname "$APP_BUNDLE" 2>/dev/null || echo "$PLAYCOVER_APPS")/$(basename "$APP_BUNDLE")" ]; then
  require_dir "$SRC_APP" "source app missing"
  require_file "$SRC_APP/$APP_EXECUTABLE_NAME" "source executable missing"
  mkdir -p "$PLAYCOVER_APPS"
  if [ -e "$APP_BUNDLE" ]; then
    BACKUP_BUNDLE="$APP_BUNDLE.backup.$(date +%Y%m%d_%H%M%S)"
    echo "==> Existing bundle found, moving to backup: $BACKUP_BUNDLE"
    mv "$APP_BUNDLE" "$BACKUP_BUNDLE"
  fi
  echo "==> Installing app into PlayCover applications"
  ditto "$SRC_APP" "$APP_BUNDLE"
else
  require_dir "$APP_BUNDLE" "target PlayCover app missing; set SRC_APP or SRC_ZIP to install it first"
  require_file "$APP_EXECUTABLE" "target executable missing; set APP_EXECUTABLE_NAME if needed"
  BACKUP_DIR="$APP_BUNDLE.SoccerAppBypassBackup.$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  cp -p "$APP_EXECUTABLE" "$BACKUP_DIR/"
  if [ -f "$DYLIB_DST" ]; then
    cp -p "$DYLIB_DST" "$BACKUP_DIR/"
  fi
  echo "==> Patching existing app in place; backup: $BACKUP_DIR"
fi

echo "==> Embedding tweak dylib"
mkdir -p "$APP_BUNDLE/Frameworks"
cp "$DYLIB_SRC" "$DYLIB_DST"
chmod 755 "$DYLIB_DST"

if should_fast_dylib_only; then
  echo "==> Fast dylib-only install; leaving app executable signature unchanged for TCC reuse"
  if ! vtool -set-build-version maccatalyst 11.0 14.0 -replace -output "$DYLIB_DST" "$DYLIB_DST" >/dev/null 2>&1; then
    echo "warning: vtool did not update $DYLIB_DST" >&2
  fi
  codesign --force --sign - "$DYLIB_DST" >/dev/null

  echo "==> Validating prepared bundle"
  app_has_load_command
  app_is_maccatalyst
  codesign --verify "$DYLIB_DST"

  echo "==> Prepared: $APP_BUNDLE"
  echo "==> Executable: $APP_EXECUTABLE"
  echo "==> Tweak: $DYLIB_DST"
  echo "==> Control URL: http://127.0.0.1:19877"
  exit 0
fi

echo "==> Converting Mach-O platform to Mac Catalyst"
while IFS= read -r file_path; do
  if is_macho "$file_path"; then
    if ! vtool -set-build-version maccatalyst 11.0 14.0 -replace -output "$file_path" "$file_path" >/dev/null 2>&1; then
      echo "warning: vtool did not update $file_path" >&2
    fi
    chmod 755 "$file_path"
  fi
done < <(find "$APP_BUNDLE" -type f)

echo "==> Injecting tweak load command"
if [ "$INJECT_PLAYTOOLS" = "1" ]; then
  echo "==> Injecting PlayTools"
  python3 "$INJECTOR" "$APP_EXECUTABLE" "$PLAYTOOLS"
else
  echo "==> Skipping PlayTools injection"
fi
python3 "$INJECTOR" "$APP_EXECUTABLE" "$DYLIB_LOAD_PATH"

echo "==> Signing Mach-O files"
while IFS= read -r file_path; do
  if is_macho "$file_path"; then
    chmod 755 "$file_path"
    codesign --force --sign - "$file_path" >/dev/null
  fi
done < <(find "$APP_BUNDLE" -type f)
codesign --force --sign - "$APP_BUNDLE" >/dev/null

echo "==> Validating prepared bundle"
otool -l "$APP_EXECUTABLE" | grep -F "$DYLIB_LOAD_PATH" >/dev/null
vtool -show-build "$APP_EXECUTABLE" | grep -F 'platform MACCATALYST' >/dev/null
codesign --verify --deep --strict "$APP_BUNDLE"

echo "==> Prepared: $APP_BUNDLE"
echo "==> Executable: $APP_EXECUTABLE"
echo "==> Tweak: $DYLIB_DST"
echo "==> Control URL: http://127.0.0.1:19877"
