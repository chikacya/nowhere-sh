# nowhere-sh

[English](README.md)

[NodePassProject/Nowhere](https://github.com/NodePassProject/Nowhere) Portal 的
Linux VPS 一键部署和管理脚本。

## 功能

- 一步一步询问参数，每项都有默认值，一路回车即可完成安装。
- 安装指定 Release 到 `/usr/local/bin/nowhere`。
- 显示最近 10 个 GitHub Release，通过数字选择版本。
- 在同一大版本内单独更新 Nowhere 二进制，并保留现有配置。
- 自动创建和管理 systemd 服务。
- 支持 V1 的 `mix`、`tcp`、`udp`，以及 V2 独立 TCP/UDP carrier、TLS、限速、SOCKS5 上游和日志配置。
- 输出 Anywhere 2.0 / Anywhere TF 的 `nowhere://` 链接和 Native Vector 的 `vector://` URL。
- 提供 V1 原地升级至 V2：下载 V2 后备份 V1 配置，再切换 systemd 服务。
- 为推荐 Anywhere `nowhere://` 链接输出终端二维码。
- 可从管理菜单打开 Nowhere v1.6+ 的只读 Terminal UI。
- 输出 `tls=1` 临时自签证书的 SHA-256 fingerprint。

## 兼容性

本脚本保留 Nowhere V1.8 逻辑，并同时支持 Nowhere V2；稳定版默认安装
v1.8.3。V2 使用不兼容的 `nw2` 线缆协议，V1 客户端不能连接 V2 Portal，反之亦然。

| Portal 版本 | 客户端 | 链接 | 说明 |
| --- | --- | --- | --- |
| v1.8+ | Anywhere 2.0 | `nowhere://...` | 不含 `pool` 参数 |
| v1.8+ | Native Vector | `vector://...` | 本地 SOCKS5 客户端，支持 `mux=0|1` |
| v1.5-v1.7 | Anywhere 2.0 / Native Vector | 对应链接 | 指定旧 Release 时保留旧 `pool` |
| v2.0+ | Anywhere TF | `nowhere://...` | 固定 `nw2`，支持 TCP/UDP carrier 和 `morph` |
| v2.0+ | Native Vector | `vector://...` | V2 端点、`morph`、自适应 carrier 池（`mux=0`） |

同一个 v1.5+ Portal 可以根据需要输出 Anywhere 2.0 或 Native Vector 的客户端配置；
脚本不再提供 v1.5 以前版本。

## 快速安装

系统需要 Linux、systemd、`curl` 和 `tar`，支持 `x86_64` 与 `aarch64`。

```bash
curl -fsSL https://raw.githubusercontent.com/chikacya/nowhere-sh/main/nowhere-vps.sh -o nowhere-vps.sh
chmod +x nowhere-vps.sh
sudo bash nowhere-vps.sh
```

默认入口会安装 Nowhere v1.8.3，并输出 Anywhere 2.0 链接：

```text
1) 安装/重装（稳定版 Anywhere）
2) 安装/重装（V2 / Anywhere TF）
3) 从 V1 升级至 V2
4) 安装/重装（Native Vector）
5) 快速默认安装（稳定版 Anywhere）
6) 修改配置（向导）
7) 指定 Release 安装/重装
8) 更新 Nowhere 二进制（仅同一大版本）
9) 启动服务
10) 停止服务
11) 重启服务
12) 查看状态
13) 打开 Terminal UI（只读监控）
14) 查看日志
15) 打印客户端链接/命令
16) 查看 tls=1 自签证书 SHA-256
17) 卸载服务
0) 退出
```

非交互默认安装：

```bash
curl -fsSL https://raw.githubusercontent.com/chikacya/nowhere-sh/main/nowhere-vps.sh | sudo bash -s -- install-anywhere --yes
```

Native Vector 使用 `install-vector`。
全新部署 V2 / Anywhere TF 可使用 `install-v2`。

## 更新二进制

选择菜单 `8`，脚本会列出最近 10 个 Release。选择后只替换 Nowhere 二进制，
保留 `/etc/nowhere/nowhere.env`，然后重启服务。V1 与 V2 的配置和协议不兼容，
该入口会拒绝跨大版本更新。

```bash
sudo bash nowhere-vps.sh update
sudo bash nowhere-vps.sh update --version v1.8.3
```

菜单 `7` 是完整的指定版本安装/切换，会进入配置向导。

## 从 V1 升级至 V2

选择菜单 `3`，或运行：

```bash
sudo bash nowhere-vps.sh upgrade-v1-to-v2
```

向导会保留 V1 的 Shared Key、公网地址、监听地址、TLS 文件、限速和 SOCKS 设置。
脚本先下载 V2，再备份旧环境文件至
`/etc/nowhere/nowhere.env.v1.<timestamp>`，之后停止 V1 服务、写入 V2 配置并启动
同一个 systemd 服务。

只有所有客户端均支持 V2 时才应迁移。迁移后需要重新导入脚本打印的 V2 链接或二维码。

## Terminal UI

Nowhere v1.6.0 新增只读监控面板，可以查看 Portal/Vector 流量、连接、carrier、
连接池、CPU/RSS，以及独立的 Access 和 Runtime 日志。选择菜单 `13`，或者运行：

```bash
sudo bash nowhere-vps.sh tui
```

Portal 仍由 systemd 在后台运行；按 `q` 退出面板不会停止或修改服务。使用 root 运行
可以发现同一 Linux PID 和网络命名空间中由 root 启动的服务。容器内实例需要在同一
容器中打开 TUI 才能看到。

`NOW_TELEMETRY_INTERVAL` 独立控制遥测快照间隔，默认 `1s`，范围为
`250ms..60s`。

## 客户端选择

安装 v1.5+ 时，向导会询问：

```text
客户端链接 anywhere/vector/both [anywhere]:
```

- `anywhere`：输出 Anywhere 2.0 使用的 `nowhere://` 链接。
- `vector`：输出 `vector://` URL 和原生客户端命令。
- `both`：两种都输出。

Native Vector 使用 v1.8+ 时，向导会额外询问 TLS Mux：保留 `0` 为每条流使用
独立 TLS 连接，选择 `1` 则使用共享 TLS Mux Shard。此设置不影响 Anywhere 链接。

v1.8+ Portal 还可选择 QUIC 内存策略：默认 `balanced`；`memory` 偏向连接密度，
`throughput` 会提高高带宽、高延迟链路的流控窗口。

V1 Anywhere 2.0 示例：

```text
nowhere://shared-key@relay.example:2077?up=udp&down=udp#Nowhere%20VPS
```

V2 Anywhere TF 示例：

```text
nowhere://shared-key@relay.example:2077?up=tcp&down=tcp&morph=0&mux=0#Nowhere%20VPS
```

Native Vector 示例：

```bash
nowhere 'vector://shared-key@relay.example:2077?up=udp&down=udp&sni=relay.example&pin=none&socks=127.0.0.1%3A1080'
```

## TLS 与 SHA-256

默认 `tls=1` 使用内存自签证书，每次服务重启后证书和 fingerprint 都会变化：

```bash
sudo bash nowhere-vps.sh fingerprint
```

长期使用建议配置 `tls=2` 的稳定 PEM 证书：

```bash
sudo NOWHERE_PUBLIC_HOST=proxy.example.com \
  NOWHERE_PORT=443 \
  NOWHERE_TLS=2 \
  NOWHERE_CRT=/etc/letsencrypt/live/proxy.example.com/fullchain.pem \
  NOWHERE_TLS_KEY=/etc/letsencrypt/live/proxy.example.com/privkey.pem \
  bash nowhere-vps.sh install-anywhere --yes
```

Nowhere v1.5.1 的 Native Vector 支持证书 `pin`，但 Anywhere 2.0 当前不会解析
`nowhere://` 链接中的 `pin` 参数。

## 管理命令

```bash
sudo bash nowhere-vps.sh configure
sudo bash nowhere-vps.sh install-v2
sudo bash nowhere-vps.sh upgrade-v1-to-v2
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

主要参数：

| 环境变量 | 命令行参数 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `NOWHERE_VERSION` | `--version` | `v1.8.3` | V1 指定 Release；V2 入口默认 `v2.0.0` |
| `NOWHERE_CLIENT` | `--client` | `anywhere` | `anywhere`、`vector` 或 `both` |
| `NOWHERE_PUBLIC_HOST` | `--public-host` | 自动探测 | 公网域名或 IP |
| `NOWHERE_PORT` | `--port` | `2077` | Portal 端口 |
| `NOWHERE_TCP_PORT` | `--tcp-port` | V2: `NOWHERE_PORT` | V2 TCP carrier；留空关闭 |
| `NOWHERE_UDP_PORT` | `--udp-port` | V2: `NOWHERE_PORT` | V2 UDP carrier；留空关闭 |
| `NOWHERE_KEY` | `--key` | 随机 | Shared key |
| `NOWHERE_NET` | `--net` | `mix` | `mix`、`tcp` 或 `udp` |
| `NOWHERE_TLS` | `--tls` | `1` | `1` 自签，`2` PEM |
| `NOWHERE_POOL` | `--pool` | `5` | 仅 v1.5-v1.7 的旧 TCP pool |
| `NOWHERE_VECTOR_SOCKS` | `--vector-socks` | `127.0.0.1:1080` | Vector 本地 SOCKS5 入口 |
| `NOWHERE_VECTOR_SNI` | `--sni` | `none` | Vector TLS 校验名称 |
| `NOWHERE_VECTOR_PIN` | `--pin` | `none` | v1.5.1+ 小写证书 SHA-256 pin |
| `NOWHERE_VECTOR_MUX` | `--mux` | `0` | v1.8+ Vector TLS：`0` 独立连接，`1` 共享 Mux |
| `NOWHERE_QUIC_MEMORY_PROFILE` | `--quic-memory-profile` | `balanced` | v1.8+ Portal QUIC：`memory`、`balanced` 或 `throughput` |
| `NOWHERE_TRANSPORT_MEMORY_PROFILE` | `--transport-memory-profile` | `throughput` | V2 传输内存策略 |
| `NOWHERE_MORPH` | `--morph` | `0` | V2 ChaCha20 线缆变换，客户端与 Portal 必须一致 |
| `NOWHERE_MIX_FALLBACK_TIMEOUT` | `--mix-fallback-timeout` | `none` | V2 回退延迟，例如 `1s` |
| `NOWHERE_TELEMETRY_INTERVAL` / `NOW_TELEMETRY_INTERVAL` | `--telemetry-interval` | `1s` | v1.6+ TUI 快照间隔，`250ms..60s` |

完整参数请运行：

```bash
bash nowhere-vps.sh --help
```

## 文件位置

```text
/usr/local/bin/nowhere
/etc/nowhere/nowhere.env
/etc/systemd/system/nowhere.service
```

卸载时会保留 `/etc/nowhere`，避免误删 Shared Key。
