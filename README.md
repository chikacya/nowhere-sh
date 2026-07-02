# nowhere-sh

Nowhere Portal 的 Linux VPS 一键部署脚本，适合搭配 Anywhere 客户端使用。

脚本会自动下载 `NodePassProject/Nowhere` 最新 Linux release，安装二进制，生成
systemd 服务，并在安装完成后输出 `nowhere://` 导入链接和
`anywhere://add-proxy?link=...` 深链。

## 功能

- 自动识别 `x86_64` / `aarch64` 和 `gnu` / `musl` Linux 包。
- 安装 Nowhere 到 `/usr/local/bin/nowhere`。
- 配置文件保存到 `/etc/nowhere/nowhere.env`，权限为 `0600`。
- 创建并管理 systemd 服务 `/etc/systemd/system/nowhere.service`。
- 支持 `mix` / `tcp` / `udp` 监听模式。
- 支持 `tls=1` 自签临时证书和 `tls=2` PEM 证书。
- 支持速率限制、出站源地址、日志级别、Anywhere TCP pool。
- 支持 Nowhere `v1.2.4+` 的 `socks` 出站 SOCKS5 上游代理。

## 系统要求

- Linux VPS，使用 systemd。
- `curl`、`tar`。
- 推荐使用 Debian、Ubuntu、Rocky Linux、AlmaLinux、CentOS Stream 等常见发行版。

## 快速安装

推荐先下载脚本再执行：

```bash
curl -fsSL https://raw.githubusercontent.com/chikacya/nowhere-sh/main/nowhere-vps.sh -o nowhere-vps.sh
chmod +x nowhere-vps.sh
sudo bash nowhere-vps.sh
```

直接运行脚本会进入数字菜单：

```text
1) 安装/重装（向导，一路回车使用默认值）
2) 快速默认安装（不提问）
3) 修改配置（向导）
4) 更新 Nowhere 二进制
5) 启动服务
6) 停止服务
7) 重启服务
8) 查看状态
9) 查看日志
10) 打印 Anywhere 导入链接
11) 查看 tls=1 自签证书 SHA-256
12) 卸载服务
0) 退出
```

第一次使用建议选择 `1`，然后一路回车即可使用默认值完成安装。

也可以一行执行：

```bash
curl -fsSL https://raw.githubusercontent.com/chikacya/nowhere-sh/main/nowhere-vps.sh | sudo bash -s -- install
```

安装过程会询问端口、密钥、域名/IP、证书路径等参数。完成后，终端会打印 Anywhere 可导入的链接。

## 推荐部署方式

日常使用建议准备一个域名，并使用真实 TLS 证书：

```bash
sudo NOWHERE_PUBLIC_HOST=proxy.example.com \
  NOWHERE_PORT=443 \
  NOWHERE_NET=mix \
  NOWHERE_TLS=2 \
  NOWHERE_CRT=/etc/letsencrypt/live/proxy.example.com/fullchain.pem \
  NOWHERE_TLS_KEY=/etc/letsencrypt/live/proxy.example.com/privkey.pem \
  bash nowhere-vps.sh install --yes
```

如果只是临时测试，可以使用默认的 `tls=1`：

```bash
sudo bash nowhere-vps.sh install --yes
```

注意：`tls=1` 会在 Nowhere 启动时生成临时自签证书，重启后证书会变化。长期使用请改用 `tls=2`。

## 自签证书 SHA-256

默认 `tls=1` 会生成内存自签证书。脚本在安装、重启、更新后会自动尝试输出当前证书的 SHA-256 fingerprint：

```text
当前 tls=1 自签证书 SHA-256 fingerprint：
  AA:BB:CC:...
```

也可以随时手动查看：

```bash
sudo bash nowhere-vps.sh fingerprint
```

或者进入菜单选择 `11`。

因为 `tls=1` 的证书存在内存中，Nowhere 每次重启后 fingerprint 都会变化。生产环境仍建议使用 `tls=2` 配置稳定证书。

## 安装向导

选择菜单 `1` 或执行 `sudo bash nowhere-vps.sh install` 会进入交互向导。每一步都会显示默认值：

```text
公网域名/IP，用于 Anywhere 导入链接 [1.2.3.4]:
监听地址，留空表示 IPv4/IPv6 全部监听:
监听端口 [2077]:
Shared Key [随机值]:
Spec Seed [随机值]:
监听模式 mix/tcp/udp [mix]:
```

如果不想自定义，全部按回车即可。最后脚本会显示配置摘要，再次回车确认应用。

## 使用 SOCKS5 上游

如果希望 Nowhere Portal 的所有出站目标流量再经过一个 SOCKS5 代理，可以配置：

```bash
sudo NOWHERE_PUBLIC_HOST=proxy.example.com \
  NOWHERE_PORT=443 \
  NOWHERE_NET=mix \
  NOWHERE_TLS=2 \
  NOWHERE_CRT=/etc/letsencrypt/live/proxy.example.com/fullchain.pem \
  NOWHERE_TLS_KEY=/etc/letsencrypt/live/proxy.example.com/privkey.pem \
  NOWHERE_SOCKS=user:pass@127.0.0.1:1080 \
  bash nowhere-vps.sh install --yes
```

