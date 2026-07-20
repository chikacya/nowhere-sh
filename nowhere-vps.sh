#!/usr/bin/env bash
set -euo pipefail

REPO="NodePassProject/Nowhere"
SERVICE_NAME="nowhere"
BIN_PATH="/usr/local/bin/nowhere"
CONFIG_DIR="/etc/nowhere"
CONFIG_FILE="${CONFIG_DIR}/nowhere.env"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

DEFAULT_PORT="2077"
DEFAULT_NET="mix"
DEFAULT_ALPN="now/1"
DEFAULT_LOG="info"
DEFAULT_POOL="5"
DEFAULT_SOCKS="none"
DEFAULT_PROTOCOL="modern"
DEFAULT_CLIENT="anywhere"
DEFAULT_LEGACY_VERSION="v1.4.0"
DEFAULT_MODERN_VERSION="v1.5.1"
DEFAULT_VECTOR_VERSION="$DEFAULT_MODERN_VERSION"
DEFAULT_VECTOR_SOCKS="127.0.0.1:1080"
DEFAULT_VECTOR_SNI="none"
DEFAULT_VECTOR_PIN="none"

ASSUME_YES=0
VERSION_EXPLICIT=0
ACTION="${1:-menu}"
if [[ $# -gt 0 ]]; then
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      ASSUME_YES=1
      shift
      ;;
    --port)
      NOWHERE_PORT="${2:?missing --port value}"
      shift 2
      ;;
    --key)
      NOWHERE_KEY="${2:?missing --key value}"
      shift 2
      ;;
    --spec)
      NOWHERE_SPEC="${2:?missing --spec value}"
      shift 2
      ;;
    --protocol)
      NOWHERE_PROTOCOL="${2:?missing --protocol value}"
      shift 2
      ;;
    --client)
      NOWHERE_CLIENT="${2:?missing --client value}"
      shift 2
      ;;
    --version)
      NOWHERE_VERSION="${2:?missing --version value}"
      VERSION_EXPLICIT=1
      shift 2
      ;;
    --net)
      NOWHERE_NET="${2:?missing --net value}"
      shift 2
      ;;
    --tls)
      NOWHERE_TLS="${2:?missing --tls value}"
      shift 2
      ;;
    --crt|--cert)
      NOWHERE_CRT="${2:?missing --crt value}"
      shift 2
      ;;
    --tls-key)
      NOWHERE_TLS_KEY="${2:?missing --tls-key value}"
      shift 2
      ;;
    --public-host)
      NOWHERE_PUBLIC_HOST="${2:?missing --public-host value}"
      shift 2
      ;;
    --listen-host)
      NOWHERE_LISTEN_HOST="${2:?missing --listen-host value}"
      shift 2
      ;;
    --alpn)
      NOWHERE_ALPN="${2:?missing --alpn value}"
      shift 2
      ;;
    --rate)
      NOWHERE_RATE="${2:?missing --rate value}"
      shift 2
      ;;
    --etar)
      NOWHERE_ETAR="${2:?missing --etar value}"
      shift 2
      ;;
    --dial)
      NOWHERE_DIAL="${2:?missing --dial value}"
      shift 2
      ;;
    --socks)
      NOWHERE_SOCKS="${2:?missing --socks value}"
      shift 2
      ;;
    --log)
      NOWHERE_LOG="${2:?missing --log value}"
      shift 2
      ;;
    --pool)
      NOWHERE_POOL="${2:?missing --pool value}"
      shift 2
      ;;
    --vector-socks)
      NOWHERE_VECTOR_SOCKS="${2:?missing --vector-socks value}"
      shift 2
      ;;
    --sni)
      NOWHERE_VECTOR_SNI="${2:?missing --sni value}"
      shift 2
      ;;
    --pin)
      NOWHERE_VECTOR_PIN="${2:?missing --pin value}"
      shift 2
      ;;
    -h|--help)
      ACTION="help"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

info() { printf '\033[1;34m[Nowhere]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[Warn]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[Error]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Nowhere VPS 一键部署脚本。

Usage:
  sudo bash nowhere-vps.sh
  sudo bash nowhere-vps.sh install|install-anywhere|install-legacy [--yes] [options]
  sudo bash nowhere-vps.sh install-vector [--yes] [options]
  sudo bash nowhere-vps.sh configure [options]
  sudo bash nowhere-vps.sh update [--version v1.5.1]
  sudo bash nowhere-vps.sh versions
  sudo bash nowhere-vps.sh start|stop|restart|status|logs|link
  sudo bash nowhere-vps.sh fingerprint
  sudo bash nowhere-vps.sh uninstall

No arguments opens the interactive menu. Press Enter in the installer wizard to
keep every default value.

Options:
  --protocol legacy|modern  Server protocol generation; selected automatically by version
  --client anywhere|vector|both  Client links to print for v1.5+
  --version v1.5.1         Exact GitHub Release version to install
  --port 2077              Portal listen port
  --key secret             Shared key
  --spec nightfall         Optional protocol spec seed
  --net mix|tcp|udp        Server listener transport
  --tls 1|2                1=self-signed, 2=PEM certificate
  --crt /path/cert.pem     PEM certificate chain for tls=2
  --tls-key /path/key.pem  PEM private key for tls=2
  --public-host host       Domain/IP used in generated client URLs
  --listen-host host       Bind host; empty means IPv4 and IPv6 wildcard
  --alpn now/1             TLS/QUIC ALPN
  --rate 0                 Client-to-target limit in Mbps, 0 disables
  --etar 0                 Target-to-client limit in Mbps, 0 disables
  --dial auto              Outbound source IP or auto
  --socks none             SOCKS5 outbound proxy: host:port or user:pass@host:port
  --log info               none|debug|info|warn|error|event
  --pool 5                 TCP pool: Anywhere 0..9, Native Vector 0..256
  --vector-socks addr      Native Vector local SOCKS5 listener
  --sni name|none          Native Vector certificate verification name
  --pin sha256|none        Native Vector lowercase leaf certificate SHA-256 pin

Environment variables with the same names are also supported, for example:
  NOWHERE_PORT=443 NOWHERE_NET=mix sudo -E bash nowhere-vps.sh install-anywhere --yes
EOF
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "请使用 root 运行，例如：sudo bash $0 ${ACTION}"
}

require_systemd() {
  command -v systemctl >/dev/null 2>&1 || die "当前系统缺少 systemctl，暂不支持此 VPS。"
  [[ -d /run/systemd/system ]] || warn "systemd 看起来未运行，服务管理命令可能失败。"
}

env_quote() {
  local value="${1//$'\n'/}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

urlencode() {
  local input="${1:-}"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$input"
  elif command -v python >/dev/null 2>&1; then
    python -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$input"
  elif [[ "$input" =~ ^[A-Za-z0-9._~-]*$ ]]; then
    printf '%s\n' "$input"
  else
    die "python3 is required to percent-encode values containing reserved URL characters."
  fi
}

format_host_for_url() {
  local host="${1:-}"
  if [[ -z "$host" ]]; then
    printf ''
  elif [[ "$host" == \[*\] ]]; then
    printf '%s' "$host"
  elif [[ "$host" == *:* ]]; then
    printf '[%s]' "$host"
  else
    printf '%s' "$host"
  fi
}

display_socks() {
  local socks="${1:-none}"
  if [[ -z "$socks" || "$socks" == "none" ]]; then
    printf 'none'
  elif [[ "$socks" == *@* ]]; then
    printf '***@%s' "${socks##*@}"
  else
    printf '%s' "$socks"
  fi
}

strip_brackets() {
  local host="${1:-}"
  host="${host#[}"
  host="${host%]}"
  printf '%s' "$host"
}

display_empty() {
  local value="${1:-}"
  local fallback="${2:-<空>}"
  if [[ -z "$value" ]]; then
    printf '%s' "$fallback"
  else
    printf '%s' "$value"
  fi
}

local_tls_probe_host() {
  local host="${NOWHERE_LISTEN_HOST_VALUE:-}"
  if [[ -z "$host" || "$host" == "0.0.0.0" || "$host" == "::" || "$host" == "[::]" ]]; then
    printf '127.0.0.1'
  else
    strip_brackets "$host"
  fi
}

print_tls_fingerprint_from_tcp() {
  command -v openssl >/dev/null 2>&1 || return 1
  command -v timeout >/dev/null 2>&1 || return 1
  [[ "${NOWHERE_NET_VALUE:-mix}" != "udp" ]] || return 1
  [[ -n "${NOWHERE_PORT_VALUE:-}" ]] || return 1

  local connect_host sni output fingerprint
  connect_host="$(local_tls_probe_host)"
  sni="${NOWHERE_PUBLIC_HOST_VALUE:-localhost}"
  for _ in 1 2 3 4 5; do
    output="$(
      timeout 8 openssl s_client \
        -connect "${connect_host}:${NOWHERE_PORT_VALUE}" \
        -servername "$sni" \
        -showcerts </dev/null 2>/dev/null |
        openssl x509 -noout -fingerprint -sha256 2>/dev/null || true
    )"
    fingerprint="${output#*=}"
    if [[ -n "$fingerprint" && "$fingerprint" != "$output" ]]; then
      printf '%s\n' "$fingerprint"
      return 0
    fi
    sleep 1
  done
  return 1
}

