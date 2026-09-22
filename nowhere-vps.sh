#!/usr/bin/env bash
set -euo pipefail

REPO="NodePassProject/Nowhere"
SCRIPT_RAW_URL="https://raw.githubusercontent.com/chikacya/nowhere-sh/main/nowhere-vps.sh"
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
if command -v readlink >/dev/null 2>&1; then SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH" 2>/dev/null || printf '%s' "$SCRIPT_PATH")"; fi
SERVICE_NAME="nowhere"
BIN_PATH="/usr/local/bin/nowhere"
CONFIG_DIR="/etc/nowhere"
CONFIG_FILE="${CONFIG_DIR}/nowhere.env"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

DEFAULT_VERSION="v2.1.0"
DEFAULT_PORT="2077"
DEFAULT_TCP_CARRIER="tcp"
DEFAULT_UDP_CARRIER="udp"
DEFAULT_CLIENT="anywhere"
DEFAULT_TLS="1"
DEFAULT_LOG="info"
DEFAULT_MORPH="0"
DEFAULT_MORPH_TCP_PRELUDE="low7"
DEFAULT_MUX="0"
DEFAULT_TRANSPORT_MEMORY_PROFILE="throughput"
DEFAULT_MIX_FALLBACK_TIMEOUT="1s"
DEFAULT_SOCKS="none"
DEFAULT_VECTOR_SOCKS="127.0.0.1:1080"
DEFAULT_SNI="none"
DEFAULT_PIN="none"
DEFAULT_TELEMETRY_INTERVAL="1s"

ASSUME_YES=0
VERSION_EXPLICIT=0
ALLOW_MORPH_BREAKING_UPGRADE=0
ACTION="${1:-menu}"
[[ $# -eq 0 ]] || shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1; shift ;;
    --lang) NOWHERE_LANG="${2:?missing --lang value}"; shift 2 ;;
    --version) NOWHERE_VERSION="${2:?missing --version value}"; VERSION_EXPLICIT=1; shift 2 ;;
    --client) NOWHERE_CLIENT="${2:?missing --client value}"; shift 2 ;;
    --key) NOWHERE_KEY="${2:?missing --key value}"; shift 2 ;;
    --public-host) NOWHERE_PUBLIC_HOST="${2:?missing --public-host value}"; shift 2 ;;
    --listen-host) NOWHERE_LISTEN_HOST="${2:?missing --listen-host value}"; shift 2 ;;
    --tcp-carrier) NOWHERE_TCP_CARRIER="${2:?missing --tcp-carrier value}"; shift 2 ;;
    --tcp-port) NOWHERE_TCP_PORT="${2:?missing --tcp-port value}"; shift 2 ;;
    --udp-carrier) NOWHERE_UDP_CARRIER="${2:?missing --udp-carrier value}"; shift 2 ;;
    --udp-port) NOWHERE_UDP_PORT="${2:?missing --udp-port value}"; shift 2 ;;
    --tls) NOWHERE_TLS="${2:?missing --tls value}"; shift 2 ;;
    --crt|--cert) NOWHERE_CRT="${2:?missing --crt value}"; shift 2 ;;
    --tls-key) NOWHERE_TLS_KEY="${2:?missing --tls-key value}"; shift 2 ;;
    --morph) NOWHERE_MORPH="${2:?missing --morph value}"; shift 2 ;;
    --morph-tcp-prelude) NOWHERE_MORPH_TCP_PRELUDE="${2:?missing --morph-tcp-prelude value}"; shift 2 ;;
    --allow-morph-breaking-upgrade) ALLOW_MORPH_BREAKING_UPGRADE=1; shift ;;
    --rate) NOWHERE_RATE="${2:?missing --rate value}"; shift 2 ;;
    --etar) NOWHERE_ETAR="${2:?missing --etar value}"; shift 2 ;;
    --dial) NOWHERE_DIAL="${2:?missing --dial value}"; shift 2 ;;
    --socks) NOWHERE_SOCKS="${2:?missing --socks value}"; shift 2 ;;
    --next) NOWHERE_NEXT="${2:?missing --next value}"; shift 2 ;;
    --next-up) NOWHERE_NEXT_UP="${2:?missing --next-up value}"; shift 2 ;;
    --next-down) NOWHERE_NEXT_DOWN="${2:?missing --next-down value}"; shift 2 ;;
    --next-mux) NOWHERE_NEXT_MUX="${2:?missing --next-mux value}"; shift 2 ;;
    --next-sni) NOWHERE_NEXT_SNI="${2:?missing --next-sni value}"; shift 2 ;;
    --next-pin) NOWHERE_NEXT_PIN="${2:?missing --next-pin value}"; shift 2 ;;
    --vector-up) NOWHERE_VECTOR_UP="${2:?missing --vector-up value}"; shift 2 ;;
    --vector-down) NOWHERE_VECTOR_DOWN="${2:?missing --vector-down value}"; shift 2 ;;
    --mux) NOWHERE_VECTOR_MUX="${2:?missing --mux value}"; shift 2 ;;
    --vector-socks) NOWHERE_VECTOR_SOCKS="${2:?missing --vector-socks value}"; shift 2 ;;
    --vector-rate) NOWHERE_VECTOR_RATE="${2:?missing --vector-rate value}"; shift 2 ;;
    --vector-etar) NOWHERE_VECTOR_ETAR="${2:?missing --vector-etar value}"; shift 2 ;;
    --vector-log) NOWHERE_VECTOR_LOG="${2:?missing --vector-log value}"; shift 2 ;;
    --sni) NOWHERE_VECTOR_SNI="${2:?missing --sni value}"; shift 2 ;;
    --pin) NOWHERE_VECTOR_PIN="${2:?missing --pin value}"; shift 2 ;;
    --log) NOWHERE_LOG="${2:?missing --log value}"; shift 2 ;;
    --transport-memory-profile) NOWHERE_TRANSPORT_MEMORY_PROFILE="${2:?missing --transport-memory-profile value}"; shift 2 ;;
    --mix-fallback-timeout) NOWHERE_MIX_FALLBACK_TIMEOUT="${2:?missing --mix-fallback-timeout value}"; shift 2 ;;
    --telemetry-interval) NOWHERE_TELEMETRY_INTERVAL="${2:?missing --telemetry-interval value}"; shift 2 ;;
    -h|--help) ACTION="help"; shift ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

info() { printf '\033[1;34m[Nowhere]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[Warn]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[Error]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Nowhere VPS deployment and management script.

Usage:
  sudo bash nowhere-vps.sh
  sudo bash nowhere-vps.sh install [--yes] [options]
  sudo bash nowhere-vps.sh install-vector [--yes] [options]
  sudo bash nowhere-vps.sh configure [options]
  sudo bash nowhere-vps.sh update [--version v2.1.0]
  sudo bash nowhere-vps.sh update-script
  sudo bash nowhere-vps.sh versions
  sudo bash nowhere-vps.sh start|stop|restart|status|tui|logs|link|fingerprint|uninstall

This script supports Nowhere releases v2.0.0 and later. Press Enter in the wizard to keep defaults.

Options:
  --client anywhere|vector|both
  --lang zh|en                    Wizard and menu language
  --version v2.1.0
  --key secret
  --public-host host              Client-facing domain or IP
  --listen-host host              Portal bind host; empty binds wildcard addresses
  --tcp-carrier tcp|tcp4|tcp6|none
  --tcp-port 2077
  --udp-carrier udp|udp4|udp6|none
  --udp-port 2077
  --tls 1|2                       1=self-signed, 2=PEM certificate
  --crt /absolute/certificate.pem --tls-key /absolute/private.key
  --morph 0|1
  --morph-tcp-prelude low7|full8    TCP Morph prelude for native next connections
  --allow-morph-breaking-upgrade    Confirm a Morph upgrade from v2.0.x to v2.1+
  --rate 0 --etar 0 --dial auto --log info
  --socks none|[user:pass@]host:port
  --next key@host:port            Native Portal upstream; mutually exclusive with socks
  --next-up tcp|udp|mix --next-down tcp|udp|mix --next-mux 0|1
  --next-sni name|none --next-pin sha256|none
  --vector-up tcp|udp|mix --vector-down tcp|udp|mix --mux 0|1
  --vector-socks 127.0.0.1:1080 --vector-rate 0 --vector-etar 0 --vector-log info
  --sni name|none --pin sha256|none
  --transport-memory-profile memory|balanced|throughput
  --mix-fallback-timeout 1s
  --telemetry-interval 1s
EOF
}

