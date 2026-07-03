# Soccer battle automation client

This directory contains the Python client for the current workflow:

```text
Firebase/session auth -> StartMainStoryBattle
  -> local SoccerAppBypass /battle-finish-body
  -> optional FinishMainStoryBattle
```

The client does not run a Python battle simulator. Battle calculation is
delegated to the Unity/IL2CPP runtime through the injected plugin.

## Run a battle

Start the PlayCover app with the Mac plugin injected, then run:

```sh
python3 soccer_battle_api_client.py \
  --execute \
  --refresh-auth \
  --login \
  --stage-code 10210 \
  --formation-deck-code 1000 \
  --control-url http://127.0.0.1:19877
```

Add `--submit-finish` to submit the generated `FinishMainStoryBattleReq`.

## Masterdata

No pre-existing TSV directory is required on a clean Mac.

When `--execute` is used, the client calls `/v1/Entrypoint/Current`, reads
`MasterDataHost` and `ServerVersionHash`, downloads:

```text
<MasterDataHost>/public/<ServerVersionHash>.zip
```

It extracts the zip under:

```text
~/Library/Caches/SoccerBattleApiClient/MasterData/<ServerVersionHash>
```

Then it passes both `masterDataPath` and `serverVersionHash` to the plugin's
`/battle-finish-body` endpoint, so Unity loads and decrypts the same encrypted
masterdata files the original client uses.

Useful options:

```sh
--masterdata-cache <dir>        # override the local cache root
--force-masterdata-download     # replace the cached copy
--skip-masterdata-prepare       # do not download/cache masterdata
--skip-entrypoint               # do not refresh host/hash from Entrypoint/Current
```

If the plugin returns `MasterData Runtime/All directory is missing`, either the
client did not prepare masterdata, the plugin could not read the provided path,
or the endpoint was called manually without `masterDataPath`.
