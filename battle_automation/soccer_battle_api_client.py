#!/usr/bin/env python3
"""Minimal Soccer API battle client.

This script keeps only the live API path:

  Firebase refresh/login/session -> StartMainStoryBattle
    -> local Unity control API /battle-finish-body
    -> FinishMainStoryBattle

It intentionally does not import or run the Python battle simulator. The battle
finish body is produced by the injected Unity/IL2CPP control API.
"""

from __future__ import annotations

import argparse
import base64
import gzip
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import uuid
import zipfile
import zlib
from dataclasses import dataclass, field, fields
from pathlib import Path
from typing import Any

try:
    import requests
except ImportError:  # pragma: no cover - runtime dependency check gives a clearer error.
    requests = None


API_HOST = "jp-prd-391k-api.inazuma-cross.jp"
DEFAULT_BASE_URL = f"https://{API_HOST}"
DEFAULT_UNITY_VERSION = "6000.0.62f1"
DEFAULT_APP_PLATFORM = 1
DEFAULT_CONTROL_URL = "http://127.0.0.1:19877"
DEFAULT_MASTERDATA_HOST = "https://prd-game-391k-cdn.inazuma-cross.jp"
FIREBASE_SECURE_TOKEN_URL = "https://securetoken.googleapis.com/v1/token"
SENSITIVE_HEADER_PARTS = ("authorization", "cookie", "signature", "token", "secret")
MASTERDATA_MARKER_FILE = ".server_version_hash"
MASTERDATA_REQUIRED_FILE = "Runtime/All/LGAマスター - パラメータ.tsv"


def compact_json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"))


def load_json(path: str | Path) -> Any:
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def write_json(path: str | Path, obj: Any) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def deep_copy_json(obj: Any) -> Any:
    return json.loads(json.dumps(obj, ensure_ascii=False))


def default_masterdata_cache_root() -> Path:
    return Path.home() / "Library" / "Caches" / "SoccerBattleApiClient" / "MasterData"


def ensure_bearer(token: str) -> str:
    return token if token.lower().startswith("bearer ") else f"Bearer {token}"


def redact(value: str | None, keep: int = 8) -> str | None:
    if value is None:
        return None
    if len(value) <= keep * 2 + 3:
        return "<redacted>"
    return f"{value[:keep]}...{value[-keep:]}"


def masterdata_zip_url(masterdata_host: str, server_version_hash: str) -> str:
    host = (masterdata_host or DEFAULT_MASTERDATA_HOST).rstrip("/")
    version_hash = server_version_hash.strip()
    if not version_hash:
        raise RuntimeError("missing server_version_hash for masterdata download")
    return f"{host}/public/{version_hash}.zip"


def validate_zip_member_name(name: str) -> None:
    path = Path(name)
    if path.is_absolute() or ".." in path.parts:
        raise RuntimeError(f"unsafe masterdata zip entry: {name}")


def cache_has_masterdata(cache_dir: Path, server_version_hash: str) -> bool:
    marker = cache_dir / MASTERDATA_MARKER_FILE
    required = cache_dir / MASTERDATA_REQUIRED_FILE
    if not required.exists():
        return False
    try:
        cached_hash = marker.read_text(encoding="utf-8").strip()
    except OSError:
        return False
    return cached_hash == server_version_hash.strip()


def extract_masterdata_zip(zip_path: Path, target_dir: Path, server_version_hash: str) -> None:
    temp_dir = target_dir.with_name(f".{target_dir.name}.tmp-{os.getpid()}-{uuid.uuid4().hex[:8]}")
    if temp_dir.exists():
        shutil.rmtree(temp_dir)
    temp_dir.mkdir(parents=True)
    try:
        with zipfile.ZipFile(zip_path) as archive:
            for info in archive.infolist():
                validate_zip_member_name(info.filename)
            archive.extractall(temp_dir)

        required = temp_dir / MASTERDATA_REQUIRED_FILE
        if not required.exists():
            raise RuntimeError(f"masterdata zip does not contain {MASTERDATA_REQUIRED_FILE}")

        (temp_dir / MASTERDATA_MARKER_FILE).write_text(server_version_hash.strip() + "\n", encoding="utf-8")
        if target_dir.exists():
            shutil.rmtree(target_dir)
        target_dir.parent.mkdir(parents=True, exist_ok=True)
        temp_dir.replace(target_dir)
    except Exception:
        shutil.rmtree(temp_dir, ignore_errors=True)
        raise