require_root() { [[ "$(id -u)" -eq 0 ]] || die "Please run as root: sudo bash $0 ${ACTION}"; }
require_systemd() {
  command -v systemctl >/dev/null 2>&1 || die "systemctl is required."
  [[ -d /run/systemd/system ]] || warn "systemd does not appear to be running; service commands may fail."
}
load_config() { [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || true; }
validate_language() { [[ "$1" == zh || "$1" == en ]]; }
default_language() {
  case "${LC_ALL:-${LANG:-}}" in zh_*|zh.*) printf zh ;; *) printf en ;; esac
}
is_chinese() { [[ "$NOWHERE_LANG" == zh ]]; }
resolve_language() {
  if [[ -n "${NOWHERE_LANG:-}" ]]; then validate_language "$NOWHERE_LANG" || die "NOWHERE_LANG must be zh or en."; return; fi
  if [[ -n "${NOWHERE_LANG_VALUE:-}" ]]; then NOWHERE_LANG="$NOWHERE_LANG_VALUE"; validate_language "$NOWHERE_LANG" || die "Saved language must be zh or en."; return; fi
  if [[ "$ASSUME_YES" -eq 1 || ! -t 0 ]]; then NOWHERE_LANG="$(default_language)"; return; fi
  local choice
  echo
  echo "Language / 语言："
  echo "  1) English"
  echo "  2) 简体中文"
  while true; do
    read -r -p "Choose / 请选择 [1]: " choice
    case "${choice:-1}" in 1) NOWHERE_LANG=en; return ;; 2) NOWHERE_LANG=zh; return ;; *) warn "Enter 1 or 2 / 请输入 1 或 2。" ;; esac
  done
}
prompt_value() {
  local english="$1" chinese="$2" default="$3"
  if is_chinese; then read_value "$chinese" "$default"; else read_value "$english" "$default"; fi
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
    die "python3 is required to percent-encode this value."
  fi
}
format_host_for_url() {
  local host="${1:-}"
  [[ -z "$host" ]] && return
  [[ "$host" == \[*\] ]] && { printf '%s' "$host"; return; }
  [[ "$host" == *:* ]] && { printf '[%s]' "$host"; return; }
  printf '%s' "$host"
}
strip_brackets() { local host="${1:-}"; host="${host#[}"; printf '%s' "${host%]}"; }
random_token() { openssl rand -base64 24 | tr '+/' '-_' | tr -d '='; }
detect_public_host() {
  local host=""
  command -v curl >/dev/null 2>&1 && host="$(curl -4fsS --max-time 4 https://api.ipify.org 2>/dev/null || true)"
  [[ -n "$host" ]] || host="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  printf '%s' "$host"
}
read_value() {
  local prompt="$1" default="$2" value
  [[ "$ASSUME_YES" -eq 0 ]] || { printf '%s' "$default"; return; }
  if [[ -n "$default" ]]; then read -r -p "${prompt} [${default}]: " value; else read -r -p "${prompt}: " value; fi
  printf '%s' "${value:-$default}"
}
confirm_default_yes() {
  local answer
  [[ "$ASSUME_YES" -eq 1 ]] && return 0
  read -r -p "$1 [Y/n]: " answer
  [[ -z "$answer" || "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

validate_port() { [[ "$1" =~ ^[0-9]+$ ]] && (( 10#$1 >= 1 && 10#$1 <= 65535 )); }
validate_nonnegative_int() { [[ "$1" =~ ^[0-9]+$ ]]; }
validate_carrier() {
  case "$1" in tcp|tcp4|tcp6|udp|udp4|udp6|none) return 0 ;; *) return 1 ;; esac
}
validate_tcp_carrier() { [[ "$1" == tcp || "$1" == tcp4 || "$1" == tcp6 || "$1" == none ]]; }
validate_udp_carrier() { [[ "$1" == udp || "$1" == udp4 || "$1" == udp6 || "$1" == none ]]; }
validate_policy() { [[ "$1" == tcp || "$1" == udp || "$1" == mix ]]; }
validate_bool() { [[ "$1" == 0 || "$1" == 1 ]]; }
validate_profile() { [[ "$1" == memory || "$1" == balanced || "$1" == throughput ]]; }
validate_duration() { [[ "$1" =~ ^[0-9]+(ms|s|m|h)$ ]]; }
validate_pin() { [[ "$1" == none || "$1" =~ ^[0-9a-f]{64}$ ]]; }
validate_sni() { [[ "$1" == none || "$1" =~ ^[A-Za-z0-9.-]+$ ]]; }
validate_socks() {
  local value="$1" endpoint host port
  [[ "$value" == none || -z "$value" ]] && return 0
  [[ "$value" != *[[:space:]]* ]] || return 1
  endpoint="${value##*@}"
  if [[ "$endpoint" == \[*\]:* ]]; then host="${endpoint#\[}"; host="${host%%\]:*}"; port="${endpoint##*\]:}"; else host="${endpoint%:*}"; port="${endpoint##*:}"; fi
  [[ -n "$host" ]] && validate_port "$port"
}
validate_vector_socks() { [[ "$1" != none && -n "$1" ]] && validate_socks "$1"; }
carrier_for_policy() { [[ "$1" == tcp ]] && [[ "$NOWHERE_TCP_CARRIER" != none ]] || [[ "$1" == udp ]] && [[ "$NOWHERE_UDP_CARRIER" != none ]]; }
validate_policy_for_endpoint() {
  local up="$1" down="$2"
  validate_policy "$up" && validate_policy "$down" || return 1
  [[ "$up" != mix && "$down" != mix ]] || [[ "$NOWHERE_TCP_CARRIER" != none && "$NOWHERE_UDP_CARRIER" != none ]] || return 1
  [[ "$up" == mix ]] || carrier_for_policy "$up" || return 1
  [[ "$down" == mix ]] || carrier_for_policy "$down" || return 1
}
normalize_client() { case "$1" in anywhere|vector|both) printf '%s' "$1" ;; *) return 1 ;; esac; }
client_label() { case "$1" in anywhere) printf 'Anywhere' ;; vector) printf 'Native Vector' ;; both) printf 'Anywhere + Native Vector' ;; esac; }

