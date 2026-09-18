# nowhere-sh

[English](README.md)

[NodePassProject/Nowhere](https://github.com/NodePassProject/Nowhere) Portal
的 Linux VPS 一键部署与管理脚本。

## 支持范围

脚本默认安装 `v2.0.0`，支持 `v2.0.0` 及之后的当前 Release；指定版本列表会自动
排除 V1。脚本输出 Anywhere 的 `nowhere://` 链接和 Native Vector 的 `vector://` URL。

## 功能

- 交互式向导，每一项均有默认值，连续回车即可完成部署。
- 下载指定受支持 Release，并通过一个 systemd Portal 服务管理。
- 支持共享/独立 TCP、UDP 端口，TCP-only、UDP-only，以及
  `tcp4`、`tcp6`、`udp4`、`udp6` 地址族限制。
- 支持 Portal TLS、`morph`、限速、出站 SOCKS5、原生 `next` Portal 链路、
  Mux、SNI、证书 Pin、日志与传输环境参数。
- 支持 Native Vector 固定路由或 `mix`、Mux、SNI、Pin、限速、日志和本地
  SOCKS5 监听。
- 输出 Anywhere 的 TCP、UDP 导入链接，并为优先可用链路生成终端二维码。
- 提供 Terminal UI、日志、服务启停与 `tls=1` 自签证书 SHA-256 查询。

## 快速开始

系统需要 Linux、systemd、`curl`、`tar`，支持 `x86_64` 与 `aarch64` VPS。

```bash
curl -fsSL https://raw.githubusercontent.com/chikacya/nowhere-sh/main/nowhere-vps.sh -o nowhere-vps.sh
chmod +x nowhere-vps.sh
sudo bash nowhere-vps.sh
```

默认安装会在 `2077` 同时启用无限制 TCP 和 UDP carrier，使用临时自签证书，
并输出 Anywhere 链接。VPS 防火墙与云厂商安全组均需放行同一个 TCP、UDP 端口。

```text
1) 安装/重装（Anywhere）
2) 安装/重装（Native Vector）
3) 快速默认安装（Anywhere）
4) 修改配置
5) 指定 Release 安装
6) 更新 Nowhere 二进制
7) 启动服务
8) 停止服务
9) 重启服务
10) 查看状态
11) 打开 Terminal UI
12) 查看日志
13) 打印客户端链接 / 二维码
14) 查看 tls=1 证书 SHA-256
15) 卸载服务
```

非交互默认安装：

```bash
curl -fsSL https://raw.githubusercontent.com/chikacya/nowhere-sh/main/nowhere-vps.sh | sudo bash -s -- install --yes
```

## Carrier

向导分别配置 TCP carrier（`tcp`、`tcp4`、`tcp6` 或 `none`）和 UDP carrier
（`udp`、`udp4`、`udp6` 或 `none`），两个 carrier 可以使用独立端口。命令行参数为
`--tcp-carrier`、`--tcp-port`、`--udp-carrier`、`--udp-port`。

不限地址族的 TCP、UDP 共用一个端口时，会生成紧凑端点：

```text
portal://key@*:2077?tls=1&morph=0
```

分别使用端口时，会生成显式端点：

```text
portal://key@*/tcp:443/udp:8443?tls=1&morph=1
```

`tcp4`、`udp6` 用于把对应 carrier 限制为 IPv4 或 IPv6。Native Vector URL 会保留
这些高级限制；Anywhere 链接使用普通 TCP、UDP 固定路由。

## Portal 出站路径

Portal 可直连目标、经由出站 SOCKS5，或连接下一个原生 Portal。向导中选择
`direct`、`socks`、`next` 之一；SOCKS 与 `next` 不能同时使用。

使用 `--next key@host:port` 或显式 carrier 端点配置下一跳 Portal；其路由和 TLS
参数分别为 `--next-up`、`--next-down`、`--next-mux`、`--next-sni`、`--next-pin`。

## 客户端链接

Anywhere 会分别生成 TCP 与 UDP 链接，保持在其支持的固定路由范围内。Native
Vector 支持完整路由策略，例如：

```bash
sudo bash nowhere-vps.sh install-vector \
  --vector-up mix --vector-down mix --mux 1
```

Vector 相关参数是 `--vector-up`、`--vector-down`、`--mux`、`--vector-socks`、
`--sni`、`--pin`、`--vector-rate`、`--vector-etar`、`--vector-log`。使用 `mix`
必须同时启用 TCP 与 UDP carrier。

## TLS

默认 `tls=1` 使用内存自签证书；每次服务重启后 fingerprint 都会变化：

```bash
sudo bash nowhere-vps.sh fingerprint
```

使用自有 PEM 证书时填写绝对路径：

```bash
sudo NOWHERE_TLS=2 \
  NOWHERE_CRT=/etc/letsencrypt/live/proxy.example.com/fullchain.pem \
  NOWHERE_TLS_KEY=/etc/letsencrypt/live/proxy.example.com/privkey.pem \
  NOWHERE_PUBLIC_HOST=proxy.example.com \
  bash nowhere-vps.sh install --yes
```

## 管理命令

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

完整参数请执行：

```bash
bash nowhere-vps.sh --help
```

## 文件位置

```text
/usr/local/bin/nowhere
/etc/nowhere/nowhere.env
/etc/systemd/system/nowhere.service
```

卸载会保留 `/etc/nowhere`，避免误删配置与 Shared Key。
