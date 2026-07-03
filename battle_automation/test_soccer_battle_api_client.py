#!/usr/bin/env python3
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parent))


class SoccerBattleApiClientTests(unittest.TestCase):
    def test_import_does_not_load_python_battle_simulator(self) -> None:
        sys.modules.pop("soccer_battle_api_client", None)
        sys.modules.pop("battle_simulator", None)

        import soccer_battle_api_client  # noqa: F401

        self.assertNotIn("battle_simulator", sys.modules)

    def test_build_start_body_uses_template_and_overrides_stage(self) -> None:
        from soccer_battle_api_client import build_start_body

        templates = {
            "start_main_story_battle": {
                "body": {
                    "$type": "StartMainStoryBattleReq",
                    "Code": 10207,
                    "FormationDeckCode": 1000,
                }
            }
        }

        body = build_start_body(templates, stage_code=10210, formation_deck_code=2000)

        self.assertEqual(
            body,
            {
                "$type": "StartMainStoryBattleReq",
                "Code": 10210,
                "FormationDeckCode": 2000,
            },
        )
        self.assertEqual(templates["start_main_story_battle"]["body"]["Code"], 10207)

    def test_config_merge_keeps_existing_values_when_update_is_empty(self) -> None:
        from soccer_battle_api_client import ApiConfig

        config = ApiConfig(authorization="Bearer old", device_id="device-a")
        config.merge({"authorization": "", "device_id": "device-b"})

        self.assertEqual(config.authorization, "Bearer old")
        self.assertEqual(config.device_id, "device-b")

    def test_masterdata_zip_url_uses_public_hash_zip(self) -> None:
        from soccer_battle_api_client import masterdata_zip_url

        self.assertEqual(
            masterdata_zip_url("https://cdn.example.test/", "abc123"),
            "https://cdn.example.test/public/abc123.zip",
        )

    def test_cache_has_masterdata_requires_marker_and_runtime_all(self) -> None:
        from soccer_battle_api_client import MASTERDATA_MARKER_FILE, MASTERDATA_REQUIRED_FILE, cache_has_masterdata

        with tempfile.TemporaryDirectory() as raw_dir:
            cache_dir = Path(raw_dir)
            self.assertFalse(cache_has_masterdata(cache_dir, "hash-a"))

            required = cache_dir / MASTERDATA_REQUIRED_FILE
            required.parent.mkdir(parents=True)
            required.write_bytes(b"encrypted")
            (cache_dir / MASTERDATA_MARKER_FILE).write_text("hash-a\n", encoding="utf-8")

            self.assertTrue(cache_has_masterdata(cache_dir, "hash-a"))
            self.assertFalse(cache_has_masterdata(cache_dir, "hash-b"))

    def test_unity_finish_request_includes_masterdata_fields(self) -> None:
        import soccer_battle_api_client

        class FakeResponse:
            status_code = 200
            headers = {"content-type": "application/json"}

            def raise_for_status(self) -> None:
                return None

            def json(self) -> dict[str, object]:
                return {"ok": True, "requestBody": {}, "rawBody": "{}"}

        class FakeRequests:
            captured_json: dict[str, object] | None = None

            @staticmethod
            def post(url: str, json: dict[str, object], timeout: int) -> FakeResponse:
                FakeRequests.captured_json = json
                return FakeResponse()

        old_requests = soccer_battle_api_client.requests
        soccer_battle_api_client.requests = FakeRequests
        try:
            soccer_battle_api_client.request_unity_finish_body(
                {"Status": 0, "EntityOperations": {}},
                "http://127.0.0.1:19877",
                10,
                masterdata_path="/tmp/masterdata",
                server_version_hash="hash-a",
            )
        finally:
            soccer_battle_api_client.requests = old_requests

        self.assertEqual(FakeRequests.captured_json["masterDataPath"], "/tmp/masterdata")
        self.assertEqual(FakeRequests.captured_json["serverVersionHash"], "hash-a")
        self.assertEqual(FakeRequests.captured_json["Status"], 0)


if __name__ == "__main__":
    unittest.main()