validate_release_version() {
  local version="${1#v}" major
  [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9._-]+)?$ ]] || return 1
  version="${version%%-*}"; IFS=. read -r major _ <<<"$version"
  (( 10#$major >= 2 ))
}
require_supported_version() { validate_release_version "$1" || die "Only Nowhere releases v2.0.0 and later are supported."; }
validate_morph_tcp_prelude() { [[ "$1" == low7 || "$1" == full8 ]]; }
version_at_least() {
  local version="${1#v}" minimum="${2#v}" version_major version_minor version_patch minimum_major minimum_minor minimum_patch value threshold
  version="${version%%-*}"; minimum="${minimum%%-*}"
  IFS=. read -r version_major version_minor version_patch <<<"$version"
  IFS=. read -r minimum_major minimum_minor minimum_patch <<<"$minimum"
  for value in "$version_major:$minimum_major" "$version_minor:$minimum_minor" "$version_patch:$minimum_patch"; do
    threshold="${value#*:}"; value="${value%%:*}"
    (( 10#$value > 10#$threshold )) && return 0
    (( 10#$value < 10#$threshold )) && return 1
  done
  return 0
}
is_morph_upgrade_boundary() {
  [[ "${NOWHERE_MORPH_VALUE:-$DEFAULT_MORPH}" == 1 ]] || return 1
  version_at_least "$2" v2.1.0 && ! version_at_least "$1" v2.1.0
}
confirm_morph_upgrade() {
  local current="$1" selected="$2" answer
  is_morph_upgrade_boundary "$current" "$selected" || return 0
  warn "Morph protocol changes in v2.1 are incompatible with v2.0.x Morph peers."
  warn "Upgrade every client, native next hop, and Vector node using morph=1 before restarting this Portal."
  if [[ "$ALLOW_MORPH_BREAKING_UPGRADE" -eq 1 ]]; then
    warn "Proceeding because --allow-morph-breaking-upgrade was supplied."
    return 0
  fi
  [[ -t 0 ]] || die "Refusing non-interactive Morph upgrade. Add --allow-morph-breaking-upgrade after coordinating peer upgrades."
  read -r -p "Type UPGRADE to continue: " answer
  [[ "$answer" == UPGRADE ]] || { warn "Update cancelled."; return 1; }
}
validate_config() {
  require_supported_version "$NOWHERE_VERSION"
  NOWHERE_CLIENT="$(normalize_client "$NOWHERE_CLIENT")" || die "NOWHERE_CLIENT must be anywhere, vector, or both."
  [[ -n "$NOWHERE_KEY" && "${#NOWHERE_KEY}" -le 255 ]] || die "NOWHERE_KEY must contain 1..255 characters."
  validate_tcp_carrier "$NOWHERE_TCP_CARRIER" || die "NOWHERE_TCP_CARRIER must be tcp, tcp4, tcp6, or none."
  validate_udp_carrier "$NOWHERE_UDP_CARRIER" || die "NOWHERE_UDP_CARRIER must be udp, udp4, udp6, or none."
  [[ "$NOWHERE_TCP_CARRIER" != none || "$NOWHERE_UDP_CARRIER" != none ]] || die "Enable at least one carrier."
  [[ "$NOWHERE_TCP_CARRIER" == none ]] || validate_port "$NOWHERE_TCP_PORT" || die "Invalid TCP port."
  [[ "$NOWHERE_UDP_CARRIER" == none ]] || validate_port "$NOWHERE_UDP_PORT" || die "Invalid UDP port."
  [[ "$NOWHERE_TLS" == 1 || "$NOWHERE_TLS" == 2 ]] || die "NOWHERE_TLS must be 1 or 2."
  validate_bool "$NOWHERE_MORPH" || die "NOWHERE_MORPH must be 0 or 1."
  validate_language "$NOWHERE_LANG" || die "NOWHERE_LANG must be zh or en."
  validate_morph_tcp_prelude "$NOWHERE_MORPH_TCP_PRELUDE" || die "NOWHERE_MORPH_TCP_PRELUDE must be low7 or full8."
  validate_nonnegative_int "$NOWHERE_RATE" && validate_nonnegative_int "$NOWHERE_ETAR" || die "Rate limits must be non-negative integers."
  validate_socks "$NOWHERE_SOCKS" || die "Invalid NOWHERE_SOCKS value."
  [[ "$NOWHERE_LOG" =~ ^(none|debug|info|warn|error|event)$ ]] || die "Invalid log level."
  validate_profile "$NOWHERE_TRANSPORT_MEMORY_PROFILE" || die "Invalid transport memory profile."
  validate_duration "$NOWHERE_MIX_FALLBACK_TIMEOUT" || die "Invalid mix fallback timeout."
  validate_duration "$NOWHERE_TELEMETRY_INTERVAL" || die "Invalid telemetry interval."
  if [[ "$NOWHERE_TLS" == 2 ]]; then
    [[ -n "$NOWHERE_CRT" && -n "$NOWHERE_TLS_KEY" ]] || die "tls=2 requires crt and key paths."
    [[ -f "$NOWHERE_CRT" && -f "$NOWHERE_TLS_KEY" ]] || die "Certificate or private-key file does not exist."
  fi
  if [[ "$NOWHERE_NEXT" != none ]]; then
    [[ "$NOWHERE_SOCKS" == none ]] || die "Portal next and SOCKS outbound paths are mutually exclusive."
    [[ "$NOWHERE_NEXT" == *@* ]] || die "NOWHERE_NEXT must be key@host:port or an explicit carrier endpoint."
    validate_policy_for_endpoint "$NOWHERE_NEXT_UP" "$NOWHERE_NEXT_DOWN" || die "Invalid next route policy for enabled carriers."
    validate_bool "$NOWHERE_NEXT_MUX" && validate_sni "$NOWHERE_NEXT_SNI" && validate_pin "$NOWHERE_NEXT_PIN" || die "Invalid next Mux, SNI, or pin."
  fi
  if [[ "$NOWHERE_CLIENT" == vector || "$NOWHERE_CLIENT" == both ]]; then
    validate_policy_for_endpoint "$NOWHERE_VECTOR_UP" "$NOWHERE_VECTOR_DOWN" || die "Invalid Vector route policy for enabled carriers."
    validate_bool "$NOWHERE_VECTOR_MUX" && validate_sni "$NOWHERE_VECTOR_SNI" && validate_pin "$NOWHERE_VECTOR_PIN" || die "Invalid Vector Mux, SNI, or pin."
    validate_vector_socks "$NOWHERE_VECTOR_SOCKS" || die "Invalid Vector SOCKS listener."
    validate_nonnegative_int "$NOWHERE_VECTOR_RATE" && validate_nonnegative_int "$NOWHERE_VECTOR_ETAR" || die "Vector rate limits must be non-negative integers."
    [[ "$NOWHERE_VECTOR_LOG" =~ ^(none|debug|info|warn|error|event)$ ]] || die "Invalid Vector log level."
  fi
}

build_endpoint() {
  local host="$1" tcp_carrier="$2" tcp_port="$3" udp_carrier="$4" udp_port="$5"
  if [[ "$tcp_carrier" != none && "$udp_carrier" != none && "$tcp_carrier" == tcp && "$udp_carrier" == udp && "$tcp_port" == "$udp_port" ]]; then
    printf '%s:%s' "$host" "$tcp_port"
  elif [[ "$tcp_carrier" != none && "$udp_carrier" != none ]]; then
    printf '%s/%s:%s/%s:%s' "$host" "$tcp_carrier" "$tcp_port" "$udp_carrier" "$udp_port"
  elif [[ "$tcp_carrier" != none ]]; then
    printf '%s/%s:%s' "$host" "$tcp_carrier" "$tcp_port"
  else
    printf '%s/%s:%s' "$host" "$udp_carrier" "$udp_port"
  fi
}
carrier_without_family() {
  case "$1" in tcp4|tcp6) printf tcp ;; udp4|udp6) printf udp ;; *) printf '%s' "$1" ;; esac
}
build_portal_url() {
  local key host query endpoint
  key="$(urlencode "$NOWHERE_KEY")"
  host="$(format_host_for_url "$NOWHERE_LISTEN_HOST")"
  [[ -n "$host" ]] || host="*"
  endpoint="$(build_endpoint "$host" "$NOWHERE_TCP_CARRIER" "$NOWHERE_TCP_PORT" "$NOWHERE_UDP_CARRIER" "$NOWHERE_UDP_PORT")"
  query="tls=${NOWHERE_TLS}&morph=${NOWHERE_MORPH}"
  [[ "$NOWHERE_RATE" == 0 ]] || query="${query}&rate=${NOWHERE_RATE}"
  [[ "$NOWHERE_ETAR" == 0 ]] || query="${query}&etar=${NOWHERE_ETAR}"
  [[ "$NOWHERE_DIAL" == auto ]] || query="${query}&dial=$(urlencode "$NOWHERE_DIAL")"
  [[ "$NOWHERE_SOCKS" == none ]] || query="${query}&socks=$(urlencode "$NOWHERE_SOCKS")"
  if [[ "$NOWHERE_NEXT" != none ]]; then
    query="${query}&next=$(urlencode "$NOWHERE_NEXT")&up=${NOWHERE_NEXT_UP}&down=${NOWHERE_NEXT_DOWN}&mux=${NOWHERE_NEXT_MUX}"
    query="${query}&sni=$(urlencode "$NOWHERE_NEXT_SNI")&pin=$(urlencode "$NOWHERE_NEXT_PIN")"
  fi
  [[ "$NOWHERE_TLS" != 2 ]] || query="${query}&crt=$(urlencode "$NOWHERE_CRT")&key=$(urlencode "$NOWHERE_TLS_KEY")"
  [[ "$NOWHERE_LOG" == "$DEFAULT_LOG" ]] || query="${query}&log=${NOWHERE_LOG}"
  printf 'portal://%s@%s?%s' "$key" "$endpoint" "$query"
}
build_vector_query() {
  local up="${NOWHERE_VECTOR_UP_VALUE:-tcp}" down="${NOWHERE_VECTOR_DOWN_VALUE:-tcp}" mux="${NOWHERE_VECTOR_MUX_VALUE:-$DEFAULT_MUX}"
  local sni="${NOWHERE_VECTOR_SNI_VALUE:-$DEFAULT_SNI}" pin="${NOWHERE_VECTOR_PIN_VALUE:-$DEFAULT_PIN}" morph="${NOWHERE_MORPH_VALUE:-$DEFAULT_MORPH}"
  local socks="${NOWHERE_VECTOR_SOCKS_VALUE:-$DEFAULT_VECTOR_SOCKS}" rate="${NOWHERE_VECTOR_RATE_VALUE:-0}" etar="${NOWHERE_VECTOR_ETAR_VALUE:-0}" log="${NOWHERE_VECTOR_LOG_VALUE:-$DEFAULT_LOG}"
  local query="up=${up}&down=${down}&mux=${mux}"
  query="${query}&sni=$(urlencode "$sni")&pin=$(urlencode "$pin")"
  query="${query}&morph=${morph}&socks=$(urlencode "$socks")"
  [[ "$rate" == 0 ]] || query="${query}&rate=${rate}"
  [[ "$etar" == 0 ]] || query="${query}&etar=${etar}"
  [[ "$log" == "$DEFAULT_LOG" ]] || query="${query}&log=${log}"
  printf '%s' "$query"
}
build_anywhere_query() {
  local up="$1" down="$2"
  printf 'up=%s&down=%s&morph=%s&mux=%s' "$up" "$down" "${NOWHERE_MORPH_VALUE:-$DEFAULT_MORPH}" "${NOWHERE_VECTOR_MUX_VALUE:-$DEFAULT_MUX}"
}

configure_values() {
  load_config
  local generated_key detected_host default_tls path
  resolve_language
  generated_key="$(random_token)"; detected_host="$(detect_public_host)"
  NOWHERE_VERSION="${NOWHERE_VERSION:-${NOWHERE_VERSION_VALUE:-$DEFAULT_VERSION}}"
  require_supported_version "$NOWHERE_VERSION"
  NOWHERE_CLIENT="${NOWHERE_CLIENT:-${NOWHERE_CLIENT_VALUE:-$DEFAULT_CLIENT}}"
  NOWHERE_PUBLIC_HOST="${NOWHERE_PUBLIC_HOST:-${NOWHERE_PUBLIC_HOST_VALUE:-$detected_host}}"
  NOWHERE_LISTEN_HOST="${NOWHERE_LISTEN_HOST:-${NOWHERE_LISTEN_HOST_VALUE:-}}"
  NOWHERE_KEY="${NOWHERE_KEY:-${NOWHERE_KEY_VALUE:-$generated_key}}"
  NOWHERE_TCP_CARRIER="${NOWHERE_TCP_CARRIER:-${NOWHERE_TCP_CARRIER_VALUE:-$DEFAULT_TCP_CARRIER}}"
  NOWHERE_TCP_PORT="${NOWHERE_TCP_PORT:-${NOWHERE_TCP_PORT_VALUE:-$DEFAULT_PORT}}"
  NOWHERE_UDP_CARRIER="${NOWHERE_UDP_CARRIER:-${NOWHERE_UDP_CARRIER_VALUE:-$DEFAULT_UDP_CARRIER}}"
  NOWHERE_UDP_PORT="${NOWHERE_UDP_PORT:-${NOWHERE_UDP_PORT_VALUE:-$DEFAULT_PORT}}"
  NOWHERE_CRT="${NOWHERE_CRT:-${NOWHERE_CRT_VALUE:-}}"; NOWHERE_TLS_KEY="${NOWHERE_TLS_KEY:-${NOWHERE_TLS_KEY_VALUE:-}}"
  default_tls="$DEFAULT_TLS"; [[ -n "$NOWHERE_CRT$NOWHERE_TLS_KEY" ]] && default_tls=2
  NOWHERE_TLS="${NOWHERE_TLS:-${NOWHERE_TLS_VALUE:-$default_tls}}"
  NOWHERE_MORPH="${NOWHERE_MORPH:-${NOWHERE_MORPH_VALUE:-$DEFAULT_MORPH}}"
  NOWHERE_MORPH_TCP_PRELUDE="${NOWHERE_MORPH_TCP_PRELUDE:-${NOWHERE_MORPH_TCP_PRELUDE_VALUE:-${NOW_MORPH_TCP_PRELUDE:-$DEFAULT_MORPH_TCP_PRELUDE}}}"
  NOWHERE_RATE="${NOWHERE_RATE:-${NOWHERE_RATE_VALUE:-0}}"; NOWHERE_ETAR="${NOWHERE_ETAR:-${NOWHERE_ETAR_VALUE:-0}}"
  NOWHERE_DIAL="${NOWHERE_DIAL:-${NOWHERE_DIAL_VALUE:-auto}}"; NOWHERE_SOCKS="${NOWHERE_SOCKS:-${NOWHERE_SOCKS_VALUE:-$DEFAULT_SOCKS}}"
  NOWHERE_NEXT="${NOWHERE_NEXT:-${NOWHERE_NEXT_VALUE:-none}}"; NOWHERE_NEXT_UP="${NOWHERE_NEXT_UP:-${NOWHERE_NEXT_UP_VALUE:-tcp}}"; NOWHERE_NEXT_DOWN="${NOWHERE_NEXT_DOWN:-${NOWHERE_NEXT_DOWN_VALUE:-tcp}}"
  NOWHERE_NEXT_MUX="${NOWHERE_NEXT_MUX:-${NOWHERE_NEXT_MUX_VALUE:-$DEFAULT_MUX}}"; NOWHERE_NEXT_SNI="${NOWHERE_NEXT_SNI:-${NOWHERE_NEXT_SNI_VALUE:-$DEFAULT_SNI}}"; NOWHERE_NEXT_PIN="${NOWHERE_NEXT_PIN:-${NOWHERE_NEXT_PIN_VALUE:-$DEFAULT_PIN}}"
  NOWHERE_VECTOR_UP="${NOWHERE_VECTOR_UP:-${NOWHERE_VECTOR_UP_VALUE:-tcp}}"; NOWHERE_VECTOR_DOWN="${NOWHERE_VECTOR_DOWN:-${NOWHERE_VECTOR_DOWN_VALUE:-tcp}}"
  NOWHERE_VECTOR_MUX="${NOWHERE_VECTOR_MUX:-${NOWHERE_VECTOR_MUX_VALUE:-$DEFAULT_MUX}}"; NOWHERE_VECTOR_SOCKS="${NOWHERE_VECTOR_SOCKS:-${NOWHERE_VECTOR_SOCKS_VALUE:-$DEFAULT_VECTOR_SOCKS}}"
  NOWHERE_VECTOR_SNI="${NOWHERE_VECTOR_SNI:-${NOWHERE_VECTOR_SNI_VALUE:-$DEFAULT_SNI}}"; NOWHERE_VECTOR_PIN="${NOWHERE_VECTOR_PIN:-${NOWHERE_VECTOR_PIN_VALUE:-$DEFAULT_PIN}}"
  NOWHERE_VECTOR_RATE="${NOWHERE_VECTOR_RATE:-${NOWHERE_VECTOR_RATE_VALUE:-0}}"; NOWHERE_VECTOR_ETAR="${NOWHERE_VECTOR_ETAR:-${NOWHERE_VECTOR_ETAR_VALUE:-0}}"; NOWHERE_VECTOR_LOG="${NOWHERE_VECTOR_LOG:-${NOWHERE_VECTOR_LOG_VALUE:-$DEFAULT_LOG}}"
  NOWHERE_LOG="${NOWHERE_LOG:-${NOWHERE_LOG_VALUE:-$DEFAULT_LOG}}"; NOWHERE_TRANSPORT_MEMORY_PROFILE="${NOWHERE_TRANSPORT_MEMORY_PROFILE:-${NOWHERE_TRANSPORT_MEMORY_PROFILE_VALUE:-${NOW_TRANSPORT_MEMORY_PROFILE:-$DEFAULT_TRANSPORT_MEMORY_PROFILE}}}"
  NOWHERE_MIX_FALLBACK_TIMEOUT="${NOWHERE_MIX_FALLBACK_TIMEOUT:-${NOWHERE_MIX_FALLBACK_TIMEOUT_VALUE:-${NOW_MIX_FALLBACK_TIMEOUT:-$DEFAULT_MIX_FALLBACK_TIMEOUT}}}"
  NOWHERE_TELEMETRY_INTERVAL="${NOWHERE_TELEMETRY_INTERVAL:-${NOWHERE_TELEMETRY_INTERVAL_VALUE:-${NOW_TELEMETRY_INTERVAL:-$DEFAULT_TELEMETRY_INTERVAL}}}"

  if [[ "$ASSUME_YES" -eq 0 ]]; then
    is_chinese && info "Nowhere 配置向导。直接回车保留默认值。" || info "Nowhere configuration wizard. Press Enter to keep defaults."
    NOWHERE_CLIENT="$(prompt_value "Client output anywhere/vector/both" "客户端输出 anywhere/vector/both" "$NOWHERE_CLIENT")"
    NOWHERE_PUBLIC_HOST="$(prompt_value "Public domain/IP" "公网域名或 IP" "$NOWHERE_PUBLIC_HOST")"; NOWHERE_LISTEN_HOST="$(prompt_value "Listen host, empty means wildcard" "监听地址，留空监听全部地址" "$NOWHERE_LISTEN_HOST")"
    NOWHERE_TCP_CARRIER="$(prompt_value "TCP carrier tcp/tcp4/tcp6/none" "TCP 载体 tcp/tcp4/tcp6/none" "$NOWHERE_TCP_CARRIER")"
    [[ "$NOWHERE_TCP_CARRIER" == none ]] || NOWHERE_TCP_PORT="$(prompt_value "TCP port" "TCP 端口" "$NOWHERE_TCP_PORT")"
    NOWHERE_UDP_CARRIER="$(prompt_value "UDP carrier udp/udp4/udp6/none" "UDP 载体 udp/udp4/udp6/none" "$NOWHERE_UDP_CARRIER")"
    [[ "$NOWHERE_UDP_CARRIER" == none ]] || NOWHERE_UDP_PORT="$(prompt_value "UDP port" "UDP 端口" "$NOWHERE_UDP_PORT")"
    NOWHERE_KEY="$(prompt_value "Shared Key" "共享密钥" "$NOWHERE_KEY")"; NOWHERE_TLS="$(prompt_value "TLS 1=self-signed, 2=PEM" "TLS 1=自签证书，2=PEM 证书" "$NOWHERE_TLS")"
    if [[ "$NOWHERE_TLS" == 2 ]]; then NOWHERE_CRT="$(prompt_value "Certificate chain absolute path" "证书链绝对路径" "$NOWHERE_CRT")"; NOWHERE_TLS_KEY="$(prompt_value "Private key absolute path" "私钥绝对路径" "$NOWHERE_TLS_KEY")"; fi
    NOWHERE_MORPH="$(prompt_value "Morph 0=off, 1=ChaCha20 transform" "Morph 0=关闭，1=ChaCha20 变换" "$NOWHERE_MORPH")"
    [[ "$NOWHERE_MORPH" != 1 ]] || NOWHERE_MORPH_TCP_PRELUDE="$(prompt_value "TCP Morph prelude low7/full8 (native next only)" "TCP Morph 前导 low7/full8（仅原生 next）" "$NOWHERE_MORPH_TCP_PRELUDE")"
    NOWHERE_RATE="$(prompt_value "Rate Mbps, 0=unlimited" "限速 Mbps，0=不限速" "$NOWHERE_RATE")"; NOWHERE_ETAR="$(prompt_value "Etar Mbps, 0=unlimited" "Etar Mbps，0=不限速" "$NOWHERE_ETAR")"
    NOWHERE_DIAL="$(prompt_value "Outbound source IP, auto=system default" "出站源 IP，auto=系统默认" "$NOWHERE_DIAL")"; path="$(prompt_value "Outbound path direct/socks/next" "出站路径 direct/socks/next" "$([[ "$NOWHERE_NEXT" != none ]] && printf next || [[ "$NOWHERE_SOCKS" != none ]] && printf socks || printf direct)")"
    case "$path" in direct) NOWHERE_SOCKS=none; NOWHERE_NEXT=none ;; socks) NOWHERE_NEXT=none; NOWHERE_SOCKS="$(prompt_value "Outbound SOCKS5" "出站 SOCKS5" "$NOWHERE_SOCKS")" ;; next) NOWHERE_SOCKS=none; NOWHERE_NEXT="$(prompt_value "Next key@endpoint" "下一跳 key@endpoint" "$NOWHERE_NEXT")"; NOWHERE_NEXT_UP="$(prompt_value "Next up tcp/udp/mix" "下一跳上行 tcp/udp/mix" "$NOWHERE_NEXT_UP")"; NOWHERE_NEXT_DOWN="$(prompt_value "Next down tcp/udp/mix" "下一跳下行 tcp/udp/mix" "$NOWHERE_NEXT_DOWN")"; NOWHERE_NEXT_MUX="$(prompt_value "Next Mux 0/1" "下一跳 Mux 0/1" "$NOWHERE_NEXT_MUX")"; NOWHERE_NEXT_SNI="$(prompt_value "Next SNI/none" "下一跳 SNI/none" "$NOWHERE_NEXT_SNI")"; NOWHERE_NEXT_PIN="$(prompt_value "Next certificate pin/none" "下一跳证书 Pin/none" "$NOWHERE_NEXT_PIN")" ;; *) die "Outbound path must be direct, socks, or next." ;; esac
    NOWHERE_LOG="$(prompt_value "Log level" "日志级别" "$NOWHERE_LOG")"; NOWHERE_TRANSPORT_MEMORY_PROFILE="$(prompt_value "Transport memory memory/balanced/throughput" "传输内存 memory/balanced/throughput" "$NOWHERE_TRANSPORT_MEMORY_PROFILE")"; NOWHERE_MIX_FALLBACK_TIMEOUT="$(prompt_value "Mix fallback timeout" "Mix 回退超时" "$NOWHERE_MIX_FALLBACK_TIMEOUT")"; NOWHERE_TELEMETRY_INTERVAL="$(prompt_value "TUI telemetry interval" "TUI 遥测间隔" "$NOWHERE_TELEMETRY_INTERVAL")"
    if [[ "$NOWHERE_CLIENT" == vector || "$NOWHERE_CLIENT" == both ]]; then NOWHERE_VECTOR_UP="$(prompt_value "Vector up tcp/udp/mix" "Vector 上行 tcp/udp/mix" "$NOWHERE_VECTOR_UP")"; NOWHERE_VECTOR_DOWN="$(prompt_value "Vector down tcp/udp/mix" "Vector 下行 tcp/udp/mix" "$NOWHERE_VECTOR_DOWN")"; NOWHERE_VECTOR_MUX="$(prompt_value "Vector Mux 0/1" "Vector Mux 0/1" "$NOWHERE_VECTOR_MUX")"; NOWHERE_VECTOR_SOCKS="$(prompt_value "Vector local SOCKS5" "Vector 本地 SOCKS5" "$NOWHERE_VECTOR_SOCKS")"; NOWHERE_VECTOR_SNI="$(prompt_value "Vector SNI/none" "Vector SNI/none" "$NOWHERE_VECTOR_SNI")"; NOWHERE_VECTOR_PIN="$(prompt_value "Vector certificate pin/none" "Vector 证书 Pin/none" "$NOWHERE_VECTOR_PIN")"; NOWHERE_VECTOR_RATE="$(prompt_value "Vector rate Mbps, 0=unlimited" "Vector 限速 Mbps，0=不限速" "$NOWHERE_VECTOR_RATE")"; NOWHERE_VECTOR_ETAR="$(prompt_value "Vector etar Mbps, 0=unlimited" "Vector Etar Mbps，0=不限速" "$NOWHERE_VECTOR_ETAR")"; NOWHERE_VECTOR_LOG="$(prompt_value "Vector log level" "Vector 日志级别" "$NOWHERE_VECTOR_LOG")"; fi
  fi
  validate_config
  NOWHERE_PORTAL="$(build_portal_url)"
}

