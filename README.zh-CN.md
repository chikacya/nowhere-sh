# nowhere-sh

[English](README.md)

[NodePassProject/Nowhere](https://github.com/NodePassProject/Nowhere) Portal
的 Linux VPS 一键部署与管理脚本。

## 支持范围

脚本默认安装 `v2.1.1`，支持 `v2.0.0` 及之后的当前 Release；指定版本列表会自动
排除 V1。脚本输出 Anywhere 的 `nowhere://` 链接和 Native Vector 的 `vector://` URL。

## 功能

- 交互式向导，每一项均有默认值，连续回车即可完成部署。
- 下载指定受支持 Release，并通过一个 systemd Portal 服务管理。
- 支持共享/独立 TCP、UDP 端口，TCP-only、UDP-only，以及
  `tcp4`、`tcp6`、`udp4`、`udp6` 地址族限制。
- 支持 Portal TLS、`morph`、TCP Morph 前导模式、限速、出站 SOCKS5、原生
  `next` Portal 链路、Mux、SNI、证书 Pin、日志与传输环境参数。
- 支持 Native Vector 固定路由或 `mix`、Mux、SNI、Pin、限速、日志和本地
  SOCKS5 监听。
- 输出 Anywhere 的 TCP、UDP 导入链接，并为优先可用链路生成终端二维码。
- 提供 Terminal UI、日志、服务启停与 TLS 证书 SHA-256 查询。

## 快速开始

系统需要 Linux、systemd、`curl`、`tar`，支持 `x86_64` 与 `aarch64` VPS。

```bash
curl -fsSL https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh -o nowhere-vps.sh
chmod +x nowhere-vps.sh
sudo bash nowhere-vps.sh
```

首次交互运行时可选择 English 或简体中文，选择会保存下来；之后可在菜单第 `16`
项切换，也可用 `--lang en` 或 `--lang zh` 显式指定语言。

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
14) 查看证书 SHA-256
15) 卸载服务
16) 切换语言
17) 更新部署脚本
```

非交互默认安装：

```bash
curl -fsSL https://raw.githubusercontent.com/NodePassProject/nowhere-sh/main/nowhere-vps.sh | sudo bash -s -- install --yes
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

## Morph 与升级

默认 `morph=0`。启用 `morph=1` 后，Nowhere `v2.1.0` 更改了 Morph 协议格式，
无法与 `v2.0.x` 的 Morph 对端通信。因此，将已启用 Morph 的 Portal 从 `v2.0.x`
升级到 `v2.1.0` 或更高版本前，需要同步升级受影响的 Anywhere 客户端、原生
Vector 节点和原生 `next` 跳板。

交互式更新在这个兼容性边界会要求输入 `UPGRADE` 才继续。非交互式自动化会被
拒绝；只有已完成协同升级时，才应额外传入
`--allow-morph-breaking-upgrade`。

Nowhere `v2.1.1` 移除了 `event` 日志级别。更新或重配到 `v2.1.1` 及之后版本时，
脚本会自动将已保存的 `event` 改为 `info`；选择较早版本时仍允许使用 `event`。

本机 Nowhere 进程主动发起的 TCP Morph 连接可用
`--morph-tcp-prelude low7|full8` 选择前导模式，默认 `low7`，大多数场景无需
调整。它影响原生 `next` 等出站连接，不会写入 Anywhere 导入链接。

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

指纹命令会输出 Portal 实际加载证书的 SHA-256，适用于自签证书（`tls=1`）和
PEM 证书（`tls=2`）。脚本优先探测本机 TCP 当前呈现的证书；探测不可用时再从
Nowhere 日志读取，因此 PEM 证书热重载后也能显示当前指纹。自签证书指纹每次重启
都会变化；PEM 证书指纹会在证书续期后变化：

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