def ensure_masterdata_cache(
    *,
    masterdata_host: str,
    server_version_hash: str,
    cache_root: str | Path | None,
    force: bool,
    session: Any,
) -> Path:
    version_hash = server_version_hash.strip()
    if not version_hash:
        raise RuntimeError("missing server_version_hash; cannot prepare masterdata")
    if session is None:
        raise RuntimeError("requests is required for masterdata download")

    root = Path(cache_root).expanduser() if cache_root else default_masterdata_cache_root()
    target_dir = root / version_hash
    if not force and cache_has_masterdata(target_dir, version_hash):
        print(f"   masterdata_cache: reuse {target_dir}")
        return target_dir

    url = masterdata_zip_url(masterdata_host, version_hash)
    download_path = root / f"{version_hash}.zip.download"
    root.mkdir(parents=True, exist_ok=True)
    print(f"-> masterdata_download: GET {url}")
    response = session.get(url, timeout=60)
    print(f"<- masterdata_download: {response.status_code} {response.headers.get('content-type', '')}")
    response.raise_for_status()
    download_path.write_bytes(response.content)
    try:
        extract_masterdata_zip(download_path, target_dir, version_hash)
    finally:
        download_path.unlink(missing_ok=True)
    print(f"   masterdata_cache: ready {target_dir}")
    return target_dir


def redacted_headers(headers: dict[str, str]) -> dict[str, str]:
    out: dict[str, str] = {}
    for key, value in headers.items():
        if any(part in key.lower() for part in SENSITIVE_HEADER_PARTS):
            out[key] = redact(value) or "<redacted>"
        else:
            out[key] = value
    return out


def pkcs7_pad(data: bytes, block_size: int = 16) -> bytes:
    pad_len = block_size - (len(data) % block_size)
    return data + bytes([pad_len]) * pad_len


def aes_cbc_encrypt(key: bytes, iv: bytes, data: bytes) -> bytes:
    try:
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

        encryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
        return encryptor.update(data) + encryptor.finalize()
    except ImportError:
        pass

    try:
        from Crypto.Cipher import AES

        return AES.new(key, AES.MODE_CBC, iv).encrypt(data)
    except ImportError:
        pass

    try:
        return subprocess.check_output(
            [
                "openssl",
                "enc",
                "-aes-256-cbc",
                "-K",
                key.hex(),
                "-iv",
                iv.hex(),
                "-nosalt",
                "-nopad",
            ],
            input=data,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        raise RuntimeError("install cryptography/pycryptodome or make openssl available") from exc


def create_message_signature(request_json: str, message_key: str, message_salt_b64: str) -> str:
    salt = base64.b64decode(message_salt_b64)
    dk = hashlib.pbkdf2_hmac("sha1", message_key.encode("utf-8"), salt, 1000, 48)
    key, iv = dk[:32], dk[32:48]
    digest = hashlib.md5(request_json.encode("utf-8")).digest()
    encrypted = aes_cbc_encrypt(key, iv, pkcs7_pad(digest))
    return base64.b64encode(encrypted).decode("ascii")


def response_has_application_error(response_json: dict[str, Any]) -> bool:
    for key in ("Error", "Errors", "ErrorCode", "ErrorMessage"):
        value = response_json.get(key)
        if value not in (None, "", [], {}):
            return True
    return False


def response_server_accepted(response_json: dict[str, Any]) -> bool:
    status = response_json.get("_http_status")
    try:
        status_int = int(status) if status is not None else 0
    except (TypeError, ValueError):
        status_int = 0
    return status_int < 400 and not response_has_application_error(response_json)


def template_body(templates: dict[str, Any], name: str) -> dict[str, Any] | None:
    template = templates.get(name)
    body = template.get("body") if isinstance(template, dict) else None
    if body is None:
        return None
    if not isinstance(body, dict):
        raise RuntimeError(f"template {name} has no JSON object body")
    return deep_copy_json(body)


def build_start_body(
    templates: dict[str, Any],
    *,
    stage_code: int | None,
    formation_deck_code: int | None,
) -> dict[str, Any]:
    body = template_body(templates, "start_main_story_battle") or {
        "$type": "StartMainStoryBattleReq",
        "Code": stage_code,
        "FormationDeckCode": formation_deck_code,
    }
    if stage_code is not None:
        body["Code"] = stage_code
    if formation_deck_code is not None:
        body["FormationDeckCode"] = formation_deck_code
    if body.get("Code") is None:
        raise RuntimeError("missing stage code; pass --stage-code or load a session template")
    if body.get("FormationDeckCode") is None:
        raise RuntimeError("missing formation deck code; pass --formation-deck-code or load a session template")
    return body


def build_formation_body(
    templates: dict[str, Any],
    *,
    formation_deck_code: int | None,
) -> dict[str, Any] | None:
    body = template_body(templates, "set_formation")
    if body is None:
        return None
    if formation_deck_code is not None:
        body["FormationDeckCode"] = formation_deck_code
    return body


def extract_battle_summary(start_response: dict[str, Any], finish_body: dict[str, Any] | None = None) -> dict[str, Any]:
    detail: dict[str, Any] = {}
    reservations = (start_response.get("EntityOperations") or {}).get("BattleReservation") or []
    for operation in reservations:
        current = operation.get("Current") or {}
        raw_detail = current.get("DetailJson")
        if not raw_detail:
            continue
        try:
            parsed = json.loads(raw_detail)
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, dict):
            detail = parsed
            break

    finish_body = finish_body or {}
    return {
        "stage_code": detail.get("StageCode"),
        "seed": detail.get("Seed"),
        "expected_result": finish_body.get("ExpectedResult"),
        "expected_a_score": finish_body.get("ExpectedAScore"),
        "expected_b_score": finish_body.get("ExpectedBScore"),
        "move_count": len(finish_body.get("MoveSelections") or []),
    }