save_config() {
  install -d -m 700 "$CONFIG_DIR"
  cat >"$CONFIG_FILE" <<EOF
NOWHERE_PORTAL=$(env_quote "$NOWHERE_PORTAL")
NOWHERE_LANG_VALUE=$(env_quote "$NOWHERE_LANG")
NOWHERE_VERSION_VALUE=$(env_quote "$NOWHERE_VERSION")
NOWHERE_CLIENT_VALUE=$(env_quote "$NOWHERE_CLIENT")
NOWHERE_PUBLIC_HOST_VALUE=$(env_quote "$NOWHERE_PUBLIC_HOST")
NOWHERE_LISTEN_HOST_VALUE=$(env_quote "$NOWHERE_LISTEN_HOST")
NOWHERE_KEY_VALUE=$(env_quote "$NOWHERE_KEY")
NOWHERE_TCP_CARRIER_VALUE=$(env_quote "$NOWHERE_TCP_CARRIER")
NOWHERE_TCP_PORT_VALUE=$(env_quote "$NOWHERE_TCP_PORT")
NOWHERE_UDP_CARRIER_VALUE=$(env_quote "$NOWHERE_UDP_CARRIER")
NOWHERE_UDP_PORT_VALUE=$(env_quote "$NOWHERE_UDP_PORT")
NOWHERE_TLS_VALUE=$(env_quote "$NOWHERE_TLS")
NOWHERE_CRT_VALUE=$(env_quote "$NOWHERE_CRT")
NOWHERE_TLS_KEY_VALUE=$(env_quote "$NOWHERE_TLS_KEY")
NOWHERE_MORPH_VALUE=$(env_quote "$NOWHERE_MORPH")
NOWHERE_MORPH_TCP_PRELUDE_VALUE=$(env_quote "$NOWHERE_MORPH_TCP_PRELUDE")
NOW_MORPH_TCP_PRELUDE=$(env_quote "$NOWHERE_MORPH_TCP_PRELUDE")
NOWHERE_RATE_VALUE=$(env_quote "$NOWHERE_RATE")
NOWHERE_ETAR_VALUE=$(env_quote "$NOWHERE_ETAR")
NOWHERE_DIAL_VALUE=$(env_quote "$NOWHERE_DIAL")
NOWHERE_SOCKS_VALUE=$(env_quote "$NOWHERE_SOCKS")
NOWHERE_NEXT_VALUE=$(env_quote "$NOWHERE_NEXT")
NOWHERE_NEXT_UP_VALUE=$(env_quote "$NOWHERE_NEXT_UP")
NOWHERE_NEXT_DOWN_VALUE=$(env_quote "$NOWHERE_NEXT_DOWN")
NOWHERE_NEXT_MUX_VALUE=$(env_quote "$NOWHERE_NEXT_MUX")
NOWHERE_NEXT_SNI_VALUE=$(env_quote "$NOWHERE_NEXT_SNI")
NOWHERE_NEXT_PIN_VALUE=$(env_quote "$NOWHERE_NEXT_PIN")
NOWHERE_VECTOR_UP_VALUE=$(env_quote "$NOWHERE_VECTOR_UP")
NOWHERE_VECTOR_DOWN_VALUE=$(env_quote "$NOWHERE_VECTOR_DOWN")
NOWHERE_VECTOR_MUX_VALUE=$(env_quote "$NOWHERE_VECTOR_MUX")
NOWHERE_VECTOR_SOCKS_VALUE=$(env_quote "$NOWHERE_VECTOR_SOCKS")
NOWHERE_VECTOR_SNI_VALUE=$(env_quote "$NOWHERE_VECTOR_SNI")
NOWHERE_VECTOR_PIN_VALUE=$(env_quote "$NOWHERE_VECTOR_PIN")
NOWHERE_VECTOR_RATE_VALUE=$(env_quote "$NOWHERE_VECTOR_RATE")
NOWHERE_VECTOR_ETAR_VALUE=$(env_quote "$NOWHERE_VECTOR_ETAR")
NOWHERE_VECTOR_LOG_VALUE=$(env_quote "$NOWHERE_VECTOR_LOG")
NOWHERE_LOG_VALUE=$(env_quote "$NOWHERE_LOG")
NOWHERE_TRANSPORT_MEMORY_PROFILE_VALUE=$(env_quote "$NOWHERE_TRANSPORT_MEMORY_PROFILE")
NOW_TRANSPORT_MEMORY_PROFILE=$(env_quote "$NOWHERE_TRANSPORT_MEMORY_PROFILE")
NOWHERE_MIX_FALLBACK_TIMEOUT_VALUE=$(env_quote "$NOWHERE_MIX_FALLBACK_TIMEOUT")
NOW_MIX_FALLBACK_TIMEOUT=$(env_quote "$NOWHERE_MIX_FALLBACK_TIMEOUT")
NOWHERE_TELEMETRY_INTERVAL_VALUE=$(env_quote "$NOWHERE_TELEMETRY_INTERVAL")
NOW_TELEMETRY_INTERVAL=$(env_quote "$NOWHERE_TELEMETRY_INTERVAL")
EOF
  chmod 600 "$CONFIG_FILE"
}

