# nowhere-sh

[English](README.md)

[NodePassProject/Nowhere](https://github.com/NodePassProject/Nowhere) Portal 的
Linux VPS 一键部署和管理脚本。

## 功能

- 一步一步询问参数，每项都有默认值，一路回车即可完成安装。
- 安装指定 Release 到 `/usr/local/bin/nowhere`。
- 显示最近 10 个 GitHub Release，通过数字选择版本。
- 单独更新 Nowhere 二进制，并保留现有配置。
- 自动创建和管理 systemd 服务。
- 支持 `mix`、`tcp`、`udp`、TLS、限速、SOCKS5 上游和日志配置。
- 输出 Anywhere 2.0 的 `nowhere://` 链接和 Native Vector 的 `vector://` URL。
- 输出 `tls=1` 临时自签证书的 SHA-256 fingerprint。
- 保留 Nowhere v1.4 及更早版本的安装入口。

## 兼容性

Nowhere v1.5 更换了线协议并删除 `spec`，**Anywhere 2.0 已支持这个新版协议**。

| Portal 版本 | 客户端 | 链接 | 说明 |
| --- | --- | --- | --- |
| v1.5+ | Anywhere 2.0 | `nowhere://...` | 不含 `spec`，pool 为 `0..9` |
| v1.5+ | Native Vector | `vector://...` | 本地 SOCKS5 客户端，pool 为 `0..256` |
| v1.4 及更早 | Anywhere 1.x/兼容版本 | `nowhere://...` | 旧链接包含 `spec` |

服务端协议代际和客户端类型现在分开选择。同一个 v1.5+ Portal 可以根据需要输出
Anywhere 2.0 或 Native Vector 的客户端配置。

## 快速安装

系统需要 Linux、systemd、`curl` 和 `tar`，支持 `x86_64` 与 `aarch64`。

```bash
curl -fsSL https://raw.githubusercontent.com/chikacya/nowhere-sh/main/nowhere-vps.sh -o nowhere-vps.sh
chmod +x nowhere-vps.sh
sudo bash nowhere-vps.sh
```

默认入口会安装 Nowhere v1.5.1，并输出 Anywhere 2.0 链接：

```text
1) 安装/重装新版（Anywhere 2.0，v1.5.1）
2) 安装/重装新版（Native Vector，v1.5.1）
3) 快速默认安装（Anywhere 2.0，v1.5.1）
4) 修改当前协议模式配置（向导）
5) 指定 Release 安装/切换（最近 10 个版本）
6) 更新 Nowhere 二进制（保留当前配置）
7) 安装/重装旧版（Anywhere 1.x，v1.4.0）
8) 启动服务
9) 停止服务
10) 重启服务
11) 查看状态
12) 查看日志
13) 打印客户端链接/命令
14) 查看 tls=1 自签证书 SHA-256
15) 卸载服务
0) 退出
```

非交互默认安装：

```bash
curl -fsSL https://raw.githubusercontent.com/chikacya/nowhere-sh/main/nowhere-vps.sh | sudo bash -s -- install-anywhere --yes
```

Native Vector 使用 `install-vector`，旧版 v1.4.0 使用 `install-legacy`。

## 更新二进制

选择菜单 `6`，脚本会列出最近 10 个 Release。选择后只替换 Nowhere 二进制，
保留 `/etc/nowhere/nowhere.env`，然后重启服务。

```bash
sudo bash nowhere-vps.sh update
sudo bash nowhere-vps.sh update --version v1.5.1
```

如果升级或降级跨越 v1.5 协议边界，脚本会自动进入迁移向导，因为配置需要增加或
删除 `spec`。同一协议代际内更新不会重新询问全部参数。

菜单 `5` 是完整的指定版本安装/切换，会进入配置向导。

## 客户端选择

安装 v1.5+ 时，向导会询问：

```text
客户端链接 anywhere/vector/both [anywhere]:
```

- `anywhere`：输出 Anywhere 2.0 使用的 `nowhere://` 链接。
- `vector`：输出 `vector://` URL 和原生客户端命令。
- `both`：两种都输出；为了兼容 Anywhere，TCP pool 限制为 `0..9`。

Anywhere 2.0 示例：

```text
nowhere://shared-key@relay.example:2077?up=udp&down=udp#Nowhere%20VPS
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

主要参数：

| 环境变量 | 命令行参数 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `NOWHERE_VERSION` | `--version` | `v1.5.1` | 指定 Release |
| `NOWHERE_PROTOCOL` | `--protocol` | `modern` | v1.5+ 为 `modern`，更早为 `legacy` |
| `NOWHERE_CLIENT` | `--client` | `anywhere` | `anywhere`、`vector` 或 `both` |
| `NOWHERE_PUBLIC_HOST` | `--public-host` | 自动探测 | 公网域名或 IP |
| `NOWHERE_PORT` | `--port` | `2077` | Portal 端口 |
| `NOWHERE_KEY` | `--key` | 随机 | Shared key |
| `NOWHERE_SPEC` | `--spec` | 旧版随机 | v1.5+ 已删除 |
| `NOWHERE_NET` | `--net` | `mix` | `mix`、`tcp` 或 `udp` |
| `NOWHERE_TLS` | `--tls` | `1` | `1` 自签，`2` PEM |
| `NOWHERE_POOL` | `--pool` | `5` | Anywhere `0..9`，Vector `0..256` |
| `NOWHERE_VECTOR_SOCKS` | `--vector-socks` | `127.0.0.1:1080` | Vector 本地 SOCKS5 入口 |
| `NOWHERE_VECTOR_SNI` | `--sni` | `none` | Vector TLS 校验名称 |
| `NOWHERE_VECTOR_PIN` | `--pin` | `none` | v1.5.1+ 小写证书 SHA-256 pin |

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
