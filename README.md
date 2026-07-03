# SoccerAppBypass tweak

This repository contains only the SoccerAppBypass plugin sources and helper
scripts.

## Layout

| Path | Purpose |
| --- | --- |
| `mac/` | Mac Catalyst / PlayCover plugin and installer. |
| `ios/` | Rootless iOS tweak for jailbroken devices. |

The matching app package is kept outside this repository except for release
artifacts. Do not place account sessions, Charles exports, device logs, or API
tokens here.

## Local control API

The plugin starts a local HTTP control server after the app launches.

| Platform | Default URL | Notes |
| --- | --- | --- |
| Mac / PlayCover | `http://127.0.0.1:19877` | Directly reachable from the Mac. |
| iOS device | `http://127.0.0.1:19876` | Usually reached through `iproxy` or SSH forwarding. |

Endpoints used by the current workflow:

| Endpoint | Method | Purpose |
| --- | --- | --- |
| `/health` | `GET` | Check whether the plugin server is alive. |
| `/control-settings` | `GET` / `POST` | Mac only. Read or save control server settings such as the next-launch port. |
| `/ready` | `GET` / `POST` | Basic managed runtime readiness probe. |
| `/battle-finish-body` | `POST` | Accept a `StartMainStoryBattle` response and return a generated `FinishMainStoryBattleReq`. |

Debug-only endpoint:

| Endpoint | Method | Purpose |
| --- | --- | --- |
| `/battle-stage-probe` | `POST` | Run a specific Unity battle bridge stage for diagnosis. Normal clients should use `/battle-finish-body`. |

## Install on Mac / PlayCover

Prerequisites:

- PlayCover is installed.
- The matching IPA is available.
- Xcode command line tools are installed.
- Theos is installed at `$THEOS` or `$HOME/theos` if you need to rebuild the dylib.

Install or patch the PlayCover app from an IPA:

```sh
cd mac
SRC_ZIP=../1.ipa \
BUILD_DYLIB=0 \
APP_ID=jp.co.level5.inazumacross \
APP_EXECUTABLE_NAME=SoccerApp \
./prepare_playcover_mac.sh
```

Rebuild and patch in one step:

```sh
cd mac
SRC_ZIP=../1.ipa \
APP_ID=jp.co.level5.inazumacross \
APP_EXECUTABLE_NAME=SoccerApp \
./prepare_playcover_mac.sh
```

Verify after launch:

```sh
open -b jp.co.level5.inazumacross
curl -sS http://127.0.0.1:19877/health
./tools/check_mac_status.py --app-id jp.co.level5.inazumacross
```

The Mac floating control panel has a settings button in the upper-right
corner. Changing the port is persistent and restarts only the local control
server.

## iOS tweak path

The iOS rootless tweak lives in:

```text
ios
```

Build and install to a jailbroken device:

```sh
cd ios
./scripts/build.sh
./scripts/install_rootless.sh root@127.0.0.1 2224
```

Adjust the host and port for your SSH or `iproxy` setup.