print_tls_fingerprint_from_logs() {
  command -v journalctl >/dev/null 2>&1 || return 1
  local line fingerprint

  line="$(
    journalctl -u "$SERVICE_NAME" -n 300 --no-pager 2>/dev/null |
      grep -Eai 'CERT_SHA256\|' |
      tail -n 1 || true
  )"
  if [[ -n "$line" ]]; then
    fingerprint="$(
      printf '%s\n' "$line" |
        sed -nE 's/.*CERT_SHA256\|([A-Fa-f0-9]{64}).*/\1/p' |
        tail -n 1
    )"
    [[ -n "$fingerprint" ]] && {
      printf '%s\n' "$fingerprint"
      return 0
    }
  fi

  line="$(
    journalctl -u "$SERVICE_NAME" -n 300 --no-pager 2>/dev/null |
      grep -Eai 'fingerprint|sha-?256' |
      tail -n 1 || true
  )"
  [[ -n "$line" ]] || return 1
  fingerprint="$(
    printf '%s\n' "$line" |
      grep -Eaio '([A-Fa-f0-9]{2}:){31}[A-Fa-f0-9]{2}|[A-Fa-f0-9]{64}' |
      tail -n 1 || true
  )"
  [[ -n "$fingerprint" ]] || {
    printf '%s\n' "$line"
    return 0
  }
  printf '%s\n' "$fingerprint"
}

print_tls_fingerprint() {
  require_root
  load_config
  if [[ "${NOWHERE_TLS_VALUE:-1}" != "1" ]]; then
    echo
    echo "当前配置不是 tls=1 自签模式，无需使用自签证书 fingerprint。"
    echo "tls=2 请使用系统证书链校验，或在证书变更后按客户端需要重新固定证书。"
    return 0
  fi

  echo
  echo "当前 tls=1 自签证书 SHA-256 fingerprint："
  local fingerprint
  if fingerprint="$(print_tls_fingerprint_from_logs)"; then
    echo "  ${fingerprint}"
    echo
    echo "提示：tls=1 证书存在内存中，Nowhere 每次重启后 fingerprint 都会变化。"
    return 0
  fi
  if fingerprint="$(print_tls_fingerprint_from_tcp)"; then
    echo "  ${fingerprint}"
    echo
    echo "提示：tls=1 证书存在内存中，Nowhere 每次重启后 fingerprint 都会变化。"
    return 0
  fi

  warn "暂时没有获取到 fingerprint。请确认服务已启动，并且 net 不是 udp-only；也可以查看：journalctl -u ${SERVICE_NAME} -n 100"
}

mask_secret() {
  local value="${1:-}"
  local length="${#value}"
  if [[ "$length" -le 8 ]]; then
    printf '***'
  else
    printf '%s...%s' "${value:0:4}" "${value: -4}"
  fi
}

confirm_default_yes() {
  local prompt="$1"
  local answer
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  read -r -p "${prompt} [Y/n]: " answer
  [[ -z "$answer" || "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]
}

print_config_summary() {
  echo
  echo "配置确认："
  echo "  协议模式:          $(protocol_label "${NOWHERE_PROTOCOL:-legacy}")"
  echo "  客户端输出:        $(client_label "${NOWHERE_CLIENT:-anywhere}")"
  echo "  Release:           ${NOWHERE_VERSION:-}"
  echo "  公网域名/IP:       $(display_empty "${NOWHERE_PUBLIC_HOST:-}" "<自动探测失败，稍后可重新配置>")"
  echo "  监听地址:          $(display_empty "${NOWHERE_LISTEN_HOST:-}" "<空，IPv4/IPv6 wildcard>")"
  echo "  监听端口:          ${NOWHERE_PORT:-}"
  echo "  Shared Key:        $(mask_secret "${NOWHERE_KEY:-}")"
  if [[ "${NOWHERE_PROTOCOL:-legacy}" == "legacy" ]]; then
    echo "  Spec:              $(mask_secret "${NOWHERE_SPEC:-}")"
  fi
  echo "  Net:               ${NOWHERE_NET:-}"
  echo "  TLS:               ${NOWHERE_TLS:-}"
  if [[ "${NOWHERE_TLS:-}" == "2" ]]; then
    echo "  证书链:            ${NOWHERE_CRT:-}"
    echo "  私钥:              ${NOWHERE_TLS_KEY:-}"
  fi
  echo "  ALPN:              ${NOWHERE_ALPN:-}"
  echo "  Rate / Etar:       ${NOWHERE_RATE:-0} / ${NOWHERE_ETAR:-0} Mbps"
  echo "  Dial:              ${NOWHERE_DIAL:-auto}"
  echo "  SOCKS5 出站:       $(display_socks "${NOWHERE_SOCKS:-none}")"
  echo "  Log:               ${NOWHERE_LOG:-}"
  echo "  TCP Pool:          ${NOWHERE_POOL:-}"
  if [[ "${NOWHERE_CLIENT:-anywhere}" == "vector" || "${NOWHERE_CLIENT:-anywhere}" == "both" ]]; then
    echo "  Vector SOCKS5:     ${NOWHERE_VECTOR_SOCKS:-}"
    echo "  Vector SNI:        ${NOWHERE_VECTOR_SNI:-none}"
    echo "  Vector Pin:        ${NOWHERE_VECTOR_PIN:-none}"
  fi
}

random_token() {
  local bytes="${1:-24}"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 "$bytes" | tr '+/' '-_' | tr -d '='
  else
    LC_ALL=C tr -dc 'A-Za-z0-9._~-' </dev/urandom | head -c $((bytes * 2))
    printf '\n'
  fi
}

detect_public_host() {
  local detected=""
  if command -v curl >/dev/null 2>&1; then
    detected="$(curl -4fsS --max-time 4 https://api.ipify.org 2>/dev/null || true)"
  fi
  if [[ -z "$detected" ]]; then
    detected="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  fi
  printf '%s' "$detected"
}

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  fi
}

read_value() {
  local prompt="$1"
  local default="$2"
  local var
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    printf '%s' "$default"
    return
  fi
  if [[ -n "$default" ]]; then
    read -r -p "${prompt} [${default}]: " var
    printf '%s' "${var:-$default}"
  else
    read -r -p "${prompt}: " var
    printf '%s' "$var"
  fi
}

normalize_protocol() {
  case "${1:-}" in
    legacy|anywhere) printf 'legacy' ;;
    vector|v15|modern) printf 'modern' ;;
    *) return 1 ;;
  esac
}

normalize_client() {
  case "${1:-}" in
    anywhere) printf 'anywhere' ;;
    vector) printf 'vector' ;;
    both) printf 'both' ;;
    *) return 1 ;;
  esac
}

