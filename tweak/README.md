# SoccerAppBypass tweak

This directory contains only the SoccerAppBypass plugin sources and helper
scripts.

## Layout

| Path | Purpose |
| --- | --- |
| `mac/` | Mac Catalyst / PlayCover plugin and installer. |
| `ios/` | Rootless iOS tweak for jailbroken devices. |

The matching app package is kept outside this directory. Do not place account
sessions, Charles exports, device logs, or API tokens under `tweak/`.

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
| `/control-settings` | `GET` / `POST` | Read or save control server settings such as the next-launch port. |
| `/ready` | `GET` | Basic managed runtime readiness probe. |
| `/unity-scene-probe` | `GET` | Inspect Unity/IL2CPP scene and object availability. |
| `/battle-finish-body` | `POST` | Accept a `StartMainStoryBattle` response and return a generated `FinishMainStoryBattleReq`. |
| `/finish-capture/install` | `GET` | Install the opt-in native finish request capture hook. |
| `/finish-capture/clear` | `GET` | Clear old finish capture state. |
| `/finish-capture/last` | `GET` | Read the latest captured native finish request body. |

## Install on Mac / PlayCover

Prerequisites:

- PlayCover is installed.
- The matching IPA is available.
- Xcode command line tools are installed.
- Theos is installed at `$THEOS` or `$HOME/theos` if you need to rebuild the dylib.

Install or patch the PlayCover app from an IPA:

```sh
cd tweak/mac
SRC_ZIP=../../1.ipa \
BUILD_DYLIB=0 \
APP_ID=jp.co.level5.inazumacross \
APP_EXECUTABLE_NAME=SoccerApp \
./prepare_playcover_mac.sh
```

Rebuild and patch in one step:

```sh
cd tweak/mac
SRC_ZIP=../../1.ipa \
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
tweak/ios
```

Build and install to a jailbroken device:

```sh
cd tweak/ios
./scripts/build.sh
./scripts/install_rootless.sh root@127.0.0.1 2224
```

Adjust the host and port for your SSH or `iproxy` setup.
