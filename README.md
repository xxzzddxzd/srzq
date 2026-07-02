# SoccerAppBypass

Rootless/Dopamine tweak for `jp.co.level5.inazumacross` / `SoccerApp`.

## What It Does

- Hides common jailbreak/rootless artifacts from the app:
  - `/var/jb`, Procursus, Sileo/Zebra/Cydia/Filza paths
  - MobileSubstrate/ElleKit/Substitute/Frida/TweakInject image names
  - jailbreak URL schemes
  - `fork`, `ptrace(PT_DENY_ATTACH)`, `sysctl` debugger flags
- Suppresses the jailbreak/debugger blocking alert if it is presented.
- Logs Foundation-network requests and responses:
  - `NSURLSession` completion-based data/upload/download tasks
  - `NSURLSessionTask resume` request creation path
  - `NSURLConnection` synchronous/asynchronous APIs
- Trust hooks return success for `SecTrustEvaluate` and `SecTrustEvaluateWithError`.

## Build

```sh
cd /Users/xuzhengda/Documents/workspace/srzq/111/SoccerAppBypass
./scripts/build.sh
```

`build.sh` first verifies the hard-coded Finish capture RVA and field offsets
against the local IL2CPP dump. To run only that check:

```sh
make verify-offsets
```

To run the Mac-side Finish evidence verifier and summary self-test without a
device:

```sh
make selftest-finish-evidence
```

Built dylib:

```text
.theos/obj/debug/SoccerAppBypass.dylib
```

## Deploy To Dopamine Device

This update path pushes the dylib and filter plist, then kills the target app.
It does not reboot, respring, run `sbreload`, or kill SpringBoard.
If the dylib is missing or older than the Makefile/Sources, the script runs
`scripts/build.sh` first. Set `AUTO_BUILD=0` to make stale artifacts an error.

```sh
./scripts/install_rootless.sh root@DEVICE_IP 22
```

If using an `iproxy` tunnel:

```sh
./scripts/install_rootless.sh root@127.0.0.1 2222
```

The filter plist is `SoccerAppBypass.plist` and is installed to:

```text
/var/jb/Library/MobileSubstrate/DynamicLibraries/SoccerAppBypass.plist
```

Daily updates can use the same script.

## Logs

Logs are written inside the app container:

```text
Library/Caches/SoccerAppBypassLogs/
```

Each app launch gets its own session directory named like:

```text
20260629-082041-pid28571/
```

`latest` is updated to point at the newest session directory.

Files are linked by the same numeric id:

```text
index.tsv
000001-meta.txt
000001-request.bin
000001-response.bin
```

`index.tsv` maps id, time, event, source, method, URL, request file, and response file.

Loaded IL2CPP metadata is written under the session `metadata/` directory:

```text
metadata/global-metadata.dat
metadata/global-metadata.runtime.dat
metadata/metadata-info.txt
```

`global-metadata.dat` is repaired for dumper use when the runtime image has zeroed the IL2CPP magic. `global-metadata.runtime.dat` is only written when that repair was needed and preserves the exact in-memory bytes.

## Finish Body Capture

The local control server exposes an opt-in capture path for the app's native
`FinishMainStoryBattleReq` creation. The hook is not installed at launch; it is
only installed when this endpoint is called:

```sh
curl -sS http://127.0.0.1:19876/finish-capture/install
curl -sS http://127.0.0.1:19876/finish-capture/clear
```

After the app runs and finishes a real main-story battle, fetch the captured
body:

```sh
curl -sS http://127.0.0.1:19876/finish-capture/last
```

To normalize that response into a submit-ready request body from the Mac side:

```sh
python3 /Users/xuzhengda/Documents/workspace/srzq/battle_automation/soccer_battle_client.py \
  phone-finish-capture \
  --control-url http://127.0.0.1:19876 \
  --out-body /tmp/phone_finish_body.json \
  --out-raw /tmp/phone_finish_body.raw.json
```

If the same app run also produced network log files under
`SoccerAppBypassLogs/latest`, extract the native Start/Finish pair:

```sh
python3 /Users/xuzhengda/Documents/workspace/srzq/battle_automation/soccer_battle_client.py \
  extract-log-battle-fixture /path/to/SoccerAppBypassLogs/latest \
  --out /tmp/app_battle_fixture.json
```

The printed summary should include `"finish_accepted": true` and
`"finish_http_status": 200` for a server-accepted native app result.

Then compare the hook-captured body with the app's logged Finish request:

```sh
python3 /Users/xuzhengda/Documents/workspace/srzq/battle_automation/soccer_battle_client.py \
  phone-finish-capture \
  --snapshot /tmp/finish_capture_last.json \
  --compare /tmp/app_battle_fixture.json
```

Or run the combined evidence check in one step:

```sh
python3 /Users/xuzhengda/Documents/workspace/srzq/battle_automation/soccer_battle_client.py \
  verify-phone-finish-evidence \
  --snapshot /tmp/finish_capture_last.json \
  --fixture /tmp/app_battle_fixture.json \
  --out-body /tmp/phone_finish_body.json \
  --out-report /tmp/phone_finish_evidence.json
```

The combined report is the current acceptance gate for this route: it should
print `"ok": true`, `"body_match": true`, and
`"server_acceptance": {"accepted": true, ...}`. When the fixture contains raw
network logs, it should also report
`"raw_body_equivalence": {"json_match": true, ...}` and
`"capture_diagnostics": {"capture_shape_ok": true, ...}`.

For a connected Dopamine device, the helper script can push the current dylib,
open the app, install the opt-in capture hook, wait while you manually finish
one real battle, then collect evidence:

```sh
./scripts/finish_capture_evidence.sh deploy-all root@localhost 2224
```

If you need to split the flow for debugging, first install the opt-in hook and
clear old capture state:

```sh
./scripts/finish_capture_evidence.sh install root@localhost 2224
```

After finishing one real main-story battle in the app, collect and verify the
capture plus the app's native network logs:

```sh
./scripts/finish_capture_evidence.sh collect root@localhost 2224
```

Or use `all` to install first, wait for Enter while you manually finish the
battle, then collect evidence:

```sh
./scripts/finish_capture_evidence.sh all root@localhost 2224
```

The helper waits for `http://127.0.0.1:19876/health` before installing or
collecting. If the app takes longer to launch, set a larger timeout:

```sh
WAIT_SECONDS=90 ./scripts/finish_capture_evidence.sh deploy-all root@localhost 2224
```

During collection, the helper reads `logRoot` from `/finish-capture/last` and
pulls that exact session directory from the device. If an older build does not
return `logRoot`, it falls back to the newest `SoccerAppBypassLogs/latest`
directory. The evidence directory also contains `local_artifacts.json` with the
local dylib/plist SHA-256 values used for that run, and `remote_artifacts.json`
with the installed device-side dylib/plist metadata when the device can provide
it. The root of the evidence directory also mirrors the same-session
`finish_capture_install.json`, `finish_capture_clear.json`, and
`finish_capture_logged_last.json` files when those control snapshots are present
in the pulled log directory. It also writes `evidence_summary.json`, a compact
roll-up of the acceptance checks, battle seed/stage, server status, capture
diagnostics, log directory, and local-vs-device artifact hashes.

## Current Evidence

Static command-line analysis found the jailbreak warning string in `Payload/SoccerApp.app/Frameworks/anogs.framework/anogs`. That framework also imports `access`, `open`, `opendir`, `stat`, `sysctl`, dyld image APIs, `NSURLSession`, and `NSURLConnection`, so the first bypass layer targets those surfaces.