detect_asset() {
  local arch libc=gnu
  case "$(uname -m)" in x86_64|amd64) arch=x86_64 ;; aarch64|arm64) arch=aarch64 ;; *) die "Unsupported architecture: $(uname -m)" ;; esac
  command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl && libc=musl
  printf 'nowhere-%s-unknown-linux-%s.tar.gz' "$arch" "$libc"
}
install_binary() {
  local version="$1" asset url tmpdir binary
  require_supported_version "$version"; command -v curl >/dev/null 2>&1 || die "curl is required."; command -v tar >/dev/null 2>&1 || die "tar is required."
  asset="$(detect_asset)"; url="https://github.com/${REPO}/releases/download/${version}/${asset}"; tmpdir="$(mktemp -d)"; trap 'rm -rf "${tmpdir:-}"' RETURN
  info "Downloading ${asset} from ${REPO} ${version}..."; curl -fL --retry 3 --connect-timeout 10 -o "${tmpdir}/${asset}" "$url"; tar -xzf "${tmpdir}/${asset}" -C "$tmpdir"
  binary="$(find "$tmpdir" -type f -name nowhere -perm -u+x | head -n 1)"; [[ -n "$binary" ]] || binary="$(find "$tmpdir" -type f -name nowhere | head -n 1)"; [[ -n "$binary" ]] || die "Nowhere binary not found in release archive."
  install -m 755 "$binary" "$BIN_PATH"; rm -rf "$tmpdir"; trap - RETURN
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
}
service_cmd() { require_root; require_systemd; systemctl "$1" "$SERVICE_NAME"; }