@dataclass
class ApiConfig:
    base_url: str = DEFAULT_BASE_URL
    app_version: str = "1.1.1"
    app_platform: int = DEFAULT_APP_PLATFORM
    unity_version: str = DEFAULT_UNITY_VERSION
    masterdata_host: str = DEFAULT_MASTERDATA_HOST
    client_version_hash: str = ""
    server_version_hash: str = ""
    device_id: str = ""
    user_agent: str = ""
    cookie: str = ""
    authorization: str = ""
    message_signature_key: str = ""
    message_signature_salt: str = ""
    firebase_api_key: str = ""
    firebase_refresh_token: str = ""
    firebase_user_id: str = ""
    firebase_app_id: str = ""
    firebase_id_token_expires_at: float | None = None
    templates: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> "ApiConfig":
        config = cls()
        config.merge(raw)
        return config

    def merge(self, raw: dict[str, Any]) -> None:
        valid_names = {item.name for item in fields(self)}
        for key, value in raw.items():
            if key not in valid_names or value in (None, ""):
                continue
            if key == "templates":
                if not isinstance(value, dict):
                    raise RuntimeError("templates must be a JSON object")
                self.templates.update(value)
            else:
                setattr(self, key, value)

    def to_dict(self) -> dict[str, Any]:
        return {item.name: getattr(self, item.name) for item in fields(self)}


