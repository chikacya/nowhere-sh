# nowhere-sh

[简体中文](README.zh-CN.md)

An interactive deployment and management script for a Linux VPS running
[Nowhere](https://github.com/NodePassProject/Nowhere) Portal.

## Scope

This script installs `v2.1.1` by default and supports current releases from
`v2.0.0` onward. Release selection excludes V1 automatically. It generates
`nowhere://` links for Anywhere plus `vector://` URLs for the native Vector client.

## Features

- Interactive wizard: press Enter at every prompt for sensible defaults.
- Downloads a selected supported release and manages one systemd Portal service.
- Endpoint forms: shared TCP/UDP port, independent ports, TCP-only,
  UDP-only, and `tcp4`/`tcp6`/`udp4`/`udp6` address-family restrictions.
- Portal TLS modes, `morph`, rate limits, outbound SOCKS5, native `next` Portal
  chaining, Mux, SNI, certificate pinning, logs, TCP Morph prelude mode, and
  transport environment settings.
- Native Vector URL generation with fixed or `mix` routes, Mux, SNI, pin,
  rate limits, logs, and local SOCKS5 listener.
- Anywhere TCP and UDP import links, plus a terminal QR code for the preferred
  available carrier.
- Terminal UI, logs, service lifecycle commands, and TLS certificate SHA-256
  fingerprint output.

## Quick Start

Requirements: Linux, systemd, `curl`, `tar`, and an `x86_64` or `aarch64` VPS.

```bash
curl -fsSL https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh -o nowhere-vps.sh
chmod +x nowhere-vps.sh
sudo bash nowhere-vps.sh
```

On the first interactive run, choose English or Simplified Chinese. The choice
is saved and can later be changed from menu item `16`, or selected explicitly
with `--lang en` or `--lang zh`.

The default install enables both unrestricted TCP and UDP carriers on port
`2077`, creates an ephemeral self-signed certificate, and prints Anywhere
links. Open the same TCP and UDP port in both the VPS firewall and cloud security
group.

```text
1) Install/Reinstall (Anywhere)
2) Install/Reinstall (Native Vector)
3) Quick default install (Anywhere)
4) Reconfigure
5) Select a Release and install
6) Update Nowhere binary
7) Start service
8) Stop service
9) Restart service
10) Show status
11) Open Terminal UI
12) Follow logs
13) Print client links / QR code
14) Show certificate SHA-256
15) Uninstall
16) Switch language
17) Update deployment script
```

For non-interactive defaults:

```bash
curl -fsSL https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh | sudo bash -s -- install --yes
```

## Endpoints

The wizard accepts a TCP carrier (`tcp`, `tcp4`, `tcp6`, or `none`) and a UDP
carrier (`udp`, `udp4`, `udp6`, or `none`), each with its own port. Equivalent
CLI options are `--tcp-carrier`, `--tcp-port`, `--udp-carrier`, and
`--udp-port`.

When unrestricted TCP and UDP use one port, Portal uses the compact endpoint:

```text
portal://key@*:2077?tls=1&morph=0
```

Different ports produce an explicit endpoint:

```text
portal://key@*/tcp:443/udp:8443?tls=1&morph=1
```

`tcp4` and `udp6` restrict a carrier to IPv4 or IPv6. These advanced carrier
suffixes are retained in native Vector URLs. Anywhere links use ordinary TCP
and UDP routes.

## Portal Outbound Paths

Portal can connect to targets directly, through an outbound SOCKS5 proxy, or via
a native next-hop Portal. The wizard offers one of `direct`, `socks`, or `next`;
SOCKS and `next` are mutually exclusive.

Use `--next key@host:port` or an explicit carrier endpoint to configure a
next-hop Portal. Its route policy and TLS settings are available through
`--next-up`, `--next-down`, `--next-mux`, `--next-sni`, and `--next-pin`.

## Morph and Upgrades

`morph=0` is the default. With `morph=1`, Nowhere `v2.1.0` changes the Morph
wire format and cannot communicate with a `v2.0.x` Morph peer. Before upgrading
a Morph-enabled Portal from `v2.0.x` to `v2.1.0` or later, upgrade every
affected Anywhere client, native Vector node, and native `next` hop together.

The interactive update flow requires typing `UPGRADE` at this compatibility
boundary. Non-interactive automation is refused unless the coordinated rollout
has been completed and `--allow-morph-breaking-upgrade` is supplied.

Nowhere `v2.1.1` removes the `event` log level. When updating or reconfiguring
to `v2.1.1` or later, this script automatically changes a saved `event` level
to `info`; older selected releases continue to accept `event`.

For TCP Morph connections initiated by the local Nowhere process, choose the
client-side prelude mode with `--morph-tcp-prelude low7|full8`. `low7` is the
default and is appropriate for most deployments. This setting affects native
outbound connections such as `next`; it is not included in Anywhere import
links.

## Client Output

Anywhere links are generated separately for TCP and UDP, so they stay within
its supported fixed-route model. Native Vector supports the full policy set:

```bash
sudo bash nowhere-vps.sh install-vector \
  --vector-up mix --vector-down mix --mux 1
```

The Vector options are `--vector-up`, `--vector-down`, `--mux`,
`--vector-socks`, `--sni`, `--pin`, `--vector-rate`, `--vector-etar`, and
`--vector-log`. `mix` requires both carriers.

## TLS

The fingerprint command prints the SHA-256 fingerprint for the certificate
loaded by Portal, whether it is self-signed (`tls=1`) or supplied as PEM
(`tls=2`). It probes the live local TCP endpoint first and falls back to the
Nowhere log when probing is unavailable, so hot-reloaded PEM certificates are
reported correctly. A self-signed fingerprint changes after every service
restart; a PEM fingerprint changes when that certificate is renewed.

```bash
sudo bash nowhere-vps.sh fingerprint
```

For a supplied certificate use absolute paths:

```bash
sudo NOWHERE_TLS=2 \
  NOWHERE_CRT=/etc/letsencrypt/live/proxy.example.com/fullchain.pem \
  NOWHERE_TLS_KEY=/etc/letsencrypt/live/proxy.example.com/privkey.pem \
  NOWHERE_PUBLIC_HOST=proxy.example.com \
  bash nowhere-vps.sh install --yes
```

## Commands

```bash
sudo bash nowhere-vps.sh configure
sudo bash nowhere-vps.sh versions
sudo bash nowhere-vps.sh update
sudo bash nowhere-vps.sh update-script
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

Run `bash nowhere-vps.sh --help` for the complete option list.

## Files

```text
/usr/local/bin/nowhere
/etc/nowhere/nowhere.env
/etc/systemd/system/nowhere.service
```

Uninstalling keeps `/etc/nowhere` so configuration and keys are not removed by
accident.