client_label() {
  case "${1:-anywhere}" in
    anywhere) printf 'Anywhere 2.0' ;;
    vector) printf 'Native Vector' ;;
    both) printf 'Anywhere 2.0 + Native Vector' ;;
  esac
}

protocol_label() {
  if [[ "${1:-legacy}" == "modern" ]]; then
    printf 'Nowhere v1.5+ protocol'
  else
    printf 'Legacy protocol (v1.4 and earlier)'
  fi
}

validate_release_version() {
  [[ "${1:-}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9._-]+)?$ ]]
}

version_at_least() {
  local version="${1#v}" required_major="$2" required_minor="$3" required_patch="$4"
  local major minor patch
  version="${version%%-*}"
  IFS=. read -r major minor patch <<<"$version"
  [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ && "$patch" =~ ^[0-9]+$ ]] || return 1
  (( 10#$major > required_major )) && return 0
  (( 10#$major < required_major )) && return 1
  (( 10#$minor > required_minor )) && return 0
  (( 10#$minor < required_minor )) && return 1
  (( 10#$patch >= required_patch ))
}

protocol_for_version() {
  if version_at_least "$1" 1 5 0; then
    printf 'modern'
  else
    printf 'legacy'
  fi
}

default_version_for_protocol() {
  if [[ "${1:-legacy}" == "modern" ]]; then
    printf '%s' "$DEFAULT_MODERN_VERSION"
  else
    printf '%s' "$DEFAULT_LEGACY_VERSION"
  fi
}

validate_version_protocol() {
  local expected
  validate_release_version "$NOWHERE_VERSION" || die "Invalid release version: ${NOWHERE_VERSION}"
  expected="$(protocol_for_version "$NOWHERE_VERSION")"
  [[ "$NOWHERE_PROTOCOL" == "$expected" ]] || die "${NOWHERE_VERSION} requires protocol=${expected}; current selection is ${NOWHERE_PROTOCOL}."
}

fetch_recent_releases() {
  local api="https://api.github.com/repos/${REPO}/releases?per_page=10"
  if command -v python3 >/dev/null 2>&1; then
    curl -fsSL -H 'Accept: application/vnd.github+json' "$api" |
      python3 -c 'import json,sys; [print(item["tag_name"]) for item in json.load(sys.stdin)[:10]]'
  elif command -v python >/dev/null 2>&1; then
    curl -fsSL -H 'Accept: application/vnd.github+json' "$api" |
      python -c 'import json,sys; [sys.stdout.write(item["tag_name"] + "\n") for item in json.load(sys.stdin)[:10]]'
  else
    curl -fsSL -H 'Accept: application/vnd.github+json' "$api" |
      sed -nE 's/^[[:space:]]*"tag_name":[[:space:]]*"([^"]+)".*/\1/p' |
      head -n 10
  fi
}

choose_release_version() {
  local releases=() choice index release mode choice_number
  command -v curl >/dev/null 2>&1 || die "curl is required to query GitHub Releases."
  while IFS= read -r release; do
    [[ -n "$release" ]] && releases+=("$release")
  done < <(fetch_recent_releases)
  [[ "${#releases[@]}" -gt 0 ]] || die "Could not read recent releases from GitHub."

  echo
  echo "最近 ${#releases[@]} 个 Nowhere Release："
  for index in "${!releases[@]}"; do
    release="${releases[$index]}"
    mode="$(protocol_for_version "$release")"
    printf ' %2d) %-12s %s\n' "$((index + 1))" "$release" "$(protocol_label "$mode")"
  done
  echo "  0) 取消"

  while true; do
    read -r -p "请选择要安装的版本: " choice
    if [[ "$choice" == "0" ]]; then
      return 1
    fi
    if [[ "$choice" =~ ^[0-9]+$ && "${#choice}" -le 2 ]]; then
      choice_number=$((10#$choice))
      if (( choice_number >= 1 && choice_number <= ${#releases[@]} )); then
        SELECTED_VERSION="${releases[$((choice_number - 1))]}"
        return 0
      fi
    fi
    warn "请输入 0..${#releases[@]}。"
  done
}

validate_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -ge 1 ]] && [[ "$1" -le 65535 ]]
}

validate_nonnegative_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

validate_socks() {
  local socks="$1"
  local endpoint userinfo host port

  [[ -z "$socks" || "$socks" == "none" ]] && return 0
  [[ "$socks" != *[[:space:]]* ]] || return 1

  endpoint="$socks"
  if [[ "$endpoint" == *@* ]]; then
    userinfo="${endpoint%@*}"
    endpoint="${endpoint##*@}"
    [[ "$userinfo" == *:* ]] || return 1
    [[ -n "${userinfo%%:*}" && -n "${userinfo#*:}" ]] || return 1
    [[ "${#userinfo}" -le 511 ]] || return 1
  fi

  if [[ "$endpoint" == \[*\]:* ]]; then
    host="${endpoint#\[}"
    host="${host%%\]:*}"
    port="${endpoint##*\]:}"
  else
    [[ "$endpoint" != *:*:* ]] || return 1
    host="${endpoint%:*}"
    port="${endpoint##*:}"
  fi

  [[ -n "$host" ]] || return 1
  validate_port "$port"
}

validate_vector_socks() {
  local socks="$1"
  local endpoint userinfo host port

  [[ -n "$socks" && "$socks" != "none" ]] || return 1
  [[ "$socks" != *[[:space:]]* ]] || return 1

  endpoint="$socks"
  if [[ "$endpoint" == *@* ]]; then
    userinfo="${endpoint%@*}"
    endpoint="${endpoint##*@}"
    [[ "$userinfo" == *:* ]] || return 1
    [[ -n "${userinfo%%:*}" && -n "${userinfo#*:}" ]] || return 1
    [[ "${#userinfo}" -le 511 ]] || return 1
  fi

  if [[ "$endpoint" == \[*\]:* ]]; then
    host="${endpoint#\[}"
    host="${host%%\]:*}"
    port="${endpoint##*\]:}"
    [[ -n "$host" ]] || return 1
  else
    [[ "$endpoint" != *:*:* ]] || return 1
    host="${endpoint%:*}"
    port="${endpoint##*:}"
  fi

  validate_port "$port"
}

validate_config_values() {
  validate_port "$NOWHERE_PORT" || die "Invalid port: ${NOWHERE_PORT}"
  [[ -n "$NOWHERE_KEY" ]] || die "NOWHERE_KEY cannot be empty."
  [[ "${#NOWHERE_KEY}" -le 255 ]] || die "NOWHERE_KEY must be <= 255 characters."
  if [[ "$NOWHERE_PROTOCOL" == "legacy" ]]; then
    [[ -z "$NOWHERE_SPEC" || "${#NOWHERE_SPEC}" -le 255 ]] || die "NOWHERE_SPEC must be <= 255 characters."
  else
    [[ -z "$NOWHERE_SPEC" ]] || die "NOWHERE_SPEC was removed in Nowhere v1.5."
  fi
  [[ -z "$NOWHERE_ALPN" || "${#NOWHERE_ALPN}" -le 255 ]] || die "NOWHERE_ALPN must be <= 255 characters."
  [[ "$NOWHERE_NET" == "mix" || "$NOWHERE_NET" == "tcp" || "$NOWHERE_NET" == "udp" ]] || die "NOWHERE_NET must be mix, tcp, or udp."
  [[ "$NOWHERE_TLS" == "1" || "$NOWHERE_TLS" == "2" ]] || die "NOWHERE_TLS must be 1 or 2."
  validate_nonnegative_int "$NOWHERE_RATE" || die "NOWHERE_RATE must be a non-negative integer."
  validate_nonnegative_int "$NOWHERE_ETAR" || die "NOWHERE_ETAR must be a non-negative integer."
  validate_socks "$NOWHERE_SOCKS" || die "NOWHERE_SOCKS must be none, host:port, or user:pass@host:port. IPv6 endpoints require brackets."
  [[ "$NOWHERE_LOG" == "none" || "$NOWHERE_LOG" == "debug" || "$NOWHERE_LOG" == "info" || "$NOWHERE_LOG" == "warn" || "$NOWHERE_LOG" == "error" || "$NOWHERE_LOG" == "event" ]] || die "Invalid log level: ${NOWHERE_LOG}"
  NOWHERE_CLIENT="$(normalize_client "$NOWHERE_CLIENT")" || die "NOWHERE_CLIENT must be anywhere, vector, or both."
  if [[ "$NOWHERE_PROTOCOL" == "legacy" && "$NOWHERE_CLIENT" != "anywhere" ]]; then
    die "Nowhere versions before v1.5 only support the Anywhere client output."
  fi
  if [[ "$NOWHERE_CLIENT" != "anywhere" && "$NOWHERE_VECTOR_PIN" != "none" ]] && ! version_at_least "$NOWHERE_VERSION" 1 5 1; then
    die "NOWHERE_VECTOR_PIN requires Nowhere v1.5.1 or newer."
  fi
  if [[ "$NOWHERE_CLIENT" == "vector" ]]; then
    [[ "$NOWHERE_POOL" =~ ^[0-9]+$ ]] && [[ "$NOWHERE_POOL" -ge 0 ]] && [[ "$NOWHERE_POOL" -le 256 ]] || die "NOWHERE_POOL must be 0..256 for Native Vector."
    validate_vector_socks "$NOWHERE_VECTOR_SOCKS" || die "NOWHERE_VECTOR_SOCKS must be [user:pass@]host:port or :port."
    [[ "$NOWHERE_VECTOR_SNI" == "none" || "$NOWHERE_VECTOR_SNI" =~ ^[A-Za-z0-9.-]+$ ]] || die "NOWHERE_VECTOR_SNI must be a DNS name or none."
    [[ "$NOWHERE_VECTOR_PIN" == "none" || "$NOWHERE_VECTOR_PIN" =~ ^[0-9a-f]{64}$ ]] || die "NOWHERE_VECTOR_PIN must be none or 64 lowercase hexadecimal characters."
  else
    [[ "$NOWHERE_POOL" =~ ^[0-9]+$ ]] && [[ "$NOWHERE_POOL" -ge 0 ]] && [[ "$NOWHERE_POOL" -le 9 ]] || die "NOWHERE_POOL must be 0..9 when Anywhere links are enabled."
    if [[ "$NOWHERE_CLIENT" == "both" ]]; then
      validate_vector_socks "$NOWHERE_VECTOR_SOCKS" || die "NOWHERE_VECTOR_SOCKS must be [user:pass@]host:port or :port."
      [[ "$NOWHERE_VECTOR_SNI" == "none" || "$NOWHERE_VECTOR_SNI" =~ ^[A-Za-z0-9.-]+$ ]] || die "NOWHERE_VECTOR_SNI must be a DNS name or none."
      [[ "$NOWHERE_VECTOR_PIN" == "none" || "$NOWHERE_VECTOR_PIN" =~ ^[0-9a-f]{64}$ ]] || die "NOWHERE_VECTOR_PIN must be none or 64 lowercase hexadecimal characters."
    fi
  fi
  validate_version_protocol
  if [[ "$NOWHERE_PROTOCOL" == "legacy" ]] && ! version_at_least "$NOWHERE_VERSION" 1 2 4 && [[ "$NOWHERE_SOCKS" != "none" && -n "$NOWHERE_SOCKS" ]]; then
    die "Portal outbound SOCKS5 requires Nowhere v1.2.4 or newer."
  fi
  if [[ "$NOWHERE_TLS" == "2" ]]; then
    [[ -n "$NOWHERE_CRT" && -n "$NOWHERE_TLS_KEY" ]] || die "tls=2 requires --crt and --tls-key."
    [[ -f "$NOWHERE_CRT" ]] || die "Certificate file not found: ${NOWHERE_CRT}"
    [[ -f "$NOWHERE_TLS_KEY" ]] || die "Private key file not found: ${NOWHERE_TLS_KEY}"
  fi
}

build_portal_url() {
  local encoded_key host_part query
  encoded_key="$(urlencode "$NOWHERE_KEY")"
  host_part="$(format_host_for_url "${NOWHERE_LISTEN_HOST:-}")"
  query="tls=${NOWHERE_TLS}"

  if [[ "$NOWHERE_PROTOCOL" == "legacy" && -n "$NOWHERE_SPEC" ]]; then
    query="${query}&spec=$(urlencode "$NOWHERE_SPEC")"
  fi
  if [[ -n "$NOWHERE_ALPN" && "$NOWHERE_ALPN" != "$DEFAULT_ALPN" ]]; then
    query="${query}&alpn=$(urlencode "$NOWHERE_ALPN")"
  fi
  if [[ "$NOWHERE_NET" != "$DEFAULT_NET" ]]; then
    query="${query}&net=${NOWHERE_NET}"
  fi
  if [[ -n "$NOWHERE_DIAL" && "$NOWHERE_DIAL" != "auto" ]]; then
    query="${query}&dial=$(urlencode "$NOWHERE_DIAL")"
  fi
  if [[ -n "$NOWHERE_SOCKS" && "$NOWHERE_SOCKS" != "$DEFAULT_SOCKS" ]]; then
    query="${query}&socks=$(urlencode "$NOWHERE_SOCKS")"
  fi
  if [[ "$NOWHERE_RATE" != "0" ]]; then
    query="${query}&rate=${NOWHERE_RATE}"
  fi
  if [[ "$NOWHERE_ETAR" != "0" ]]; then
    query="${query}&etar=${NOWHERE_ETAR}"
  fi
  if [[ "$NOWHERE_TLS" == "2" ]]; then
    query="${query}&crt=$(urlencode "$NOWHERE_CRT")&key=$(urlencode "$NOWHERE_TLS_KEY")"
  fi
  if [[ "$NOWHERE_LOG" != "$DEFAULT_LOG" ]]; then
    query="${query}&log=${NOWHERE_LOG}"
  fi

  printf 'portal://%s@%s:%s?%s' "$encoded_key" "$host_part" "$NOWHERE_PORT" "$query"
}

build_anywhere_client_query() {
  local up="$1"
  local down="$2"
  local query
  if version_at_least "${NOWHERE_VERSION_VALUE:-$DEFAULT_LEGACY_VERSION}" 1 3 0; then
    query="up=${up}&down=${down}"
  else
    [[ "$up" == "$down" ]] || return 1
    query="net=${up}"
  fi

  if [[ "$up" == "tcp" && "$down" == "tcp" ]]; then
    query="${query}&pool=${NOWHERE_POOL_VALUE:-$DEFAULT_POOL}"
  fi
  if ! version_at_least "${NOWHERE_VERSION_VALUE:-$DEFAULT_LEGACY_VERSION}" 1 5 0 && [[ -n "${NOWHERE_SPEC_VALUE:-}" ]]; then
    query="${query}&spec=$(urlencode "$NOWHERE_SPEC_VALUE")"
  fi
  if [[ -n "${NOWHERE_ALPN_VALUE:-}" && "$NOWHERE_ALPN_VALUE" != "$DEFAULT_ALPN" ]]; then
    query="${query}&alpn=$(urlencode "$NOWHERE_ALPN_VALUE")"
  fi

  printf '%s' "$query"
}

build_vector_query() {
  local up="$1"
  local down="$2"
  local query="up=${up}&down=${down}"

  if [[ "$up" == "tcp" && "$down" == "tcp" ]]; then
    query="${query}&pool=${NOWHERE_POOL_VALUE:-$DEFAULT_POOL}"
  fi
  query="${query}&sni=$(urlencode "${NOWHERE_VECTOR_SNI_VALUE:-$DEFAULT_VECTOR_SNI}")"
  if version_at_least "${NOWHERE_VERSION_VALUE:-$DEFAULT_MODERN_VERSION}" 1 5 1; then
    query="${query}&pin=$(urlencode "${NOWHERE_VECTOR_PIN_VALUE:-$DEFAULT_VECTOR_PIN}")"
  fi
  if [[ -n "${NOWHERE_ALPN_VALUE:-}" && "$NOWHERE_ALPN_VALUE" != "$DEFAULT_ALPN" ]]; then
    query="${query}&alpn=$(urlencode "$NOWHERE_ALPN_VALUE")"
  fi
  query="${query}&socks=$(urlencode "${NOWHERE_VECTOR_SOCKS_VALUE:-$DEFAULT_VECTOR_SOCKS}")"

  printf '%s' "$query"
}

default_vector_sni_for() {
  local host="${1:-}"
  local tls_mode="${2:-1}"
  host="$(strip_brackets "$host")"
  if [[ "$tls_mode" == "2" && "$host" =~ [A-Za-z] && "$host" != *:* ]]; then
    printf '%s' "$host"
  else
    printf '%s' "$DEFAULT_VECTOR_SNI"
  fi
}

configure_values() {
  load_config

  local generated_key generated_spec detected_host default_tls normalized_protocol saved_protocol saved_client
  generated_key="$(random_token 24)"
  generated_spec="$(random_token 12)"
  detected_host="$(detect_public_host)"

  saved_protocol="$(normalize_protocol "${NOWHERE_PROTOCOL_VALUE:-$DEFAULT_PROTOCOL}")" || saved_protocol="$DEFAULT_PROTOCOL"
  normalized_protocol="$(normalize_protocol "${NOWHERE_PROTOCOL:-$saved_protocol}")" || die "NOWHERE_PROTOCOL must be legacy or modern."
  NOWHERE_PROTOCOL="$normalized_protocol"
  NOWHERE_VERSION="${NOWHERE_VERSION:-${NOWHERE_VERSION_VALUE:-$(default_version_for_protocol "$NOWHERE_PROTOCOL")}}"
  if [[ -n "${NOWHERE_CLIENT_VALUE:-}" ]]; then
    saved_client="$(normalize_client "$NOWHERE_CLIENT_VALUE")" || saved_client="$DEFAULT_CLIENT"
  elif [[ "${NOWHERE_PROTOCOL_VALUE:-}" == "vector" ]]; then
    saved_client="vector"
  else
    saved_client="$DEFAULT_CLIENT"
  fi
  if [[ "$NOWHERE_PROTOCOL" == "legacy" ]]; then
    NOWHERE_CLIENT="anywhere"
  else
    NOWHERE_CLIENT="$(normalize_client "${NOWHERE_CLIENT:-$saved_client}")" || die "NOWHERE_CLIENT must be anywhere, vector, or both."
  fi

  NOWHERE_PORT="${NOWHERE_PORT:-${NOWHERE_PORT_VALUE:-$DEFAULT_PORT}}"
  NOWHERE_KEY="${NOWHERE_KEY:-${NOWHERE_KEY_VALUE:-$generated_key}}"
  if [[ "$NOWHERE_PROTOCOL" == "legacy" ]]; then
    NOWHERE_SPEC="${NOWHERE_SPEC:-${NOWHERE_SPEC_VALUE:-$generated_spec}}"
  else
    NOWHERE_SPEC=""
  fi
  NOWHERE_NET="${NOWHERE_NET:-${NOWHERE_NET_VALUE:-$DEFAULT_NET}}"
  NOWHERE_ALPN="${NOWHERE_ALPN:-${NOWHERE_ALPN_VALUE:-$DEFAULT_ALPN}}"
  NOWHERE_RATE="${NOWHERE_RATE:-${NOWHERE_RATE_VALUE:-0}}"
  NOWHERE_ETAR="${NOWHERE_ETAR:-${NOWHERE_ETAR_VALUE:-0}}"
  NOWHERE_DIAL="${NOWHERE_DIAL:-${NOWHERE_DIAL_VALUE:-auto}}"
  NOWHERE_SOCKS="${NOWHERE_SOCKS:-${NOWHERE_SOCKS_VALUE:-$DEFAULT_SOCKS}}"
  NOWHERE_LOG="${NOWHERE_LOG:-${NOWHERE_LOG_VALUE:-$DEFAULT_LOG}}"
  if [[ "$NOWHERE_PROTOCOL" != "$saved_protocol" ]]; then
    NOWHERE_POOL="${NOWHERE_POOL:-$DEFAULT_POOL}"
  else
    NOWHERE_POOL="${NOWHERE_POOL:-${NOWHERE_POOL_VALUE:-$DEFAULT_POOL}}"
  fi
  NOWHERE_VECTOR_SOCKS="${NOWHERE_VECTOR_SOCKS:-${NOWHERE_VECTOR_SOCKS_VALUE:-$DEFAULT_VECTOR_SOCKS}}"
  NOWHERE_VECTOR_SNI="${NOWHERE_VECTOR_SNI:-${NOWHERE_VECTOR_SNI_VALUE:-}}"
  NOWHERE_VECTOR_PIN="${NOWHERE_VECTOR_PIN:-${NOWHERE_VECTOR_PIN_VALUE:-$DEFAULT_VECTOR_PIN}}"
  NOWHERE_PUBLIC_HOST="${NOWHERE_PUBLIC_HOST:-${NOWHERE_PUBLIC_HOST_VALUE:-$detected_host}}"
  NOWHERE_LISTEN_HOST="${NOWHERE_LISTEN_HOST:-${NOWHERE_LISTEN_HOST_VALUE:-}}"
  NOWHERE_CRT="${NOWHERE_CRT:-${NOWHERE_CRT_VALUE:-}}"
  NOWHERE_TLS_KEY="${NOWHERE_TLS_KEY:-${NOWHERE_TLS_KEY_VALUE:-}}"
  default_tls="1"
  if [[ -n "$NOWHERE_CRT" || -n "$NOWHERE_TLS_KEY" ]]; then
    default_tls="2"
  fi
  NOWHERE_TLS="${NOWHERE_TLS:-${NOWHERE_TLS_VALUE:-$default_tls}}"

  if [[ "$ASSUME_YES" -eq 0 ]]; then
    info "进入 $(protocol_label "$NOWHERE_PROTOCOL") 配置向导：一路回车即可使用默认值。"
    if [[ "$NOWHERE_PROTOCOL" == "modern" ]]; then
      NOWHERE_CLIENT="$(read_value "客户端链接 anywhere/vector/both" "$NOWHERE_CLIENT")"
    fi
    NOWHERE_PUBLIC_HOST="$(read_value "公网域名/IP，用于客户端连接" "$NOWHERE_PUBLIC_HOST")"
    NOWHERE_LISTEN_HOST="$(read_value "监听地址，留空表示 IPv4/IPv6 全部监听" "$NOWHERE_LISTEN_HOST")"
    NOWHERE_PORT="$(read_value "监听端口" "$NOWHERE_PORT")"
    NOWHERE_KEY="$(read_value "Shared Key" "$NOWHERE_KEY")"
    if [[ "$NOWHERE_PROTOCOL" == "legacy" ]]; then
      NOWHERE_SPEC="$(read_value "Spec Seed" "$NOWHERE_SPEC")"
    fi
    NOWHERE_NET="$(read_value "监听模式 mix/tcp/udp" "$NOWHERE_NET")"
    NOWHERE_ALPN="$(read_value "ALPN" "$NOWHERE_ALPN")"
    NOWHERE_TLS="$(read_value "TLS 模式：1=临时自签，2=PEM 证书" "$NOWHERE_TLS")"
    if [[ "$NOWHERE_TLS" == "2" ]]; then
      NOWHERE_CRT="$(read_value "证书链路径 fullchain.pem/cert.pem" "$NOWHERE_CRT")"
      NOWHERE_TLS_KEY="$(read_value "私钥路径 privkey.pem/key.pem" "$NOWHERE_TLS_KEY")"
    fi
    NOWHERE_RATE="$(read_value "上行限速 Mbps，0 表示不限速" "$NOWHERE_RATE")"
    NOWHERE_ETAR="$(read_value "下行限速 Mbps，0 表示不限速" "$NOWHERE_ETAR")"
    NOWHERE_DIAL="$(read_value "出站源 IP，auto 表示系统默认" "$NOWHERE_DIAL")"
    NOWHERE_SOCKS="$(read_value "SOCKS5 出站代理，none/host:port/user:pass@host:port" "$NOWHERE_SOCKS")"
    NOWHERE_LOG="$(read_value "日志级别 none/debug/info/warn/error/event" "$NOWHERE_LOG")"
    if [[ "$NOWHERE_CLIENT" == "vector" || "$NOWHERE_CLIENT" == "both" ]]; then
      if [[ "$NOWHERE_CLIENT" == "both" ]]; then
        NOWHERE_POOL="$(read_value "TCP pool（Anywhere 限制为 0..9）" "$NOWHERE_POOL")"
      else
        NOWHERE_POOL="$(read_value "Native Vector TCP pool，0..256" "$NOWHERE_POOL")"
      fi
      NOWHERE_VECTOR_SOCKS="$(read_value "Vector 本地 SOCKS5 监听地址" "$NOWHERE_VECTOR_SOCKS")"
      if [[ -z "$NOWHERE_VECTOR_SNI" ]]; then
        NOWHERE_VECTOR_SNI="$(default_vector_sni_for "$NOWHERE_PUBLIC_HOST" "$NOWHERE_TLS")"
      fi
      NOWHERE_VECTOR_SNI="$(read_value "Vector SNI，none 表示不校验证书" "$NOWHERE_VECTOR_SNI")"
      NOWHERE_VECTOR_PIN="$(read_value "Vector 证书 SHA-256 pin，none 表示不固定证书" "$NOWHERE_VECTOR_PIN")"
    else
      NOWHERE_POOL="$(read_value "Anywhere TCP pool，0..9" "$NOWHERE_POOL")"
    fi
  fi

  if [[ "$NOWHERE_CLIENT" == "vector" || "$NOWHERE_CLIENT" == "both" ]] && [[ -z "$NOWHERE_VECTOR_SNI" ]]; then
    NOWHERE_VECTOR_SNI="$(default_vector_sni_for "$NOWHERE_PUBLIC_HOST" "$NOWHERE_TLS")"
  fi

  validate_config_values
  NOWHERE_PORTAL="$(build_portal_url)"
  if [[ "$ASSUME_YES" -eq 0 ]]; then
    print_config_summary
    confirm_default_yes "确认保存并应用以上配置吗？" || die "已取消配置。"
  fi
}

save_config() {
  install -d -m 700 "$CONFIG_DIR"
  cat >"$CONFIG_FILE" <<EOF
NOWHERE_PORTAL=$(env_quote "$NOWHERE_PORTAL")
NOWHERE_PROTOCOL_VALUE=$(env_quote "$NOWHERE_PROTOCOL")
NOWHERE_CLIENT_VALUE=$(env_quote "$NOWHERE_CLIENT")
NOWHERE_VERSION_VALUE=$(env_quote "$NOWHERE_VERSION")
NOWHERE_PUBLIC_HOST_VALUE=$(env_quote "$NOWHERE_PUBLIC_HOST")
NOWHERE_LISTEN_HOST_VALUE=$(env_quote "$NOWHERE_LISTEN_HOST")
NOWHERE_PORT_VALUE=$(env_quote "$NOWHERE_PORT")
NOWHERE_KEY_VALUE=$(env_quote "$NOWHERE_KEY")
NOWHERE_SPEC_VALUE=$(env_quote "$NOWHERE_SPEC")
NOWHERE_NET_VALUE=$(env_quote "$NOWHERE_NET")
NOWHERE_ALPN_VALUE=$(env_quote "$NOWHERE_ALPN")
NOWHERE_TLS_VALUE=$(env_quote "$NOWHERE_TLS")
NOWHERE_CRT_VALUE=$(env_quote "$NOWHERE_CRT")
NOWHERE_TLS_KEY_VALUE=$(env_quote "$NOWHERE_TLS_KEY")
NOWHERE_RATE_VALUE=$(env_quote "$NOWHERE_RATE")
NOWHERE_ETAR_VALUE=$(env_quote "$NOWHERE_ETAR")
NOWHERE_DIAL_VALUE=$(env_quote "$NOWHERE_DIAL")
NOWHERE_SOCKS_VALUE=$(env_quote "$NOWHERE_SOCKS")
NOWHERE_LOG_VALUE=$(env_quote "$NOWHERE_LOG")
NOWHERE_POOL_VALUE=$(env_quote "$NOWHERE_POOL")
NOWHERE_VECTOR_SOCKS_VALUE=$(env_quote "$NOWHERE_VECTOR_SOCKS")
NOWHERE_VECTOR_SNI_VALUE=$(env_quote "$NOWHERE_VECTOR_SNI")
NOWHERE_VECTOR_PIN_VALUE=$(env_quote "$NOWHERE_VECTOR_PIN")
EOF
  chmod 600 "$CONFIG_FILE"
  info "Config saved to ${CONFIG_FILE}"
}

detect_asset() {
  local arch libc
  case "$(uname -m)" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *) die "Unsupported architecture: $(uname -m)" ;;
  esac
  libc="gnu"
  if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
    libc="musl"
  fi
  printf 'nowhere-%s-unknown-linux-%s.tar.gz' "$arch" "$libc"
}

install_binary() {
  command -v curl >/dev/null 2>&1 || die "curl is required to download Nowhere."
  command -v tar >/dev/null 2>&1 || die "tar is required."

  local version="${1:-${NOWHERE_VERSION:-}}"
  local asset url tmpdir binary
  validate_release_version "$version" || die "An exact release version such as v1.5.1 is required."
  asset="$(detect_asset)"
  url="https://github.com/${REPO}/releases/download/${version}/${asset}"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir:-}"' RETURN

  info "Downloading ${asset} from ${REPO} ${version}..."
  curl -fL --retry 3 --connect-timeout 10 -o "${tmpdir}/${asset}" "$url"
  tar -xzf "${tmpdir}/${asset}" -C "$tmpdir"
  binary="$(find "$tmpdir" -type f -name nowhere -perm -u+x | head -n 1)"
  if [[ -z "$binary" ]]; then
    binary="$(find "$tmpdir" -type f -name nowhere | head -n 1)"
  fi
  [[ -n "$binary" ]] || die "Could not find nowhere binary in release archive."
  install -m 755 "$binary" "$BIN_PATH"
  rm -rf "$tmpdir"
  trap - RETURN
  info "Installed ${BIN_PATH} (${version})"
}

write_service() {
  cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Nowhere Portal
Documentation=https://github.com/${REPO}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=${CONFIG_FILE}
ExecStart=${BIN_PATH} \${NOWHERE_PORTAL}
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=read-only
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  info "systemd service written to ${SERVICE_FILE}"
}

service_cmd() {
  require_root
  require_systemd
  systemctl "$1" "$SERVICE_NAME"
}

start_service() {
  service_cmd start
  print_tls_fingerprint
}

restart_service() {
  service_cmd restart
  print_tls_fingerprint
}

print_links() {
  require_root
  load_config
  [[ -n "${NOWHERE_KEY_VALUE:-}" ]] || die "No config found. Run install or configure first."

  local protocol client version host host_part encoded_key encoded_name base udp_link tcp_link tcp_udp_link udp_tcp_link
  local import_udp import_tcp import_tcp_udp import_udp_tcp
  protocol="$(normalize_protocol "${NOWHERE_PROTOCOL_VALUE:-$DEFAULT_PROTOCOL}")" || die "Invalid saved protocol mode."
  if [[ -n "${NOWHERE_CLIENT_VALUE:-}" ]]; then
    client="$(normalize_client "$NOWHERE_CLIENT_VALUE")" || client="$DEFAULT_CLIENT"
  elif [[ "${NOWHERE_PROTOCOL_VALUE:-}" == "vector" ]]; then
    client="vector"
  else
    client="$DEFAULT_CLIENT"
  fi
  [[ "$protocol" == "legacy" ]] && client="anywhere"
  version="${NOWHERE_VERSION_VALUE:-$(default_version_for_protocol "$protocol")}"
  host="${NOWHERE_PUBLIC_HOST_VALUE:-}"
  [[ -n "$host" ]] || host="$(detect_public_host)"
  [[ -n "$host" ]] || die "Public host is empty. Re-run configure with --public-host."
  host_part="$(format_host_for_url "$host")"
  encoded_key="$(urlencode "$NOWHERE_KEY_VALUE")"

  echo
  echo "Protocol mode: $(protocol_label "$protocol")"
  echo "Client output: $(client_label "$client")"
  echo "Release: ${version}"
  echo
  echo "Portal URL:"
  echo "  ${NOWHERE_PORTAL:-}"
  echo

  if [[ "$client" == "vector" || "$client" == "both" ]]; then
    base="vector://${encoded_key}@${host_part}:${NOWHERE_PORT_VALUE}"
    udp_link="${base}?$(build_vector_query udp udp)"
    tcp_link="${base}?$(build_vector_query tcp tcp)"
    tcp_udp_link="${base}?$(build_vector_query tcp udp)"
    udp_tcp_link="${base}?$(build_vector_query udp tcp)"

    if [[ "${NOWHERE_NET_VALUE:-mix}" == "tcp" ]]; then
      echo "Native Vector URL (TLS/TCP):"
      echo "  ${tcp_link}"
      echo
      echo "Client command:"
      echo "  nowhere '${tcp_link}'"
    elif [[ "${NOWHERE_NET_VALUE:-mix}" == "udp" ]]; then
      echo "Native Vector URL (QUIC/UDP):"
      echo "  ${udp_link}"
      echo
      echo "Client command:"
      echo "  nowhere '${udp_link}'"
    else
      echo "Native Vector URL (QUIC/UDP):"
      echo "  ${udp_link}"
      echo
      echo "Native Vector URL (TLS/TCP):"
      echo "  ${tcp_link}"
      echo
      echo "Native Vector URLs (split carriers):"
      echo "  up=tcp/down=udp: ${tcp_udp_link}"
      echo "  up=udp/down=tcp: ${udp_tcp_link}"
      echo
      echo "Run one URL on a v1.5+ client, for example:"
      echo "  nowhere '${udp_link}'"
    fi
    [[ "$client" == "both" ]] && echo
  fi

  if [[ "$client" == "anywhere" || "$client" == "both" ]]; then
    encoded_name="$(urlencode "Nowhere VPS")"
    base="nowhere://${encoded_key}@${host_part}:${NOWHERE_PORT_VALUE}"
    udp_link="${base}?$(build_anywhere_client_query udp udp)#${encoded_name}"
    tcp_link="${base}?$(build_anywhere_client_query tcp tcp)#${encoded_name}"
    import_udp="anywhere://add-proxy?link=$(urlencode "$udp_link")"
    import_tcp="anywhere://add-proxy?link=$(urlencode "$tcp_link")"

    if version_at_least "$version" 1 3 0; then
      tcp_udp_link="${base}?$(build_anywhere_client_query tcp udp)#${encoded_name}"
      udp_tcp_link="${base}?$(build_anywhere_client_query udp tcp)#${encoded_name}"
      import_tcp_udp="anywhere://add-proxy?link=$(urlencode "$tcp_udp_link")"
      import_udp_tcp="anywhere://add-proxy?link=$(urlencode "$udp_tcp_link")"
    fi

    if [[ "${NOWHERE_NET_VALUE:-mix}" == "tcp" ]]; then
      echo "Anywhere import link (TLS/TCP):"
      echo "  ${tcp_link}"
      echo
      echo "Anywhere deep link:"
      echo "  ${import_tcp}"
    elif [[ "${NOWHERE_NET_VALUE:-mix}" == "udp" ]]; then
      echo "Anywhere import link (QUIC/UDP):"
      echo "  ${udp_link}"
      echo
      echo "Anywhere deep link:"
      echo "  ${import_udp}"
    else
      echo "Anywhere import link (QUIC/UDP recommended):"
      echo "  ${udp_link}"
      echo
      echo "Anywhere import link (TLS/TCP fallback):"
      echo "  ${tcp_link}"
      if version_at_least "$version" 1 3 0 && [[ -z "${NOWHERE_SOCKS_VALUE:-}" || "${NOWHERE_SOCKS_VALUE}" == "$DEFAULT_SOCKS" ]]; then
        echo
        echo "Anywhere import links (split carriers):"
        echo "  up=tcp/down=udp: ${tcp_udp_link}"
        echo "  up=udp/down=tcp: ${udp_tcp_link}"
      fi
      echo
      echo "Anywhere deep link (QUIC/UDP):"
      echo "  ${import_udp}"
      echo
      echo "Anywhere deep link (TLS/TCP):"
      echo "  ${import_tcp}"
      if version_at_least "$version" 1 3 0 && [[ -z "${NOWHERE_SOCKS_VALUE:-}" || "${NOWHERE_SOCKS_VALUE}" == "$DEFAULT_SOCKS" ]]; then
        echo
        echo "Anywhere deep links (split carriers):"
        echo "  up=tcp/down=udp: ${import_tcp_udp}"
        echo "  up=udp/down=tcp: ${import_udp_tcp}"
      fi
    fi
  fi

  echo
  echo "Firewall reminder:"
  if [[ "${NOWHERE_NET_VALUE:-mix}" == "tcp" ]]; then
    echo "  Open TCP ${NOWHERE_PORT_VALUE}"
  elif [[ "${NOWHERE_NET_VALUE:-mix}" == "udp" ]]; then
    echo "  Open UDP ${NOWHERE_PORT_VALUE}"
  else
    echo "  Open TCP ${NOWHERE_PORT_VALUE} and UDP ${NOWHERE_PORT_VALUE}"
  fi
  if [[ "${NOWHERE_TLS_VALUE:-1}" == "1" ]]; then
    echo
    echo "TLS note:"
    if [[ "$client" == "vector" ]]; then
      echo "  Native Vector uses sni=none to disable verification for tls=1; it does not accept an Anywhere fingerprint."
    elif [[ "$client" == "both" ]]; then
      echo "  Anywhere can trust the current SHA-256; Native Vector uses sni=none unless configured otherwise."
    else
      echo "  tls=1 uses an ephemeral self-signed certificate. Trust the current SHA-256 in Anywhere or use tls=2."
    fi
  fi
  if [[ -n "${NOWHERE_SOCKS_VALUE:-}" && "${NOWHERE_SOCKS_VALUE}" != "$DEFAULT_SOCKS" ]]; then
    echo
    echo "Outbound SOCKS5:"
    echo "  $(display_socks "$NOWHERE_SOCKS_VALUE")"
  fi
}

install_all() {
  require_root
  require_systemd
  configure_values
  install_binary "$NOWHERE_VERSION"
  save_config
  write_service
  systemctl enable --now "$SERVICE_NAME"
  info "Nowhere service enabled and started."
  print_links
  print_tls_fingerprint
}

install_legacy_all() {
  NOWHERE_PROTOCOL="legacy"
  NOWHERE_CLIENT="anywhere"
  if [[ "$VERSION_EXPLICIT" -eq 0 ]]; then
    NOWHERE_VERSION="$DEFAULT_LEGACY_VERSION"
  fi
  install_all
}

install_vector_all() {
  NOWHERE_PROTOCOL="modern"
  NOWHERE_CLIENT="vector"
  if [[ "$VERSION_EXPLICIT" -eq 0 ]]; then
    NOWHERE_VERSION="$DEFAULT_VECTOR_VERSION"
  fi
  install_all
}

install_anywhere_all() {
  NOWHERE_PROTOCOL="modern"
  NOWHERE_CLIENT="anywhere"
  if [[ "$VERSION_EXPLICIT" -eq 0 ]]; then
    NOWHERE_VERSION="$DEFAULT_MODERN_VERSION"
  fi
  install_all
}

install_by_protocol() {
  local requested_protocol
  if [[ "$VERSION_EXPLICIT" -eq 1 ]]; then
    requested_protocol="$(protocol_for_version "$NOWHERE_VERSION")"
  else
    requested_protocol="$(normalize_protocol "${NOWHERE_PROTOCOL:-$DEFAULT_PROTOCOL}")" || die "NOWHERE_PROTOCOL must be legacy or modern."
  fi
  if [[ "$requested_protocol" == "modern" ]]; then
    NOWHERE_PROTOCOL="modern"
    NOWHERE_CLIENT="$(normalize_client "${NOWHERE_CLIENT:-$DEFAULT_CLIENT}")" || die "NOWHERE_CLIENT must be anywhere, vector, or both."
    if [[ "$VERSION_EXPLICIT" -eq 0 ]]; then
      NOWHERE_VERSION="$DEFAULT_MODERN_VERSION"
    fi
    install_all
  else
    install_legacy_all
  fi
}

quick_install_anywhere_all() {
  ASSUME_YES=1 install_anywhere_all
}

configure_all() {
  require_root
  require_systemd
  load_config
  [[ -n "${NOWHERE_PROTOCOL_VALUE:-}" ]] || warn "旧配置未记录协议模式，将按已安装版本自动判断。"
  local saved_protocol
  saved_protocol="$(normalize_protocol "${NOWHERE_PROTOCOL_VALUE:-$(protocol_for_version "${NOWHERE_VERSION_VALUE:-$DEFAULT_MODERN_VERSION}")}")" || die "Invalid saved protocol mode."
  if [[ -n "${NOWHERE_PROTOCOL:-}" ]]; then
    [[ "$(normalize_protocol "$NOWHERE_PROTOCOL")" == "$saved_protocol" ]] || die "Use install/versions to switch protocol generations safely."
  fi
  NOWHERE_PROTOCOL="$saved_protocol"
  NOWHERE_VERSION="${NOWHERE_VERSION_VALUE:-$(default_version_for_protocol "$saved_protocol")}"
  configure_values
  save_config
  write_service
  if systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
    systemctl restart "$SERVICE_NAME"
    info "Nowhere service restarted."
    print_tls_fingerprint
  else
    warn "Service is configured but not enabled. Run: systemctl enable --now ${SERVICE_NAME}"
  fi
  print_links
}

update_saved_version() {
  local version="$1"
  local replacement tmp
  replacement="NOWHERE_VERSION_VALUE=$(env_quote "$version")"
  tmp="$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")"
  awk -v replacement="$replacement" '
    BEGIN { updated = 0 }
    /^NOWHERE_VERSION_VALUE=/ { print replacement; updated = 1; next }
    { print }
    END { if (!updated) print replacement }
  ' "$CONFIG_FILE" >"$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$CONFIG_FILE"
}

update_all() {
  require_root
  require_systemd
  load_config
  [[ -n "${NOWHERE_VERSION_VALUE:-}" ]] || die "No existing installation config found. Run install first."

  local old_protocol new_protocol selected
  old_protocol="$(normalize_protocol "${NOWHERE_PROTOCOL_VALUE:-$(protocol_for_version "$NOWHERE_VERSION_VALUE")}")" || die "Invalid saved protocol mode."
  if [[ "$VERSION_EXPLICIT" -eq 1 ]]; then
    selected="$NOWHERE_VERSION"
    validate_release_version "$selected" || die "Invalid release version: ${selected}"
  else
    if ! choose_release_version; then
      info "已取消二进制更新。"
      return 0
    fi
    selected="$SELECTED_VERSION"
  fi
  new_protocol="$(protocol_for_version "$selected")"

  if [[ "$new_protocol" != "$old_protocol" ]]; then
    warn "${NOWHERE_VERSION_VALUE} 到 ${selected} 跨越 v1.5 协议边界，需要迁移配置。"
    NOWHERE_VERSION="$selected"
    NOWHERE_PROTOCOL="$new_protocol"
    unset NOWHERE_SPEC
    install_all
    return
  fi

  install_binary "$selected"
  update_saved_version "$selected"
  if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
    systemctl restart "$SERVICE_NAME"
    info "Nowhere binary updated from ${NOWHERE_VERSION_VALUE} to ${selected}; service restarted."
  else
    info "Nowhere binary updated from ${NOWHERE_VERSION_VALUE} to ${selected}; service is not running."
  fi
  print_links
  print_tls_fingerprint
}

install_selected_release() {
  require_root
  require_systemd
  if ! choose_release_version; then
    info "已取消版本选择。"
    return 0
  fi
  NOWHERE_VERSION="$SELECTED_VERSION"
  NOWHERE_PROTOCOL="$(protocol_for_version "$NOWHERE_VERSION")"
  echo
  info "已选择 ${NOWHERE_VERSION}，将使用 $(protocol_label "$NOWHERE_PROTOCOL") 配置。"
  install_all
}

uninstall_all() {
  require_root
  require_systemd
  systemctl disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true
  rm -f "$SERVICE_FILE" "$BIN_PATH"
  systemctl daemon-reload
  warn "Kept ${CONFIG_DIR} so you do not lose keys. Remove it manually if you really want to wipe the config."
}

menu() {
  require_root
  require_systemd
  while true; do
    cat <<EOF

==============================
 Nowhere VPS 管理脚本
==============================
  1) 安装/重装新版（Anywhere 2.0，${DEFAULT_MODERN_VERSION}）
  2) 安装/重装新版（Native Vector，${DEFAULT_VECTOR_VERSION}）
  3) 快速默认安装（Anywhere 2.0，${DEFAULT_MODERN_VERSION}）
  4) 修改当前协议模式配置（向导）
  5) 指定 Release 安装/切换（最近 10 个版本）
  6) 更新 Nowhere 二进制（保留当前配置）
  7) 安装/重装旧版（Anywhere 1.x，${DEFAULT_LEGACY_VERSION}）
  8) 启动服务
  9) 停止服务
 10) 重启服务
 11) 查看状态
 12) 查看日志
 13) 打印客户端链接/命令
 14) 查看 tls=1 自签证书 SHA-256
 15) 卸载服务
  0) 退出