install_qrencode() {
  command -v qrencode >/dev/null 2>&1 && return 0
  if command -v apt-get >/dev/null 2>&1; then DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq qrencode
  elif command -v dnf >/dev/null 2>&1; then dnf install -y qrencode
  elif command -v yum >/dev/null 2>&1; then yum install -y qrencode
  elif command -v apk >/dev/null 2>&1; then apk add --no-cache qrencode
  else warn "qrencode is unavailable; QR output skipped."; return 1; fi
}
print_qr_code() { [[ -n "$1" ]] || return; install_qrencode || return; echo; echo "QR code (Anywhere nowhere:// link):"; qrencode -t ANSIUTF8 -m 1 -s 1 "$1" || warn "QR rendering failed."; }

print_links() {
  require_root; load_config; [[ -n "${NOWHERE_KEY_VALUE:-}" ]] || die "No configuration found."
  local host endpoint anywhere_endpoint key name base tcp_link udp_link vector_link qr_link=""
  host="${NOWHERE_PUBLIC_HOST_VALUE:-}"; [[ -n "$host" ]] || die "Public host is empty. Reconfigure the service."
  host="$(format_host_for_url "$host")"; endpoint="$(build_endpoint "$host" "$NOWHERE_TCP_CARRIER_VALUE" "$NOWHERE_TCP_PORT_VALUE" "$NOWHERE_UDP_CARRIER_VALUE" "$NOWHERE_UDP_PORT_VALUE")"; anywhere_endpoint="$(build_endpoint "$host" "$(carrier_without_family "$NOWHERE_TCP_CARRIER_VALUE")" "$NOWHERE_TCP_PORT_VALUE" "$(carrier_without_family "$NOWHERE_UDP_CARRIER_VALUE")" "$NOWHERE_UDP_PORT_VALUE")"; key="$(urlencode "$NOWHERE_KEY_VALUE")"; name="$(urlencode "Nowhere VPS")"
  echo; echo "Client output: $(client_label "$NOWHERE_CLIENT_VALUE")"; echo "Release: ${NOWHERE_VERSION_VALUE}"; echo; echo "Portal URL:"; echo "  ${NOWHERE_PORTAL}"; echo
  if [[ "$NOWHERE_CLIENT_VALUE" == vector || "$NOWHERE_CLIENT_VALUE" == both ]]; then
    vector_link="vector://${key}@${endpoint}?$(build_vector_query)"; echo "Native Vector URL:"; echo "  ${vector_link}"; echo; echo "Client command:"; echo "  nowhere '${vector_link}'"; [[ "$NOWHERE_CLIENT_VALUE" == both ]] && echo
  fi
  if [[ "$NOWHERE_CLIENT_VALUE" == anywhere || "$NOWHERE_CLIENT_VALUE" == both ]]; then
    base="nowhere://${key}@${anywhere_endpoint}"
    if [[ "$NOWHERE_TCP_CARRIER_VALUE" != none ]]; then tcp_link="${base}?$(build_anywhere_query tcp tcp)#${name}"; qr_link="$tcp_link"; echo "Anywhere import link (TLS/TCP):"; echo "  ${tcp_link}"; fi
    if [[ "$NOWHERE_UDP_CARRIER_VALUE" != none ]]; then udp_link="${base}?$(build_anywhere_query udp udp)#${name}"; [[ -n "$tcp_link" ]] && echo; [[ -n "$qr_link" ]] || qr_link="$udp_link"; echo "Anywhere import link (QUIC/UDP):"; echo "  ${udp_link}"; fi
    print_qr_code "$qr_link"
    if [[ "$endpoint" != "$anywhere_endpoint" ]]; then
      echo "Note: Anywhere links omit tcp4/tcp6/udp4/udp6 suffixes; Native Vector retains them."
    fi
  fi
  echo; echo "Firewall reminder:"; [[ "$NOWHERE_TCP_CARRIER_VALUE" == none ]] || echo "  Open TCP ${NOWHERE_TCP_PORT_VALUE}"; [[ "$NOWHERE_UDP_CARRIER_VALUE" == none ]] || echo "  Open UDP ${NOWHERE_UDP_PORT_VALUE}"
}