class SoccerApiClient:
    def __init__(self, config: ApiConfig, *, execute: bool, out_dir: str | Path | None = None):
        self.config = config
        self.execute = execute
        self.out_dir = Path(out_dir) if out_dir else None
        self.session = requests.Session() if requests else None

    def common_headers(self) -> dict[str, str]:
        headers = {
            "X-Unity-Version": self.config.unity_version,
            "Accept": "*/*",
            "ClientVersionHash": self.config.client_version_hash,
            "ServerVersionHash": self.config.server_version_hash,
            "DeviceId": self.config.device_id,
        }
        if self.config.user_agent:
            headers["User-Agent"] = self.config.user_agent
        if self.config.cookie:
            headers["Cookie"] = self.config.cookie
        return {key: str(value) for key, value in headers.items() if value not in (None, "")}

    def request_json(
        self,
        method: str,
        path: str,
        body_obj: dict[str, Any] | None = None,
        *,
        raw_body: str | None = None,
        authorization_required: bool = True,
        signature_required: bool = True,
        idempotency_key: str | None = None,
        label: str | None = None,
        raise_for_status: bool = True,
    ) -> dict[str, Any]:
        method = method.upper()
        request_json = raw_body if raw_body is not None else compact_json(body_obj or {})
        headers = self.common_headers()

        if authorization_required:
            if not self.config.authorization:
                raise RuntimeError("missing authorization token; load a session or use --refresh-auth")
            headers["Authorization"] = ensure_bearer(self.config.authorization)

        if signature_required:
            if not self.config.message_signature_key or not self.config.message_signature_salt:
                raise RuntimeError("missing MessageSignature-Key/Salt; run with --login or load a session")
            headers["X-Signature"] = create_message_signature(
                request_json,
                self.config.message_signature_key,
                self.config.message_signature_salt,
            )

        url = self.config.base_url.rstrip("/") + path
        data: bytes | None = None
        if method == "GET":
            from urllib.parse import urlencode

            url = f"{url}?{urlencode({'json': request_json})}"
        else:
            headers["Content-Type"] = "application/json"
            headers["IdempotencyKey"] = idempotency_key or str(uuid.uuid4())
            data = request_json.encode("utf-8")

        self.print_request_summary(label or path, method, url, headers, request_json)
        if not self.execute:
            return {
                "dry_run": True,
                "url": url,
                "method": method,
                "request_json": request_json,
                "headers": redacted_headers(headers),
            }

        if not self.session:
            raise RuntimeError("requests is required for network execution")
        response = self.session.request(method, url, headers=headers, data=data, timeout=30)
        print(f"<- {label or path}: {response.status_code} {response.headers.get('content-type', '')}")
        self.update_signature_material(response.headers)
        parsed = self.parse_response(response)
        parsed["_http_status"] = response.status_code
        self.save_response(label or path, parsed)
        if response.status_code >= 400 and raise_for_status:
            print(json.dumps(parsed, ensure_ascii=False, indent=2, sort_keys=True))
            response.raise_for_status()
        return parsed

    def parse_response(self, response: Any) -> dict[str, Any]:
        content = response.content
        encoding = response.headers.get("content-encoding", "").lower()
        if encoding == "gzip":
            try:
                content = gzip.decompress(content)
            except OSError:
                pass
        elif encoding == "deflate":
            try:
                content = zlib.decompress(content)
            except zlib.error:
                pass
        text = content.decode(response.encoding or "utf-8", errors="replace")
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            return {"raw": text}
        return parsed if isinstance(parsed, dict) else {"value": parsed}

    def update_signature_material(self, headers: Any) -> None:
        key = headers.get("MessageSignature-Key") or headers.get("messagesignature-key")
        salt = headers.get("MessageSignature-Salt") or headers.get("messagesignature-salt")
        if key:
            self.config.message_signature_key = key
        if salt:
            self.config.message_signature_salt = salt

    def save_response(self, label: str, parsed: dict[str, Any]) -> None:
        if not self.out_dir:
            return
        safe_label = re.sub(r"[^A-Za-z0-9_.-]+", "_", label).strip("_") or "response"
        write_json(self.out_dir / f"{safe_label}.json", parsed)

    def print_request_summary(
        self, label: str, method: str, url: str, headers: dict[str, str], request_json: str
    ) -> None:
        print(f"-> {label}: {method} {url}")
        print("   headers:", json.dumps(redacted_headers(headers), ensure_ascii=False, sort_keys=True))
        if request_json:
            preview = request_json if len(request_json) <= 500 else request_json[:500] + "...<truncated>"
            print("   json:", preview)

    def refresh_firebase_auth(self) -> dict[str, Any]:
        if not self.config.firebase_api_key or not self.config.firebase_refresh_token:
            raise RuntimeError("missing firebase_api_key/firebase_refresh_token in session")
        if not self.execute:
            print("-> firebase_refresh skipped in dry-run; pass --execute to refresh token")
            return {"dry_run": True}
        if not self.session:
            raise RuntimeError("requests is required for Firebase token refresh")

        response = self.session.post(
            FIREBASE_SECURE_TOKEN_URL,
            params={"key": self.config.firebase_api_key},
            data={
                "grant_type": "refresh_token",
                "refresh_token": self.config.firebase_refresh_token,
            },
            timeout=30,
        )
        print(f"<- firebase_refresh: {response.status_code} {response.headers.get('content-type', '')}")
        response.raise_for_status()
        payload = response.json()
        id_token = payload.get("id_token") or payload.get("access_token")
        if not id_token:
            raise RuntimeError("Firebase refresh response has no id_token/access_token")
        self.config.authorization = ensure_bearer(id_token)
        if payload.get("refresh_token"):
            self.config.firebase_refresh_token = payload["refresh_token"]
        if payload.get("user_id"):
            self.config.firebase_user_id = payload["user_id"]
        try:
            self.config.firebase_id_token_expires_at = time.time() + float(payload.get("expires_in", 0))
        except (TypeError, ValueError):
            self.config.firebase_id_token_expires_at = None
        return payload

    def login(self, *, device_model: str, operating_system: str, adjust_device_id: str = "") -> dict[str, Any]:
        body = {
            "$type": "LogInReq",
            "DeviceInfo": {
                "DeviceId": self.config.device_id,
                "DeviceModel": device_model,
                "OperatingSystem": operating_system,
                "AppVersion": self.config.app_version,
                "AppPlatform": self.config.app_platform,
                "AdjustDeviceId": adjust_device_id,
            },
        }
        return self.request_json(
            "POST",
            "/v1/User/LogIn",
            body,
            authorization_required=True,
            signature_required=False,
            label="login",
        )

    def get_current_entrypoint(self) -> dict[str, Any]:
        body = {
            "$type": "GetCurrentEntrypointReq",
            "AppPlatform": self.config.app_platform,
            "AppVersion": self.config.app_version,
        }
        response = self.request_json(
            "GET",
            "/v1/Entrypoint/Current",
            body,
            authorization_required=False,
            signature_required=False,
            label="entrypoint_current",
        )
        current = response.get("Current")
        if isinstance(current, dict):
            server_version_hash = current.get("ServerVersionHash")
            masterdata_host = current.get("MasterDataHost")
            if isinstance(server_version_hash, str) and server_version_hash.strip():
                self.config.server_version_hash = server_version_hash.strip()
            if isinstance(masterdata_host, str) and masterdata_host.strip():
                self.config.masterdata_host = masterdata_host.strip()
        return response

    def set_formation(self, body: dict[str, Any]) -> dict[str, Any]:
        return self.request_json(
            "POST",
            "/v1/ClubMember/SetFormation",
            body,
            authorization_required=True,
            signature_required=True,
            label="set_formation",
        )

    def start_main_story_battle(self, body: dict[str, Any]) -> dict[str, Any]:
        return self.request_json(
            "POST",
            "/v1/Battle/StartMainStoryBattle",
            body,
            authorization_required=True,
            signature_required=True,
            label="start_main_story_battle",
        )

    def finish_main_story_battle(self, body: dict[str, Any], *, raw_body: str | None = None) -> dict[str, Any]:
        return self.request_json(
            "POST",
            "/v1/Battle/FinishMainStoryBattle",
            body,
            raw_body=raw_body,
            authorization_required=True,
            signature_required=True,
            label="finish_main_story_battle",
            raise_for_status=False,
        )