EOF
    read -r -p "请输入数字: " choice
    case "$choice" in
      1) install_anywhere_all ;;
      2) install_vector_all ;;
      3) quick_install_anywhere_all ;;
      4) configure_all ;;
      5) install_selected_release ;;
      6) update_all ;;
      7) install_legacy_all ;;
      8) start_service ;;
      9) service_cmd stop ;;
      10) restart_service ;;
      11) service_cmd status ;;
      12) journalctl -u "$SERVICE_NAME" -f ;;
      13) print_links ;;
      14) print_tls_fingerprint ;;
      15) uninstall_all ;;
      0) exit 0 ;;
      *) warn "未知选项：${choice}" ;;
    esac
  done
}

case "$ACTION" in
  install) install_by_protocol ;;
  install-anywhere|anywhere) install_anywhere_all ;;
  install-legacy) install_legacy_all ;;
  install-vector|vector) install_vector_all ;;
  configure|config) configure_all ;;
  update) update_all ;;
  versions|version|releases|release) install_selected_release ;;
  start) start_service ;;
  restart) restart_service ;;
  stop|status) service_cmd "$ACTION" ;;
  fingerprint|sha256|sha-256) print_tls_fingerprint ;;
  logs|log) require_root; journalctl -u "$SERVICE_NAME" -f ;;
  link|links) print_links ;;
  uninstall|remove) uninstall_all ;;
  menu) menu ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
