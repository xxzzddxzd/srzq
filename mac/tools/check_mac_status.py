#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path


def candidates(app_id: str):
    playcover_apps = Path(os.environ.get("PLAYCOVER_APPS", str(Path.home() / "Library/Containers/io.playcover.PlayCover/Applications")))
    yield playcover_apps / "srzq_plugin_status" / app_id / "latest_status.json"
    yield Path("/tmp") / "srzq_plugin_status" / app_id / "latest_status.json"


def main():
    parser = argparse.ArgumentParser(description="Read SoccerAppBypass Mac status written by the injected dylib.")
    parser.add_argument("--app-id", default=os.environ.get("APP_ID", "jp.co.level5.inazumacross"))
    args = parser.parse_args()

    for path in candidates(args.app_id):
        if not path.exists():
            continue
        data = json.loads(path.read_text())
        print(json.dumps({"path": str(path), **data}, ensure_ascii=False, indent=2, sort_keys=True))
        return

    print(json.dumps({
        "ok": False,
        "error": "status not found",
        "searched": [str(p) for p in candidates(args.app_id)],
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
