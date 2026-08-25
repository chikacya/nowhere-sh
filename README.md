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
- Prints a terminal QR code for the recommended Anywhere `nowhere://` link.
- Opens the Nowhere v1.6+ read-only Terminal UI from the management menu.
- Prints the SHA-256 fingerprint of an ephemeral `tls=1` certificate.

## Compatibility

This script supports Nowhere v1.5 and later, which Anywhere 2.0 supports.
The default is Nowhere v1.8.0. It replaces the previous TCP `pool` setting with
optional Native Vector TLS Mux (`mux=0|1`).

| Portal release | Client | URL | Notes |
| --- | --- | --- | --- |
| v1.8+ | Anywhere 2.0 | `nowhere://...` | No `pool` parameter |
| v1.8+ | Native Vector | `vector://...` | Local SOCKS5 client; `mux=0|1` |
| v1.5-v1.7 | Anywhere 2.0 / Native Vector | matching URL | Legacy `pool` is retained for selected releases |

A v1.5+ Portal can serve Anywhere 2.0 or Native Vector clients using the
matching URL. Releases before v1.5 are intentionally not offered.

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

The default menu entry installs Nowhere v1.8.0 for Anywhere 2.0. Press Enter at
every wizard prompt to accept the defaults.

```text
1) Install/Reinstall (Anywhere)
2) Install/Reinstall (Native Vector)
3) Quick default install (Anywhere)
4) Reconfigure
5) Select and install a Release
6) Update Nowhere binary
7) Start service
8) Stop service
9) Restart service
10) Show status
11) Open read-only Terminal UI
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

Use `install-vector` for Native Vector.

## Updating Nowhere

Choose menu item `6`. The script shows the 10 latest releases, downloads the
selected binary, preserves `/etc/nowhere/nowhere.env`, and restarts the service.

```bash
sudo bash nowhere-vps.sh update
sudo bash nowhere-vps.sh update --version v1.8.0
```

Menu item `5` is for a full release install or switch and always opens the
configuration wizard.

## Terminal UI

Nowhere v1.6.0 provides a read-only dashboard for Portal and Vector traffic,
connections, carriers, pools, CPU/RSS, and separate Access and Runtime logs.
Open it from menu item `11` or run:

```bash
sudo bash nowhere-vps.sh tui
```

The Portal continues running under systemd. Closing the dashboard with `q` does
not stop or reconfigure it. Run the dashboard as root to discover the root-owned
systemd service in the same Linux PID and network namespaces. Containers remain
isolated unless the dashboard runs inside the same container.

`NOW_TELEMETRY_INTERVAL` controls snapshots independently of text logs. The
script default is `1s`; accepted values range from `250ms` to `60s`.

## Client Selection

For v1.5+, the wizard asks:

```text
Client links anywhere/vector/both [anywhere]:
```

- `anywhere`: print `nowhere://` links for Anywhere 2.0.
- `vector`: print `vector://` URLs and native client commands.
- `both`: print both types.

For Native Vector on v1.8+, the wizard also asks for TLS Mux. Keep `0` for
dedicated TLS lanes, or select `1` to use shared TLS Mux Shards. This setting
does not apply to Anywhere links.

For v1.8+ Portal deployments, choose a QUIC memory profile: `balanced` is the
default, `memory` favors connection density, and `throughput` raises flow-control
windows for high-bandwidth, high-latency links.

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
sudo bash nowhere-vps.sh tui
sudo bash nowhere-vps.sh logs
sudo bash nowhere-vps.sh link
sudo bash nowhere-vps.sh fingerprint
sudo bash nowhere-vps.sh uninstall
```

Important options:

| Environment variable | CLI option | Default | Description |
| --- | --- | --- | --- |
| `NOWHERE_VERSION` | `--version` | `v1.8.0` | Exact release tag |
| `NOWHERE_CLIENT` | `--client` | `anywhere` | `anywhere`, `vector`, or `both` |
| `NOWHERE_PUBLIC_HOST` | `--public-host` | auto | Public domain or IP |
| `NOWHERE_PORT` | `--port` | `2077` | Portal port |
| `NOWHERE_KEY` | `--key` | random | Shared key |
| `NOWHERE_NET` | `--net` | `mix` | `mix`, `tcp`, or `udp` |
| `NOWHERE_TLS` | `--tls` | `1` | `1` self-signed, `2` PEM |
| `NOWHERE_POOL` | `--pool` | `5` | v1.5-v1.7 legacy TCP pool only |
| `NOWHERE_VECTOR_SOCKS` | `--vector-socks` | `127.0.0.1:1080` | Vector local SOCKS5 listener |
| `NOWHERE_VECTOR_SNI` | `--sni` | `none` | Vector TLS verification name |
| `NOWHERE_VECTOR_PIN` | `--pin` | `none` | v1.5.1+ lowercase certificate SHA-256 pin |
| `NOWHERE_VECTOR_MUX` | `--mux` | `0` | v1.8+ Vector TLS: `0` dedicated, `1` shared Mux |
| `NOWHERE_QUIC_MEMORY_PROFILE` | `--quic-memory-profile` | `balanced` | v1.8+ Portal QUIC: `memory`, `balanced`, or `throughput` |
| `NOWHERE_TELEMETRY_INTERVAL` / `NOW_TELEMETRY_INTERVAL` | `--telemetry-interval` | `1s` | v1.6+ TUI snapshot interval, `250ms..60s` |

Run `bash nowhere-vps.sh --help` for the complete option list.

## Files

```text
/usr/local/bin/nowhere
/etc/nowhere/nowhere.env
/etc/systemd/system/nowhere.service
```

Uninstalling keeps `/etc/nowhere` so the shared key is not accidentally lost.
