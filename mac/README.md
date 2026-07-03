# SoccerAppBypass Mac

Mac Catalyst / PlayCover adaptation of the iOS SoccerAppBypass tweak.

## Build

```sh
make embedded-mac-dylib
```

Output:

```text
build/mac/SoccerAppBypass.dylib
```

## Install into PlayCover

Patch the matching app from an IPA:

```sh
SRC_ZIP=../1.ipa \
BUILD_DYLIB=0 \
APP_ID=jp.co.level5.inazumacross \
APP_EXECUTABLE_NAME=SoccerApp \
./prepare_playcover_mac.sh
```

Build the dylib first, then patch:

```sh
SRC_ZIP=../1.ipa \
APP_ID=jp.co.level5.inazumacross \
APP_EXECUTABLE_NAME=SoccerApp \
./prepare_playcover_mac.sh
```

Patch an already installed PlayCover app:

```sh
APP_ID=jp.co.level5.inazumacross \
APP_EXECUTABLE_NAME=SoccerApp \
./prepare_playcover_mac.sh
```

## Verify

```sh
open -b jp.co.level5.inazumacross
curl -sS http://127.0.0.1:19877/health
./tools/check_mac_status.py --app-id jp.co.level5.inazumacross
```

The control server defaults to `http://127.0.0.1:19877`. The floating
control panel's settings button can change the port; saving a new value
restarts only the local control server.

The same setting can be checked or saved through the local API:

```sh
curl -sS http://127.0.0.1:19877/control-settings
curl -sS -X POST http://127.0.0.1:19877/control-settings \
  -H 'Content-Type: application/json' \
  -d '{"port":19879}'
```

Generate a `FinishMainStoryBattleReq` from a live `StartMainStoryBattle`
response:

```sh
curl -sS -X POST http://127.0.0.1:19877/battle-finish-body \
  -H 'Content-Type: application/json' \
  --data-binary @start_main_story_battle_response.json
```