def request_unity_finish_body(
    start_response: dict[str, Any],
    control_url: str,
    timeout: int,
    *,
    masterdata_path: str | Path | None = None,
    server_version_hash: str = "",
) -> dict[str, Any]:
    if requests is None:
        raise RuntimeError("requests is required to call the local Unity control API")
    url = control_url.rstrip("/") + "/battle-finish-body"
    print(f"-> unity_finish_body: POST {url}")
    payload = dict(start_response)
    if masterdata_path:
        payload["masterDataPath"] = str(Path(masterdata_path).expanduser())
    if server_version_hash:
        payload["serverVersionHash"] = server_version_hash
    response = requests.post(url, json=payload, timeout=timeout)
    print(f"<- unity_finish_body: {response.status_code} {response.headers.get('content-type', '')}")
    response.raise_for_status()
    payload = response.json()
    if not isinstance(payload, dict) or not payload.get("ok"):
        raise RuntimeError(f"Unity control API failed: {payload}")
    if not isinstance(payload.get("requestBody"), dict) or not isinstance(payload.get("rawBody"), str):
        raise RuntimeError(f"Unity control API returned no submit-ready body: {payload}")
    return payload


def load_config(args: argparse.Namespace) -> ApiConfig:
    config = ApiConfig()
    if args.session:
        config.merge(load_json(args.session))

    env_map = {
        "SOCCER_AUTH_TOKEN": "authorization",
        "SOCCER_MESSAGE_SIGNATURE_KEY": "message_signature_key",
        "SOCCER_MESSAGE_SIGNATURE_SALT": "message_signature_salt",
        "SOCCER_FIREBASE_API_KEY": "firebase_api_key",
        "SOCCER_FIREBASE_REFRESH_TOKEN": "firebase_refresh_token",
        "SOCCER_DEVICE_ID": "device_id",
        "SOCCER_CLIENT_VERSION_HASH": "client_version_hash",
        "SOCCER_SERVER_VERSION_HASH": "server_version_hash",
        "SOCCER_MASTERDATA_HOST": "masterdata_host",
        "SOCCER_CONTROL_URL": "control_url",
    }
    for env_name, key in env_map.items():
        value = os.environ.get(env_name)
        if not value:
            continue
        if key == "control_url":
            args.control_url = value
        else:
            setattr(config, key, value)

    for arg_name, key in [
        ("base_url", "base_url"),
        ("auth_token", "authorization"),
        ("message_signature_key", "message_signature_key"),
        ("message_signature_salt", "message_signature_salt"),
        ("firebase_api_key", "firebase_api_key"),
        ("firebase_refresh_token", "firebase_refresh_token"),
        ("device_id", "device_id"),
        ("client_version_hash", "client_version_hash"),
        ("server_version_hash", "server_version_hash"),
        ("masterdata_host", "masterdata_host"),
        ("app_version", "app_version"),
    ]:
        value = getattr(args, arg_name, None)
        if value:
            setattr(config, key, value)

    if config.authorization:
        config.authorization = ensure_bearer(config.authorization)
    return config