local_tls_probe_host() { local host="${NOWHERE_LISTEN_HOST_VALUE:-}"; [[ -z "$host" || "$host" == '*' || "$host" == 0.0.0.0 || "$host" == :: ]] && printf 127.0.0.1 || strip_brackets "$host"; }
print_tls_fingerprint_from_logs() {
  command -v journalctl >/dev/null 2>&1 || return 1
  journalctl -u "$SERVICE_NAME" -n 300 --no-pager 2>/dev/null |
    sed -nE 's/.*CERT_SHA256\|([A-Fa-f0-9]{64}).*/\1/p' |
    tail -n 1
}
print_tls_fingerprint() {
  require_root; load_config
  [[ "${NOWHERE_TLS_VALUE:-1}" == 1 ]] || { echo "tls=2 uses the supplied certificate; no self-signed fingerprint is needed."; return; }
  local fingerprint output host
  fingerprint="$(print_tls_fingerprint_from_logs || true)"
  [[ -n "$fingerprint" ]] && { echo "Self-signed certificate SHA-256:"; echo "  ${fingerprint}"; return; }
  [[ "${NOWHERE_TCP_CARRIER_VALUE:-none}" != none ]] || { warn "Fingerprint probing needs a TCP carrier."; return 1; }
  command -v openssl >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1 || { warn "openssl and timeout are required."; return 1; }
  host="$(local_tls_probe_host)"
  for _ in 1 2 3 4 5; do output="$(timeout 8 openssl s_client -connect "${host}:${NOWHERE_TCP_PORT_VALUE}" -servername "${NOWHERE_PUBLIC_HOST_VALUE:-localhost}" -alpn nw2 -showcerts </dev/null 2>/dev/null | openssl x509 -noout -fingerprint -sha256 2>/dev/null || true)"; fingerprint="${output#*=}"; [[ -n "$fingerprint" && "$fingerprint" != "$output" ]] && { echo "Self-signed certificate SHA-256:"; echo "  ${fingerprint}"; return; }; sleep 1; done
  warn "Fingerprint unavailable. Check: journalctl -u ${SERVICE_NAME} -n 100 --no-pager"
}

