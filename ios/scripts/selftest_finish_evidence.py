#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def compact_json(data: dict[str, Any]) -> str:
    return json.dumps(data, ensure_ascii=False, separators=(",", ":"))


def run_command(args: list[str], cwd: Path) -> None:
    result = subprocess.run(args, cwd=str(cwd), text=True, capture_output=True)
    if result.returncode == 0:
        if result.stdout.strip():
            print(result.stdout.strip())
        return

    if result.stdout.strip():
        print(result.stdout, file=sys.stderr)
    if result.stderr.strip():
        print(result.stderr, file=sys.stderr)
    raise SystemExit(result.returncode)


def artifact(label: str, path: Path, remote: bool = False) -> dict[str, Any]:
    item: dict[str, Any] = {
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
    if remote:
        suffix = "dylib" if label == "dylib" else "plist"
        item["path"] = f"/var/jb/Library/MobileSubstrate/DynamicLibraries/SoccerAppBypass.{suffix}"
    return item


def build_capture_snapshot(fixture: dict[str, Any]) -> dict[str, Any]:
    body = fixture.get("finish_request")
    if not isinstance(body, dict):
        raise SystemExit("fixture has no finish_request object")
    raw_body = fixture.get("raw_finish_request_body")
    if not isinstance(raw_body, str) or not raw_body.strip():
        raw_body = compact_json(body)

    moves = body.get("MoveSelections")
    move_count = len(moves) if isinstance(moves, list) else 0
    return {
        "ok": True,
        "installed": True,
        "installAttempted": True,
        "captured": True,
        "path": "/v1/Battle/FinishMainStoryBattle",
        "method": "POST",
        "requestBody": body,
        "rawBody": raw_body,
        "moveSelectionsCount": move_count,
        "serializedMoveSelectionsCount": move_count,
        "nullMoveSelectionsCount": 0,
        "moveSelectionsComplete": True,
        "unityBase": "0x100000000",
        "hookAddress": "0x101ff4924",
        "createFinishReqRVA": "0x1FF4924",
        "request": "0x1",
        "battle": "0x2",
        "stageContext": "0x3",
        "methodInfo": "0x4",
        "logRoot": "/var/mobile/mock/SoccerAppBypassLogs/latest",
        "logSession": "mock-session",
        "time": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "error": "",
    }


def require_summary_ok(summary_path: Path) -> None:
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    checks = summary.get("checks") if isinstance(summary, dict) else {}
    expected = {
        "ok": True,
        "captured": True,
        "body_match": True,
        "raw_json_match": True,
        "capture_shape_ok": True,
        "server_accepted": True,
        "finish_http_status": 200,
    }
    failures = []
    for key, expected_value in expected.items():
        actual = checks.get(key) if isinstance(checks, dict) else None
        if actual != expected_value:
            failures.append({"key": key, "expected": expected_value, "actual": actual})
    if failures:
        print(json.dumps({"ok": False, "failures": failures}, indent=2, sort_keys=True), file=sys.stderr)
        raise SystemExit(1)


def parse_args() -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent
    project_dir = script_dir.parents[2]
    default_fixture = project_dir / "charles/jp-prd-391k-api.inazuma-cross.jp.chlsj"

    parser = argparse.ArgumentParser(
        description="Offline self-test for the Finish capture evidence verifier and summary pipeline."
    )
    parser.add_argument(
        "--charles",
        default=str(default_fixture),
        help="Charles .chlsj file with an accepted native Start/Finish pair.",
    )
    parser.add_argument(
        "--out-dir",
        help="Output directory. Defaults to /tmp/srzq_finish_evidence_selftest_<utc>.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    script_dir = Path(__file__).resolve().parent
    tweak_dir = script_dir.parent
    project_dir = script_dir.parents[2]
    client = project_dir / "battle_automation/soccer_battle_client.py"
    charles = Path(args.charles).resolve()
    if not charles.exists():
        raise SystemExit(f"Charles fixture not found: {charles}")

    if args.out_dir:
        out_dir = Path(args.out_dir).resolve()
    else:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        out_dir = Path(f"/tmp/srzq_finish_evidence_selftest_{stamp}").resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    fixture_json = out_dir / "app_battle_fixture.json"
    capture_json = out_dir / "finish_capture_last.json"
    body_json = out_dir / "phone_finish_body.json"
    raw_json = out_dir / "phone_finish_body.raw.json"
    report_json = out_dir / "phone_finish_evidence.json"
    summary_json = out_dir / "evidence_summary.json"

    run_command(
        [
            sys.executable,
            str(client),
            "extract-battle-fixture",
            str(charles),
            "--out",
            str(fixture_json),
        ],
        project_dir,
    )
    fixture = json.loads(fixture_json.read_text(encoding="utf-8"))
    capture = build_capture_snapshot(fixture)
    write_json(capture_json, capture)
    write_json(out_dir / "finish_capture_logged_last.json", {"action": "last", **capture})
    write_json(
        out_dir / "finish_capture_install.json",
        {
            "action": "install",
            "installed": True,
            "captured": False,
            "logRoot": capture["logRoot"],
            "logSession": capture["logSession"],
        },
    )
    write_json(
        out_dir / "finish_capture_clear.json",
        {
            "action": "clear",
            "installed": True,
            "captured": False,
            "cleared": True,
            "logRoot": capture["logRoot"],
            "logSession": capture["logSession"],
        },
    )
    (out_dir / "remote_log_dir.txt").write_text(str(capture["logRoot"]) + "\n", encoding="utf-8")

    dylib = tweak_dir / ".theos/obj/debug/SoccerAppBypass.dylib"
    plist = tweak_dir / "SoccerAppBypass.plist"
    local_artifacts = [artifact("dylib", dylib), artifact("plist", plist)]
    write_json(out_dir / "local_artifacts.json", {"artifacts": local_artifacts})
    write_json(
        out_dir / "remote_artifacts.json",
        {"artifacts": [artifact("dylib", dylib, remote=True), artifact("plist", plist, remote=True)]},
    )

    run_command(
        [
            sys.executable,
            str(client),
            "verify-phone-finish-evidence",
            "--snapshot",
            str(capture_json),
            "--fixture",
            str(fixture_json),
            "--out-body",
            str(body_json),
            "--out-raw",
            str(raw_json),
            "--out-report",
            str(report_json),
        ],
        project_dir,
    )
    run_command(
        [
            sys.executable,
            str(script_dir / "summarize_finish_evidence.py"),
            str(out_dir),
            "--out",
            str(summary_json),
        ],
        project_dir,
    )
    require_summary_ok(summary_json)

    print(
        json.dumps(
            {
                "ok": True,
                "out_dir": str(out_dir),
                "summary": str(summary_json),
                "report": str(report_json),
            },
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
