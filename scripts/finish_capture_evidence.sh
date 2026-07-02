#!/bin/sh
set -eu

usage() {
    cat >&2 <<'EOF'
usage: finish_capture_evidence.sh install|collect|wait-collect|all|launch|deploy|deploy-all [root@host] [ssh_port]

Environment:
  BUNDLE_ID    App bundle id, default jp.co.level5.inazumacross
  CONTROL_URL  Local control URL, default http://127.0.0.1:19876
  OUT_DIR      Output directory for collect/all/deploy-all, default /tmp/srzq_finish_evidence_<utc>
  WAIT_SECONDS Seconds to wait for the app control server, default 45
  WAIT_CAPTURE_SECONDS Seconds to wait for Finish capture in wait-collect, default 600
  POLL_SECONDS Seconds between Finish capture polls, default 5

Modes:
  install  Install the opt-in Finish capture hook and clear previous state.
  collect  Fetch /finish-capture/last, pull latest tweak logs, and verify evidence.
  wait-collect
          Wait until /finish-capture/last reports captured=true, then collect.
  all      Run install, wait for Enter after a real battle, then collect.
  launch   Open the app on the device and wait for the local control server.
  deploy   Push the current dylib, open the app, then install and clear capture.
  deploy-all
          Run deploy, wait for Enter after a real battle, then collect.
EOF
}

if [ "$#" -lt 1 ]; then
    usage
    exit 2
fi

MODE="$1"
shift

TARGET="${1:-root@localhost}"
PORT="${2:-2224}"
BUNDLE_ID="${BUNDLE_ID:-jp.co.level5.inazumacross}"
CONTROL_URL="${CONTROL_URL:-http://127.0.0.1:19876}"
WAIT_SECONDS="${WAIT_SECONDS:-45}"
WAIT_CAPTURE_SECONDS="${WAIT_CAPTURE_SECONDS:-600}"
POLL_SECONDS="${POLL_SECONDS:-5}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
CLIENT="${CLIENT:-$PROJECT_DIR/battle_automation/soccer_battle_client.py}"
DYLIB="$PROJECT_DIR/111/SoccerAppBypass/.theos/obj/debug/SoccerAppBypass.dylib"
PLIST="$PROJECT_DIR/111/SoccerAppBypass/SoccerAppBypass.plist"
REMOTE_DIR="/var/jb/Library/MobileSubstrate/DynamicLibraries"

make_out_dir() {
    if [ -n "${OUT_DIR:-}" ]; then
        printf '%s\n' "$OUT_DIR"
    else
        date_part=$(date -u +%Y%m%d-%H%M%S)
        printf '/tmp/srzq_finish_evidence_%s\n' "$date_part"
    fi
}

wait_for_control_server() {
    deadline=$(( $(date +%s) + WAIT_SECONDS ))
    while [ "$(date +%s)" -le "$deadline" ]; do
        if curl -sS -f -m 2 "$CONTROL_URL/health" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    echo "control server is not reachable at $CONTROL_URL" >&2
    echo "launch the app and make sure iproxy forwards local port 19876 to device port 19876" >&2
    return 1
}

open_app() {
    ssh -p "$PORT" "$TARGET" uiopen --bundleid "$BUNDLE_ID"
    wait_for_control_server
}

deploy_tweak() {
    "$SCRIPT_DIR/install_rootless.sh" "$TARGET" "$PORT"
}

install_capture() {
    wait_for_control_server
    curl -sS -f -m 10 "$CONTROL_URL/finish-capture/install" -o /tmp/srzq_finish_capture_install.json
    curl -sS -f -m 10 "$CONTROL_URL/finish-capture/clear" -o /tmp/srzq_finish_capture_clear.json
    echo "capture installed and cleared"
    echo "install snapshot: /tmp/srzq_finish_capture_install.json"
    echo "clear snapshot: /tmp/srzq_finish_capture_clear.json"
}

capture_snapshot_is_ready() {
    python3 - "$1" <<'PY'
import json
import sys

try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(1)
last = data.get("last") if isinstance(data.get("last"), dict) else {}
captured = bool(data.get("captured") or last.get("captured"))
body = data.get("requestBody")
if not isinstance(body, dict) or not body:
    body = last.get("requestBody")
moves = body.get("MoveSelections") if isinstance(body, dict) else None
sys.exit(0 if captured and isinstance(moves, list) and len(moves) > 0 else 1)
PY
}

