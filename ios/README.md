# SoccerAppBypass iOS

Rootless iOS tweak for `jp.co.level5.inazumacross` / `SoccerApp`.

## Build

```sh
./scripts/build.sh
```

Built dylib:

```text
.theos/obj/debug/SoccerAppBypass.dylib
```

## Install to a rootless device

```sh
./scripts/install_rootless.sh root@127.0.0.1 2224
```

Adjust host and port for your SSH or `iproxy` setup.

## Control API

The iOS control server defaults to `http://127.0.0.1:19876` when forwarded to
the host.

```sh
curl -sS http://127.0.0.1:19876/health
curl -sS http://127.0.0.1:19876/finish-capture/install
curl -sS http://127.0.0.1:19876/finish-capture/last
```

Use `../README.md` for the shared endpoint list.
