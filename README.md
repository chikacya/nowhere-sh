# nowhere-sh

[简体中文](README.zh-CN.md)

An interactive one-click deployment and management script for
[NodePassProject/Nowhere](https://github.com/NodePassProject/Nowhere) Portal on a
Linux VPS.

## Features

- Step-by-step setup wizard with defaults for every prompt.
- Installs a selected release to `/usr/local/bin/nowhere`.
- Lists the 10 latest GitHub releases for numeric selection.
- Updates only the Nowhere binary while preserving the current configuration.
- Creates and manages a systemd service.
- Supports `mix`, `tcp`, and `udp`, TLS modes, rate limits, SOCKS5 upstream, and logs.
- Generates Anywhere 2.0 `nowhere://` links and Native Vector `vector://` URLs.
- Prints the SHA-256 fingerprint of an ephemeral `tls=1` certificate.
- Keeps legacy Nowhere v1.4 and earlier installations available.

## Compatibility

Nowhere v1.5 introduced a new wire protocol and removed `spec`. Anywhere 2.0
supports that new protocol.

| Portal release | Client | URL | Notes |
| --- | --- | --- | --- |
| v1.5+ | Anywhere 2.0 | `nowhere://...` | No `spec`; pool is `0..9` |
| v1.5+ | Native Vector | `vector://...` | Local SOCKS5 client; pool is `0..256` |
| v1.4 and earlier | Anywhere 1.x/compatible | `nowhere://...` | Legacy URL includes `spec` |

The server protocol generation and client type are separate choices. A v1.5+
Portal can serve Anywhere 2.0 or Native Vector clients using the matching URL.

## Requirements

- A Linux VPS using systemd.
- `curl` and `tar`.
- `x86_64` or `aarch64`, with glibc or musl.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/chikacya/nowhere-sh/main/nowhere-vps.sh -o nowhere-vps.sh
chmod +x nowhere-vps.sh
sudo bash nowhere-vps.sh
```

The default menu entry installs Nowhere v1.5.1 for Anywhere 2.0. Press Enter at
every wizard prompt to accept the defaults.

```text
1) Install/Reinstall v1.5.1 for Anywhere 2.0
2) Install/Reinstall v1.5.1 for Native Vector
3) Quick default install for Anywhere 2.0
4) Reconfigure the current installation
5) Select and install one of the 10 latest releases
6) Update Nowhere binary and preserve configuration
7) Install/Reinstall legacy v1.4.0 for Anywhere 1.x
8) Start service
9) Stop service
10) Restart service
11) Show status
12) Follow logs
13) Print client URLs
14) Show tls=1 certificate SHA-256
15) Uninstall
0) Exit
```

Non-interactive default installation:

```bash
curl -fsSL https://raw.githubusercontent.com/chikacya/nowhere-sh/main/nowhere-vps.sh | sudo bash -s -- install-anywhere --yes
```

Use `install-vector` for Native Vector, or `install-legacy` for Nowhere v1.4.0.

## Updating Nowhere

Choose menu item `6`. The script shows the 10 latest releases, downloads the
selected binary, preserves `/etc/nowhere/nowhere.env`, and restarts the service.

```bash
sudo bash nowhere-vps.sh update
sudo bash nowhere-vps.sh update --version v1.5.1
```

When an update crosses the v1.5 protocol boundary, the script opens the
migration wizard because `spec` must be added or removed. Updates within the
same protocol generation do not rerun the configuration wizard.

Menu item `5` is for a full release install or switch and always opens the
configuration wizard.

## Client Selection

For v1.5+, the wizard asks:

```text
Client links anywhere/vector/both [anywhere]:
```

- `anywhere`: print `nowhere://` links for Anywhere 2.0.
- `vector`: print `vector://` URLs and native client commands.
- `both`: print both types. TCP pool is limited to `0..9` for Anywhere compatibility.

Anywhere 2.0 example:

```text
nowhere://shared-key@relay.example:2077?up=udp&down=udp#Nowhere%20VPS
```

Native Vector example:

```bash
nowhere 'vector://shared-key@relay.example:2077?up=udp&down=udp&sni=relay.example&pin=none&socks=127.0.0.1%3A1080'
```

## TLS

The default `tls=1` creates an in-memory self-signed certificate. Its SHA-256
fingerprint changes after every service restart. Display the current value with:

```bash
sudo bash nowhere-vps.sh fingerprint
```

For stable production deployments, use `tls=2` with PEM files:

```bash
sudo NOWHERE_PUBLIC_HOST=proxy.example.com \
  NOWHERE_PORT=443 \
  NOWHERE_TLS=2 \
  NOWHERE_CRT=/etc/letsencrypt/live/proxy.example.com/fullchain.pem \
  NOWHERE_TLS_KEY=/etc/letsencrypt/live/proxy.example.com/privkey.pem \
  bash nowhere-vps.sh install-anywhere --yes
```

Nowhere v1.5.1 Native Vector supports certificate pinning, but Anywhere 2.0 does
not currently parse a `pin` parameter in `nowhere://` links.

## Commands

```bash
sudo bash nowhere-vps.sh configure
sudo bash nowhere-vps.sh versions
sudo bash nowhere-vps.sh update
sudo bash nowhere-vps.sh start
sudo bash nowhere-vps.sh stop
sudo bash nowhere-vps.sh restart
sudo bash nowhere-vps.sh status
sudo bash nowhere-vps.sh logs
sudo bash nowhere-vps.sh link
sudo bash nowhere-vps.sh fingerprint
sudo bash nowhere-vps.sh uninstall
```

Important options:

| Environment variable | CLI option | Default | Description |
| --- | --- | --- | --- |
| `NOWHERE_VERSION` | `--version` | `v1.5.1` | Exact release tag |
| `NOWHERE_PROTOCOL` | `--protocol` | `modern` | `modern` for v1.5+, `legacy` for earlier releases |
| `NOWHERE_CLIENT` | `--client` | `anywhere` | `anywhere`, `vector`, or `both` |
| `NOWHERE_PUBLIC_HOST` | `--public-host` | auto | Public domain or IP |
| `NOWHERE_PORT` | `--port` | `2077` | Portal port |
| `NOWHERE_KEY` | `--key` | random | Shared key |
| `NOWHERE_SPEC` | `--spec` | random for legacy | Removed in v1.5+ |
| `NOWHERE_NET` | `--net` | `mix` | `mix`, `tcp`, or `udp` |
| `NOWHERE_TLS` | `--tls` | `1` | `1` self-signed, `2` PEM |
| `NOWHERE_POOL` | `--pool` | `5` | Anywhere `0..9`, Vector `0..256` |
| `NOWHERE_VECTOR_SOCKS` | `--vector-socks` | `127.0.0.1:1080` | Vector local SOCKS5 listener |
| `NOWHERE_VECTOR_SNI` | `--sni` | `none` | Vector TLS verification name |
| `NOWHERE_VECTOR_PIN` | `--pin` | `none` | v1.5.1+ lowercase certificate SHA-256 pin |

Run `bash nowhere-vps.sh --help` for the complete option list.

## Files

```text
/usr/local/bin/nowhere
/etc/nowhere/nowhere.env
/etc/systemd/system/nowhere.service
```

Uninstalling keeps `/etc/nowhere` so the shared key is not accidentally lost.
