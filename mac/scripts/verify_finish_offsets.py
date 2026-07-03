#!/usr/bin/env python3
"""Verify FinishRequestCapture offsets against the current IL2CPP dump."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


SOURCE_CONSTANTS = {
    "SBFinishCaptureCreateFinishMainStoryBattleReqRVA": 0x1FF4924,
    "SBFinishCaptureReqExpectedResultOffset": 0x1C,
    "SBFinishCaptureReqExpectedAScoreOffset": 0x20,
    "SBFinishCaptureReqExpectedBScoreOffset": 0x24,
    "SBFinishCaptureReqMoveSelectionsOffset": 0x28,
    "SBFinishCaptureMoveTeamIdOffset": 0x10,
    "SBFinishCaptureMovePlayerIndexOffset": 0x14,
    "SBFinishCaptureMoveMoveIndexOffset": 0x18,
    "SBFinishCaptureMoveMoveCodeOffset": 0x20,
    "SBFinishCaptureNullableHasValueOffset": 0x0,
    "SBFinishCaptureNullableValueOffset": 0x4,
    "SBFinishCaptureArrayLengthOffset": 0x18,
    "SBFinishCaptureArrayItemsOffset": 0x20,
}

FINISH_REQ_FIELDS = {
    "ExpectedResult": 0x1C,
    "ExpectedAScore": 0x20,
    "ExpectedBScore": 0x24,
    "MoveSelections": 0x28,
}

MOVE_SELECTION_FIELDS = {
    "TeamId": 0x10,
    "PlayerIndex": 0x14,
    "MoveIndex": 0x18,
    "MoveCode": 0x20,
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def default_dump_path(project_dir: Path) -> Path:
    dump_root = project_dir.parent
    candidates = sorted(dump_root.glob("metadata_dump_*/il2cppdump/dump.cs"))
    if not candidates:
        raise FileNotFoundError(f"no metadata_dump_*/il2cppdump/dump.cs under {dump_root}")
    return candidates[-1]


def parse_source_constants(source: str) -> dict[str, int]:
    constants: dict[str, int] = {}
    pattern = re.compile(r"static const uintptr_t (SBFinishCapture\w+) = (0x[0-9A-Fa-f]+);")
    for name, value in pattern.findall(source):
        constants[name] = int(value, 16)
    return constants


def parse_class_field_offsets(dump: str, class_name: str) -> dict[str, int]:
    class_match = re.search(
        rf"public (?:abstract )?class {re.escape(class_name)}\b.*?\n\{{(?P<body>.*?)\n\}}",
        dump,
        flags=re.S,
    )
    if not class_match:
        raise RuntimeError(f"class {class_name} not found in dump")
    body = class_match.group("body")
    offsets: dict[str, int] = {}
    for field, offset in re.findall(r"<([^>]+)>k__BackingField;\s*//\s*(0x[0-9A-Fa-f]+)", body):
        offsets[field] = int(offset, 16)
    return offsets


def parse_main_story_finish_rva(dump: str) -> int:
    class_start = dump.find("public class MainStoryStageContext :")
    if class_start < 0:
        raise RuntimeError("MainStoryStageContext class not found in dump")
    next_class = dump.find("\npublic class ", class_start + 1)
    class_body = dump[class_start:] if next_class < 0 else dump[class_start:next_class]
    match = re.search(
        r"// RVA:\s*(0x[0-9A-Fa-f]+)[^\n]*\n\s*public override FinishBattleReq CreateFinishBattleReq"
        r"\(SoccerBattle battle\)",
        class_body,
        flags=re.S,
    )
    if not match:
        raise RuntimeError("MainStoryStageContext.CreateFinishBattleReq RVA not found in dump")
    return int(match.group(1), 16)


def check_equal(errors: list[str], label: str, actual: int | None, expected: int) -> None:
    if actual != expected:
        actual_text = "missing" if actual is None else f"0x{actual:X}"
        errors.append(f"{label}: expected 0x{expected:X}, got {actual_text}")


def main() -> int:
    project_dir = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=project_dir / "Sources/FinishRequestCapture.m")
    parser.add_argument("--dump", type=Path, default=None)
    args = parser.parse_args()

    dump_path = args.dump or default_dump_path(project_dir)
    source = read_text(args.source)
    dump = read_text(dump_path)

    errors: list[str] = []
    source_constants = parse_source_constants(source)
    for name, expected in SOURCE_CONSTANTS.items():
        check_equal(errors, f"source constant {name}", source_constants.get(name), expected)

    rva = parse_main_story_finish_rva(dump)
    check_equal(
        errors,
        "dump MainStoryStageContext.CreateFinishBattleReq RVA",
        rva,
        source_constants.get("SBFinishCaptureCreateFinishMainStoryBattleReqRVA", SOURCE_CONSTANTS["SBFinishCaptureCreateFinishMainStoryBattleReqRVA"]),
    )

    finish_offsets = parse_class_field_offsets(dump, "FinishBattleReq")
    for field, expected in FINISH_REQ_FIELDS.items():
        check_equal(errors, f"dump FinishBattleReq.{field}", finish_offsets.get(field), expected)

    move_offsets = parse_class_field_offsets(dump, "MoveSelection")
    for field, expected in MOVE_SELECTION_FIELDS.items():
        check_equal(errors, f"dump MoveSelection.{field}", move_offsets.get(field), expected)

    if errors:
        print("finish offset verification failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"finish offset verification ok: dump={dump_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