wait_for_finish_capture() {
    wait_for_control_server
    deadline=$(( $(date +%s) + WAIT_CAPTURE_SECONDS ))
    snapshot="/tmp/srzq_finish_capture_wait_last.json"
    while [ "$(date +%s)" -le "$deadline" ]; do
        if curl -sS -f -m 10 "$CONTROL_URL/finish-capture/last" -o "$snapshot" &&
           capture_snapshot_is_ready "$snapshot"; then
            echo "finish capture is ready: $snapshot"
            return 0
        fi
        sleep "$POLL_SECONDS"
    done
    echo "timed out waiting for Finish capture at $CONTROL_URL after ${WAIT_CAPTURE_SECONDS}s" >&2
    echo "capture remains installed; finish one real main-story battle and run: $0 collect $TARGET $PORT" >&2
    return 1
}

wait_for_manual_battle() {
    echo "finish one real main-story battle in the app, then press Enter to collect evidence."
    if read dummy; then
        return 0
    fi
    echo "stdin closed before battle confirmation; capture remains installed." >&2
    echo "after finishing one real main-story battle, run: $0 collect $TARGET $PORT" >&2
    return 1
}

remote_latest_log_dir() {
    ssh -p "$PORT" "$TARGET" 'set -eu
best=""
best_mtime=0
for index in /var/mobile/Containers/Data/Application/*/Library/Caches/SoccerAppBypassLogs/latest/index.tsv; do
    if [ -e "$index" ]; then
        dir=${index%/index.tsv}
        real_dir=$(cd "$dir" && pwd -P)
        mtime=$(stat -f %m "$real_dir" 2>/dev/null || echo 0)
        if [ "$mtime" -ge "$best_mtime" ]; then
            best="$real_dir"
            best_mtime="$mtime"
        fi
    fi
done
if [ -n "$best" ]; then
    printf "%s\n" "$best"
    exit 0
fi
echo "SoccerAppBypassLogs/latest not found" >&2
exit 1'
}

capture_log_dir() {
    python3 - "$1" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception:
    data = {}
log_root = data.get("logRoot")
print(log_root if isinstance(log_root, str) else "")
PY
}

write_local_artifacts() {
    python3 - "$1" "$DYLIB" "$PLIST" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
artifacts = []
for label, raw_path in (("dylib", sys.argv[2]), ("plist", sys.argv[3])):
    path = Path(raw_path)
    item = {
        "label": label,
        "path": str(path),
        "exists": path.exists(),
    }
    if path.exists():
        data = path.read_bytes()
        stat = path.stat()
        item.update(
            {
                "size": stat.st_size,
                "mtime": stat.st_mtime,
                "sha256": hashlib.sha256(data).hexdigest(),
            }
        )
    artifacts.append(item)

out_path.write_text(json.dumps({"artifacts": artifacts}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
}

write_remote_artifacts() {
    out_path="$1"
    raw_path="$out_path.tsv"
    ssh -p "$PORT" "$TARGET" "REMOTE_DIR='$REMOTE_DIR' sh -s" > "$raw_path" <<'REMOTE' || true
emit_artifact() {
    label="$1"
    path="$2"
    if [ ! -e "$path" ]; then
        printf '%s\t%s\t0\t0\t0\t\n' "$label" "$path"
        return
    fi
    size=$(stat -f %z "$path" 2>/dev/null || wc -c < "$path" 2>/dev/null || echo 0)
    mtime=$(stat -f %m "$path" 2>/dev/null || echo 0)
    hash=""
    if command -v sha256sum >/dev/null 2>&1; then
        hash=$(sha256sum "$path" 2>/dev/null | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        hash=$(shasum -a 256 "$path" 2>/dev/null | awk '{print $1}')
    elif command -v openssl >/dev/null 2>&1; then
        hash=$(openssl dgst -sha256 -r "$path" 2>/dev/null | awk '{print $1}')
    fi
    printf '%s\t%s\t1\t%s\t%s\t%s\n' "$label" "$path" "$size" "$mtime" "$hash"
}

emit_artifact dylib "$REMOTE_DIR/SoccerAppBypass.dylib"
emit_artifact plist "$REMOTE_DIR/SoccerAppBypass.plist"
REMOTE
    python3 - "$out_path" "$raw_path" <<'PY'
import json
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
raw_path = Path(sys.argv[2])
artifacts = []
if raw_path.exists():
    for line in raw_path.read_text(encoding="utf-8", errors="replace").splitlines():
        parts = line.split("\t")
        if len(parts) != 6:
            continue
        label, path, exists, size, mtime, sha256 = parts
        item = {
            "label": label,
            "path": path,
            "exists": exists == "1",
            "sha256": sha256 or None,
        }
        if item["exists"]:
            try:
                item["size"] = int(size)
            except ValueError:
                item["size"] = None
            try:
                item["mtime"] = float(mtime)
            except ValueError:
                item["mtime"] = None
        artifacts.append(item)

out_path.write_text(json.dumps({"artifacts": artifacts}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
    rm -f "$raw_path"
}

collect_evidence() {
    out_dir=$(make_out_dir)
    mkdir -p "$out_dir"

    capture_json="$out_dir/finish_capture_last.json"
    local_artifacts_json="$out_dir/local_artifacts.json"
    remote_artifacts_json="$out_dir/remote_artifacts.json"
    remote_log_json="$out_dir/remote_log_dir.txt"
    capture_install_json="$out_dir/finish_capture_install.json"
    capture_clear_json="$out_dir/finish_capture_clear.json"
    capture_logged_last_json="$out_dir/finish_capture_logged_last.json"
    fixture_json="$out_dir/app_battle_fixture.json"
    body_json="$out_dir/phone_finish_body.json"
    raw_json="$out_dir/phone_finish_body.raw.json"
    report_json="$out_dir/phone_finish_evidence.json"
    summary_json="$out_dir/evidence_summary.json"
    log_dir="$out_dir/log_latest"

    write_local_artifacts "$local_artifacts_json"
    write_remote_artifacts "$remote_artifacts_json"
    wait_for_control_server
    curl -sS -f -m 10 "$CONTROL_URL/finish-capture/last" -o "$capture_json"

    remote_log=$(capture_log_dir "$capture_json")
    if [ -z "$remote_log" ]; then
        remote_log=$(remote_latest_log_dir)
    fi
    printf "%s\n" "$remote_log" > "$remote_log_json"
    scp -P "$PORT" -r "$TARGET:$remote_log" "$log_dir"
    if [ -f "$log_dir/control-finish-capture-install.json" ]; then
        cp -p "$log_dir/control-finish-capture-install.json" "$capture_install_json"
    fi
    if [ -f "$log_dir/control-finish-capture-clear.json" ]; then
        cp -p "$log_dir/control-finish-capture-clear.json" "$capture_clear_json"
    fi
    if [ -f "$log_dir/control-finish-capture-last.json" ]; then
        cp -p "$log_dir/control-finish-capture-last.json" "$capture_logged_last_json"
    fi

    python3 "$CLIENT" extract-log-battle-fixture "$log_dir" --out "$fixture_json"
    verify_status=0
    python3 "$CLIENT" verify-phone-finish-evidence \
        --snapshot "$capture_json" \
        --fixture "$fixture_json" \
        --out-body "$body_json" \
        --out-raw "$raw_json" \
        --out-report "$report_json" || verify_status=$?

    python3 "$SCRIPT_DIR/summarize_finish_evidence.py" "$out_dir" --out "$summary_json"

    echo "evidence directory: $out_dir"
    echo "local artifacts: $local_artifacts_json"
    echo "remote artifacts: $remote_artifacts_json"
    echo "capture install snapshot: $capture_install_json"
    echo "capture clear snapshot: $capture_clear_json"
    echo "remote log dir: $remote_log"
    echo "submit-ready body: $body_json"
    echo "combined report: $report_json"
    echo "evidence summary: $summary_json"
    if [ "$verify_status" -ne 0 ]; then
        echo "evidence verification failed with exit code $verify_status" >&2
        exit "$verify_status"
    fi
}

case "$MODE" in
    install)
        install_capture
        ;;
    collect)
        collect_evidence
        ;;
    wait-collect)
        wait_for_finish_capture
        collect_evidence
        ;;
    all)
        install_capture
        if wait_for_manual_battle; then
            collect_evidence
        fi
        ;;
    launch)
        open_app
        ;;
    deploy)
        deploy_tweak
        open_app
        install_capture
        ;;
    deploy-all)
        deploy_tweak
        open_app
        install_capture
        if wait_for_manual_battle; then
            collect_evidence
        fi
        ;;
    *)
        usage
        exit 2
        ;;
esac