`NOWHERE_SOCKS` 支持：

```text
none
host:port
user:pass@host:port
[2001:db8::10]:1080
user:pass@[2001:db8::10]:1080
```

`NOWHERE_SOCKS` 是服务端出站设置，只写入 Portal URL，不会写入 Anywhere 客户端导入链接。Anywhere 仍然只连接你的 Nowhere Portal。

## 管理命令

```bash
sudo bash nowhere-vps.sh configure
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

常用命令说明：

- `configure`：重新配置参数并重启服务。
- `update`：下载最新 Nowhere release 并重启服务。
- `logs`：实时查看 systemd 日志。
- `link`：重新打印 Anywhere 导入链接。
- `fingerprint`：查看当前 `tls=1` 自签证书的 SHA-256 fingerprint。
- `uninstall`：删除二进制和 systemd 服务，但保留 `/etc/nowhere` 配置目录，避免误删密钥。

## 参数说明

所有参数既可以在交互模式中填写，也可以用环境变量或命令行参数传入。

| 环境变量 | 命令行参数 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `NOWHERE_PUBLIC_HOST` | `--public-host` | 自动探测 | Anywhere 导入链接中的域名或公网 IP |
| `NOWHERE_LISTEN_HOST` | `--listen-host` | 空 | 监听地址；空表示 IPv4/IPv6 wildcard |
| `NOWHERE_PORT` | `--port` | `2077` | Portal 监听端口 |
| `NOWHERE_KEY` | `--key` | 随机生成 | Nowhere shared key |
| `NOWHERE_SPEC` | `--spec` | 随机生成 | Nowhere spec seed |
| `NOWHERE_NET` | `--net` | `mix` | `mix`、`tcp`、`udp` |
| `NOWHERE_TLS` | `--tls` | `1` | `1` 自签临时证书，`2` PEM 证书 |
| `NOWHERE_CRT` | `--crt` | 空 | `tls=2` 的证书链路径 |
| `NOWHERE_TLS_KEY` | `--tls-key` | 空 | `tls=2` 的私钥路径 |
| `NOWHERE_ALPN` | `--alpn` | `now/1` | TLS/QUIC ALPN |
| `NOWHERE_RATE` | `--rate` | `0` | 客户端到目标方向 Mbps 限速，`0` 关闭 |
| `NOWHERE_ETAR` | `--etar` | `0` | 目标到客户端方向 Mbps 限速，`0` 关闭 |
| `NOWHERE_DIAL` | `--dial` | `auto` | 出站源 IP 或 `auto` |
| `NOWHERE_SOCKS` | `--socks` | `none` | SOCKS5 出站上游 |
| `NOWHERE_LOG` | `--log` | `info` | `none`、`debug`、`info`、`warn`、`error`、`event` |
| `NOWHERE_POOL` | `--pool` | `5` | Anywhere `net=tcp` 导入链接的 TCP pool 大小 |

## 防火墙

如果使用默认 `NOWHERE_NET=mix`，需要同时放行 TCP 和 UDP：

```bash
sudo ufw allow 443/tcp
sudo ufw allow 443/udp
```

firewalld 示例：

```bash
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=443/udp
sudo firewall-cmd --reload
```

如果 `NOWHERE_NET=tcp`，只需要开放 TCP。如果 `NOWHERE_NET=udp`，只需要开放 UDP。

## Anywhere 导入

安装完成后脚本会打印：

- `nowhere://...`
- `anywhere://add-proxy?link=...`

在 iPhone、iPad 或 Apple TV 上，可以复制 `nowhere://` 链接到 Anywhere 中导入；如果系统能识别 Anywhere deep link，也可以直接打开 `anywhere://add-proxy?link=...`。

如果忘记保存链接，在 VPS 上运行：

```bash
sudo bash nowhere-vps.sh link
```

## 配置文件位置

```text
/usr/local/bin/nowhere
/etc/nowhere/nowhere.env
/etc/systemd/system/nowhere.service
```

查看当前服务：

```bash
systemctl status nowhere
```

查看配置：

```bash
sudo cat /etc/nowhere/nowhere.env
```

## 故障排查

查看日志：

```bash
sudo bash nowhere-vps.sh logs
```

检查端口监听：

```bash
ss -lntup | grep nowhere
```

重启服务：

```bash
sudo bash nowhere-vps.sh restart
```

常见问题：

- 连不上：检查 VPS 安全组、防火墙、`NOWHERE_NET` 对应的 TCP/UDP 端口是否放行。
- 证书错误：生产环境建议使用 `tls=2`，并确认 `NOWHERE_PUBLIC_HOST` 与证书域名一致。
- QUIC 不通：很多云厂商安全组默认只放 TCP，记得额外放行 UDP。
- SOCKS5 不通：确认 `NOWHERE_SOCKS` 指向的代理在 VPS 上可达，认证信息正确。

## 上游项目

- Nowhere: https://github.com/NodePassProject/Nowhere
- Anywhere: https://github.com/NodePassProject/Anywhere