def default_session_path() -> str:
    path = Path(__file__).resolve().with_name("current_session.local.json")
    return str(path) if path.exists() else ""


def run_main_story(args: argparse.Namespace) -> int:
    config = load_config(args)
    client = SoccerApiClient(config, execute=args.execute, out_dir=args.out_dir)

    if args.refresh_auth:
        client.refresh_firebase_auth()

    if args.execute and not args.skip_entrypoint:
        client.get_current_entrypoint()

    if args.login:
        client.login(
            device_model=args.device_model,
            operating_system=args.operating_system,
            adjust_device_id=args.adjust_device_id,
        )

    formation_body = build_formation_body(config.templates, formation_deck_code=args.formation_deck_code)
    if args.set_formation:
        if formation_body is None:
            raise RuntimeError("session has no set_formation template")
        client.set_formation(formation_body)

    start_body = build_start_body(
        config.templates,
        stage_code=args.stage_code,
        formation_deck_code=args.formation_deck_code,
    )
    start_response = client.start_main_story_battle(start_body)

    if not args.execute:
        print("dry-run: StartMainStoryBattle was not sent; Unity finish generation skipped")
        save_session(args, config)
        return 0

    masterdata_path: Path | None = None
    if not args.skip_masterdata_prepare:
        masterdata_path = ensure_masterdata_cache(
            masterdata_host=config.masterdata_host,
            server_version_hash=config.server_version_hash,
            cache_root=args.masterdata_cache,
            force=args.force_masterdata_download,
            session=client.session,
        )

    finish_payload = request_unity_finish_body(
        start_response,
        args.control_url,
        args.control_timeout,
        masterdata_path=masterdata_path,
        server_version_hash=config.server_version_hash,
    )
    finish_body = finish_payload["requestBody"]
    finish_raw_body = finish_payload["rawBody"]
    summary = extract_battle_summary(start_response, finish_body)
    print("   generated_finish:", json.dumps(summary, ensure_ascii=False, sort_keys=True))

    if args.out_dir:
        out_dir = Path(args.out_dir)
        write_json(out_dir / "start_main_story_battle.request.json", start_body)
        write_json(out_dir / "unity_finish_payload.json", finish_payload)
        write_json(out_dir / "generated_finish_body.json", finish_body)
        (out_dir / "generated_finish_body.raw.json").write_text(finish_raw_body + "\n", encoding="utf-8")

    if not args.submit_finish:
        print("finish body generated but not submitted; pass --submit-finish to call FinishMainStoryBattle")
        save_session(args, config)
        return 0

    finish_response = client.finish_main_story_battle(finish_body, raw_body=finish_raw_body)
    result_summary = {
        **summary,
        "finish_http_status": finish_response.get("_http_status"),
        "finish_accepted": response_server_accepted(finish_response),
        "finish_error": finish_response.get("Error") or finish_response.get("ErrorCode"),
        "finish_message": finish_response.get("Message") or finish_response.get("ErrorMessage"),
    }
    print("   finish_result:", json.dumps(result_summary, ensure_ascii=False, sort_keys=True))
    save_session(args, config)
    return 0


