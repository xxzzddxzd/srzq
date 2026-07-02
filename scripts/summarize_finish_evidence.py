#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"_load_error": str(exc)}
    return data if isinstance(data, dict) else {"_load_error": "JSON root is not an object"}


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def nested_get(data: dict[str, Any] | None, *keys: str) -> Any:
    current: Any = data
    for key in keys:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current


def last_record(snapshot: dict[str, Any] | None) -> dict[str, Any]:
    last = nested_get(snapshot, "last")
    return last if isinstance(last, dict) else {}


def snapshot_field(snapshot: dict[str, Any] | None, key: str) -> Any:
    if not isinstance(snapshot, dict):
        return None
    if key in snapshot:
        return snapshot.get(key)
    last = last_record(snapshot)
    return last.get(key)


def capture_snapshot_summary(path: Path, snapshot: dict[str, Any] | None) -> dict[str, Any]:
    result: dict[str, Any] = {
        "file": path.name,
        "exists": path.exists(),
    }
    if not isinstance(snapshot, dict):
        return result
    if snapshot.get("_load_error"):
        result["load_error"] = snapshot.get("_load_error")
        return result
    for key in (
        "action",
        "installed",
        "captured",
        "path",
        "method",
        "logRoot",
        "logSession",
        "moveSelectionsComplete",
        "moveSelectionsCount",
        "serializedMoveSelectionsCount",
        "nullMoveSelectionsCount",
    ):
        value = snapshot_field(snapshot, key)
        if value is not None:
            result[key] = value
    last = last_record(snapshot)
    if last:
        result["lastCaptured"] = bool(last.get("captured"))
    if snapshot.get("error") is not None:
        result["error"] = snapshot.get("error")
    return result


def artifact_items(data: dict[str, Any] | None) -> dict[str, dict[str, Any]]:
    if not isinstance(data, dict):
        return {}
    items = data.get("artifacts")
    if not isinstance(items, list):
        return {}
    by_label: dict[str, dict[str, Any]] = {}
    for item in items:
        if not isinstance(item, dict):
            continue
        label = item.get("label")
        if isinstance(label, str) and label:
            by_label[label] = item
    return by_label


def artifact_summary(
    local_artifacts: dict[str, Any] | None,
    remote_artifacts: dict[str, Any] | None,
) -> dict[str, Any]:
    local = artifact_items(local_artifacts)
    remote = artifact_items(remote_artifacts)
    labels = sorted(set(local) | set(remote))
    comparison: dict[str, Any] = {}
    comparable_matches: list[bool] = []

    for label in labels:
        local_item = local.get(label, {})
        remote_item = remote.get(label, {})
        local_hash = local_item.get("sha256")
        remote_hash = remote_item.get("sha256")
        hash_match = None
        if local_hash and remote_hash:
            hash_match = local_hash == remote_hash
            comparable_matches.append(hash_match)
        comparison[label] = {
            "local_exists": local_item.get("exists"),
            "remote_exists": remote_item.get("exists"),
            "local_sha256": local_hash,
            "remote_sha256": remote_hash,
            "hash_match": hash_match,
            "local_size": local_item.get("size"),
            "remote_size": remote_item.get("size"),
            "size_match": (
                local_item.get("size") == remote_item.get("size")
                if local_item.get("size") is not None and remote_item.get("size") is not None
                else None
            ),
        }

    required = ("dylib", "plist")
    required_present = {
        label: bool(local.get(label, {}).get("exists")) and bool(remote.get(label, {}).get("exists"))
        for label in required
    }
    return {
        "local_load_error": nested_get(local_artifacts, "_load_error"),
        "remote_load_error": nested_get(remote_artifacts, "_load_error"),
        "required_present": required_present,
        "hashes_all_match_when_known": all(comparable_matches) if comparable_matches else None,
        "comparison": comparison,
    }


def file_summary(evidence_dir: Path) -> dict[str, Any]:
    names = (
        "finish_capture_last.json",
        "finish_capture_install.json",
        "finish_capture_clear.json",
        "finish_capture_logged_last.json",
        "app_battle_fixture.json",
        "phone_finish_body.json",
        "phone_finish_body.raw.json",
        "phone_finish_evidence.json",
        "local_artifacts.json",
        "remote_artifacts.json",
        "remote_log_dir.txt",
    )
    result: dict[str, Any] = {}
    for name in names:
        path = evidence_dir / name
        result[name] = {
            "exists": path.exists(),
            "path": str(path),
        }
        if path.exists():
            result[name]["size"] = path.stat().st_size
    return result


def read_remote_log_dir(evidence_dir: Path) -> str | None:
    path = evidence_dir / "remote_log_dir.txt"
    if not path.exists():
        return None
    value = path.read_text(encoding="utf-8", errors="replace").strip()
    return value or None


def build_summary(evidence_dir: Path) -> dict[str, Any]:
    report = load_json(evidence_dir / "phone_finish_evidence.json")
    local_artifacts = load_json(evidence_dir / "local_artifacts.json")
    remote_artifacts = load_json(evidence_dir / "remote_artifacts.json")
    capture_last = load_json(evidence_dir / "finish_capture_last.json")
    capture_install = load_json(evidence_dir / "finish_capture_install.json")
    capture_clear = load_json(evidence_dir / "finish_capture_clear.json")
    capture_logged_last = load_json(evidence_dir / "finish_capture_logged_last.json")

    checks = {
        "ok": nested_get(report, "ok"),
        "captured": nested_get(report, "captured"),
        "body_match": nested_get(report, "body_match"),
        "raw_json_match": nested_get(report, "raw_body_equivalence", "json_match"),
        "raw_equivalence_available": nested_get(report, "raw_body_equivalence", "available"),
        "capture_shape_ok": nested_get(report, "capture_diagnostics", "capture_shape_ok"),
        "server_accepted": nested_get(report, "server_acceptance", "accepted"),
        "finish_http_status": nested_get(report, "server_acceptance", "http_status"),
    }

    return {
        "generated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "evidence_dir": str(evidence_dir),
        "ok": checks["ok"],
        "checks": checks,
        "battle": nested_get(report, "battle") or {},
        "server_acceptance": nested_get(report, "server_acceptance") or {},
        "source": nested_get(report, "source") or {},
        "capture_diagnostics": nested_get(report, "capture_diagnostics") or {},
        "raw_body_equivalence": nested_get(report, "raw_body_equivalence") or {},
        "artifacts": artifact_summary(local_artifacts, remote_artifacts),
        "control_snapshots": {
            "install": capture_snapshot_summary(evidence_dir / "finish_capture_install.json", capture_install),
            "clear": capture_snapshot_summary(evidence_dir / "finish_capture_clear.json", capture_clear),
            "last": capture_snapshot_summary(evidence_dir / "finish_capture_last.json", capture_last),
            "logged_last": capture_snapshot_summary(
                evidence_dir / "finish_capture_logged_last.json",
                capture_logged_last,
            ),
        },
        "remote_log_dir": read_remote_log_dir(evidence_dir),
        "files": file_summary(evidence_dir),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Summarize a SoccerAppBypass Finish capture evidence directory."
    )
    parser.add_argument("evidence_dir", help="Directory produced by finish_capture_evidence.sh collect/all")
    parser.add_argument(
        "--out",
        help="Output JSON path. Defaults to <evidence_dir>/evidence_summary.json",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    evidence_dir = Path(args.evidence_dir).resolve()
    out = Path(args.out).resolve() if args.out else evidence_dir / "evidence_summary.json"
    summary = build_summary(evidence_dir)
    write_json(out, summary)
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