fetch_recent_releases() { curl -fsSL -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/${REPO}/releases?per_page=10" | sed -nE 's/^[[:space:]]*"tag_name":[[:space:]]*"([^"]+)".*/\1/p'; }
choose_release_version() {
  local releases=() item index choice
  while IFS= read -r item; do validate_release_version "$item" && releases+=("$item"); done < <(fetch_recent_releases)
  [[ ${#releases[@]} -gt 0 ]] || die "No supported release found on GitHub."
  echo
  is_chinese && echo "最近的受支持 Nowhere Release：" || echo "Recent supported Nowhere releases:"
  for index in "${!releases[@]}"; do printf ' %2d) %s\n' "$((index + 1))" "${releases[$index]}"; done
  is_chinese && echo "  0) 取消" || echo "  0) Cancel"
  while true; do
    if is_chinese; then read -r -p "请选择版本: " choice; else read -r -p "Choose a version: " choice; fi
    [[ "$choice" == 0 ]] && return 1
    [[ "$choice" =~ ^[0-9]+$ ]] && (( 10#$choice >= 1 && 10#$choice <= ${#releases[@]} )) && { SELECTED_VERSION="${releases[$((10#$choice - 1))]}"; return; }
    is_chinese && warn "请输入 0..${#releases[@]}。" || warn "Enter 0..${#releases[@]}."
  done
}

install_all() { require_root; require_systemd; configure_values; install_binary "$NOWHERE_VERSION"; save_config; write_service; systemctl enable --now "$SERVICE_NAME"; info "Nowhere service enabled and started."; print_links; print_tls_fingerprint || true; }
install_default() { NOWHERE_CLIENT="${NOWHERE_CLIENT:-$DEFAULT_CLIENT}"; [[ "$VERSION_EXPLICIT" -eq 1 ]] || NOWHERE_VERSION="$DEFAULT_VERSION"; install_all; }
install_vector() { NOWHERE_CLIENT=vector; [[ "$VERSION_EXPLICIT" -eq 1 ]] || NOWHERE_VERSION="$DEFAULT_VERSION"; install_all; }
quick_install() { ASSUME_YES=1 install_default; }
configure_all() { require_root; require_systemd; load_config; NOWHERE_VERSION="${NOWHERE_VERSION_VALUE:-$DEFAULT_VERSION}"; configure_values; save_config; write_service; systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1 && systemctl restart "$SERVICE_NAME"; print_links; print_tls_fingerprint || true; }
update_saved_version() { sed -i.bak "s/^NOWHERE_VERSION_VALUE=.*/NOWHERE_VERSION_VALUE=$(env_quote "$1")/" "$CONFIG_FILE"; rm -f "${CONFIG_FILE}.bak"; }
update_saved_language() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  if grep -q '^NOWHERE_LANG_VALUE=' "$CONFIG_FILE"; then
    sed -i.bak "s/^NOWHERE_LANG_VALUE=.*/NOWHERE_LANG_VALUE=$(env_quote "$NOWHERE_LANG")/" "$CONFIG_FILE"
    rm -f "${CONFIG_FILE}.bak"
  else
    printf '\nNOWHERE_LANG_VALUE=%s\n' "$(env_quote "$NOWHERE_LANG")" >>"$CONFIG_FILE"
  fi
}
change_language() { NOWHERE_LANG=""; NOWHERE_LANG_VALUE=""; resolve_language; update_saved_language; }
update_all() { require_root; require_systemd; load_config; [[ -n "${NOWHERE_VERSION_VALUE:-}" ]] || die "No installation config found."; local selected; if [[ "$VERSION_EXPLICIT" -eq 1 ]]; then selected="$NOWHERE_VERSION"; else choose_release_version || return; selected="$SELECTED_VERSION"; fi; require_supported_version "$selected"; confirm_morph_upgrade "$NOWHERE_VERSION_VALUE" "$selected" || return; install_binary "$selected"; update_saved_version "$selected"; systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1 && systemctl restart "$SERVICE_NAME"; info "Nowhere updated to ${selected}."; print_links; print_tls_fingerprint || true; }
update_script() {
  local tmp backup mode
  [[ -f "$SCRIPT_PATH" ]] || die "Cannot update a script run from a pipe. Download it to a file first."
  [[ -w "$SCRIPT_PATH" ]] || die "Current script is not writable: ${SCRIPT_PATH}. Run with sudo or fix permissions."
  command -v curl >/dev/null 2>&1 || die "curl is required to update the script."
  tmp="$(mktemp "${SCRIPT_PATH}.new.XXXXXX")"; trap 'rm -f "${tmp:-}"' RETURN
  is_chinese && info "正在下载最新脚本..." || info "Downloading the latest script..."
  curl -fsSL --retry 3 --connect-timeout 10 -o "$tmp" "$SCRIPT_RAW_URL"
  bash -n "$tmp" || die "Downloaded script failed syntax validation; current script was kept."
  if cmp -s "$tmp" "$SCRIPT_PATH"; then is_chinese && info "当前已是最新脚本。" || info "The deployment script is already up to date."; rm -f "$tmp"; trap - RETURN; return; fi
  mode="$(stat -c '%a' "$SCRIPT_PATH" 2>/dev/null || printf 755)"
  backup="${SCRIPT_PATH}.bak.$(date +%Y%m%d%H%M%S)"
  cp -p "$SCRIPT_PATH" "$backup"
  mv "$tmp" "$SCRIPT_PATH"; chmod "$mode" "$SCRIPT_PATH"; trap - RETURN
  is_chinese && info "脚本已更新，备份文件：${backup}" || info "Script updated. Backup: ${backup}"
}
open_tui() { require_root; [[ -x "$BIN_PATH" ]] || die "Nowhere is not installed."; [[ -t 0 && -t 1 ]] || die "The TUI requires an interactive terminal."; "$BIN_PATH" tui; }
uninstall_all() { require_root; require_systemd; systemctl disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true; rm -f "$SERVICE_FILE" "$BIN_PATH"; systemctl daemon-reload; warn "Kept ${CONFIG_DIR} to preserve configuration and keys."; }

menu() {
  require_root; require_systemd
  load_config; resolve_language; update_saved_language
  while true; do
    if is_chinese; then cat <<'EOF'

==============================
 Nowhere VPS 管理脚本
==============================
  1) 安装/重装（Anywhere）
  2) 安装/重装（原生 Vector）
  3) 快速默认安装（Anywhere）
  4) 修改配置
  5) 指定 Release 安装
  6) 更新 Nowhere 二进制
  7) 启动服务
  8) 停止服务
  9) 重启服务
 10) 查看状态
 11) 打开终端界面
 12) 查看实时日志
 13) 打印客户端链接 / 二维码
 14) 查看 tls=1 证书 SHA-256
 15) 卸载服务
 16) 切换语言
 17) 更新部署脚本
  0) 退出
EOF
    else cat <<'EOF'

==============================
 Nowhere VPS Manager
==============================
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
14) Show tls=1 certificate SHA-256
15) Uninstall
 16) Switch language
 17) Update deployment script
  0) Exit
EOF
    fi
    if is_chinese; then read -r -p "请选择: " choice; else read -r -p "Choose: " choice; fi
    case "$choice" in 1) install_default ;; 2) install_vector ;; 3) quick_install ;; 4) configure_all ;; 5) choose_release_version && { NOWHERE_VERSION="$SELECTED_VERSION"; install_all; } ;; 6) update_all ;; 7) service_cmd start ;; 8) service_cmd stop ;; 9) service_cmd restart ;; 10) service_cmd status ;; 11) open_tui ;; 12) journalctl -u "$SERVICE_NAME" -f ;; 13) print_links ;; 14) print_tls_fingerprint || true ;; 15) uninstall_all ;; 16) change_language ;; 17) update_script ;; 0) exit 0 ;; *) is_chinese && warn "未知选项: ${choice}" || warn "Unknown option: ${choice}" ;; esac
  done
}

case "$ACTION" in
  install|install-anywhere|anywhere) install_default ;;
  install-vector|vector) install_vector ;;
  configure|config) configure_all ;;
  update) update_all ;;
  update-script|script-update|self-update) update_script ;;
  versions|version|releases|release) choose_release_version && { NOWHERE_VERSION="$SELECTED_VERSION"; install_all; } ;;
  start|stop|restart|status) service_cmd "$ACTION" ;;
  tui|dashboard|monitor) open_tui ;;
  logs|log) require_root; journalctl -u "$SERVICE_NAME" -f ;;
  link|links) print_links ;;
  fingerprint|sha256|sha-256) print_tls_fingerprint ;;
  uninstall|remove) uninstall_all ;;
  menu) menu ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