def save_session(args: argparse.Namespace, config: ApiConfig) -> None:
    if args.save_session:
        write_json(args.save_session, config.to_dict())


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Minimal Soccer API client that delegates battle calculation to the local Unity control API."
    )
    parser.add_argument("--session", default=default_session_path(), help="Session JSON with auth/signature/templates")
    parser.add_argument("--save-session", help="Write updated auth/signature material")
    parser.add_argument("--out-dir", help="Write request/response JSON artifacts")
    parser.add_argument("--execute", action="store_true", help="Actually send game API and local control requests")
    parser.add_argument("--submit-finish", action="store_true", help="Submit FinishMainStoryBattle after Unity generation")
    parser.add_argument("--refresh-auth", action="store_true", help="Refresh Firebase ID token before login/battle")
    parser.add_argument("--skip-entrypoint", action="store_true", help="Do not refresh MasterDataHost/ServerVersionHash")
    parser.add_argument("--login", action="store_true", help="Call /v1/User/LogIn before battle to refresh signature headers")
    parser.add_argument("--set-formation", action="store_true", help="Call SetFormation from the session template before battle")
    parser.add_argument("--stage-code", type=int, help="Override main-story stage code")
    parser.add_argument("--formation-deck-code", type=int, help="Override formation deck code")
    parser.add_argument("--control-url", default=DEFAULT_CONTROL_URL, help="Local SoccerAppBypass control server URL")
    parser.add_argument("--control-timeout", type=int, default=90, help="Seconds to wait for local Unity finish generation")
    parser.add_argument("--masterdata-host", help="Override masterdata CDN host from Entrypoint/Current")
    parser.add_argument("--masterdata-cache", help="Directory used to cache downloaded masterdata zips")
    parser.add_argument("--skip-masterdata-prepare", action="store_true", help="Do not auto-download masterdata before Unity generation")
    parser.add_argument("--force-masterdata-download", action="store_true", help="Re-download and replace cached masterdata")
    parser.add_argument("--device-model", default="iPhone13ProMax")
    parser.add_argument("--operating-system", default="iOS 16.1.1")
    parser.add_argument("--adjust-device-id", default="")
    parser.add_argument("--base-url")
    parser.add_argument("--auth-token")
    parser.add_argument("--message-signature-key")
    parser.add_argument("--message-signature-salt")
    parser.add_argument("--firebase-api-key")
    parser.add_argument("--firebase-refresh-token")
    parser.add_argument("--device-id")
    parser.add_argument("--client-version-hash")
    parser.add_argument("--server-version-hash")
    parser.add_argument("--app-version")
    parser.set_defaults(func=run_main_story)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.submit_finish and not args.execute:
        parser.error("--submit-finish requires --execute")
    try:
        return args.func(args)
    except KeyboardInterrupt:
        return 130
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
