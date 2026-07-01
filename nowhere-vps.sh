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

ASSUME_YES=0
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
Nowhere VPS one-click installer for Anywhere.

Usage:
  sudo bash nowhere-vps.sh install [--yes] [options]
  sudo bash nowhere-vps.sh configure [options]
  sudo bash nowhere-vps.sh update
  sudo bash nowhere-vps.sh start|stop|restart|status|logs|link
  sudo bash nowhere-vps.sh uninstall

Options:
  --port 2077              Portal listen port
  --key secret             Shared key
  --spec nightfall         Optional protocol spec seed
  --net mix|tcp|udp        Server listener transport
  --tls 1|2                1=self-signed, 2=PEM certificate
  --crt /path/cert.pem     PEM certificate chain for tls=2
  --tls-key /path/key.pem  PEM private key for tls=2
  --public-host host       Domain/IP used in Anywhere import links
  --listen-host host       Bind host; empty means IPv4 and IPv6 wildcard
  --alpn now/1             TLS/QUIC ALPN
  --rate 0                 Client-to-target limit in Mbps, 0 disables
  --etar 0                 Target-to-client limit in Mbps, 0 disables
  --dial auto              Outbound source IP or auto
  --socks none             SOCKS5 outbound proxy: host:port or user:pass@host:port
  --log info               none|debug|info|warn|error|event
  --pool 5                 Anywhere TCP pool size for net=tcp links

Environment variables with the same names are also supported, for example:
  NOWHERE_PORT=443 NOWHERE_NET=mix sudo -E bash nowhere-vps.sh install --yes
EOF
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "Please run as root, for example: sudo bash $0 ${ACTION}"
}

require_systemd() {
  command -v systemctl >/dev/null 2>&1 || die "systemctl is required on this VPS."
  [[ -d /run/systemd/system ]] || warn "systemd does not look active; service commands may fail."
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

validate_config_values() {
  validate_port "$NOWHERE_PORT" || die "Invalid port: ${NOWHERE_PORT}"
  [[ -n "$NOWHERE_KEY" ]] || die "NOWHERE_KEY cannot be empty."
  [[ "${#NOWHERE_KEY}" -le 255 ]] || die "NOWHERE_KEY must be <= 255 characters."
  [[ -z "$NOWHERE_SPEC" || "${#NOWHERE_SPEC}" -le 255 ]] || die "NOWHERE_SPEC must be <= 255 characters."
  [[ -z "$NOWHERE_ALPN" || "${#NOWHERE_ALPN}" -le 255 ]] || die "NOWHERE_ALPN must be <= 255 characters."
  [[ "$NOWHERE_NET" == "mix" || "$NOWHERE_NET" == "tcp" || "$NOWHERE_NET" == "udp" ]] || die "NOWHERE_NET must be mix, tcp, or udp."
  [[ "$NOWHERE_TLS" == "1" || "$NOWHERE_TLS" == "2" ]] || die "NOWHERE_TLS must be 1 or 2."
  validate_nonnegative_int "$NOWHERE_RATE" || die "NOWHERE_RATE must be a non-negative integer."
  validate_nonnegative_int "$NOWHERE_ETAR" || die "NOWHERE_ETAR must be a non-negative integer."
  validate_socks "$NOWHERE_SOCKS" || die "NOWHERE_SOCKS must be none, host:port, or user:pass@host:port. IPv6 endpoints require brackets."
  [[ "$NOWHERE_LOG" == "none" || "$NOWHERE_LOG" == "debug" || "$NOWHERE_LOG" == "info" || "$NOWHERE_LOG" == "warn" || "$NOWHERE_LOG" == "error" || "$NOWHERE_LOG" == "event" ]] || die "Invalid log level: ${NOWHERE_LOG}"
  [[ "$NOWHERE_POOL" =~ ^[0-9]+$ ]] && [[ "$NOWHERE_POOL" -ge 0 ]] && [[ "$NOWHERE_POOL" -le 9 ]] || die "NOWHERE_POOL must be 0..9."
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

  if [[ -n "$NOWHERE_SPEC" ]]; then
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

configure_values() {
  load_config

  local generated_key generated_spec detected_host default_tls
  generated_key="$(random_token 24)"
  generated_spec="$(random_token 12)"
  detected_host="$(detect_public_host)"

  NOWHERE_PORT="${NOWHERE_PORT:-${NOWHERE_PORT_VALUE:-$DEFAULT_PORT}}"
  NOWHERE_KEY="${NOWHERE_KEY:-${NOWHERE_KEY_VALUE:-$generated_key}}"
  NOWHERE_SPEC="${NOWHERE_SPEC:-${NOWHERE_SPEC_VALUE:-$generated_spec}}"
  NOWHERE_NET="${NOWHERE_NET:-${NOWHERE_NET_VALUE:-$DEFAULT_NET}}"
  NOWHERE_ALPN="${NOWHERE_ALPN:-${NOWHERE_ALPN_VALUE:-$DEFAULT_ALPN}}"
  NOWHERE_RATE="${NOWHERE_RATE:-${NOWHERE_RATE_VALUE:-0}}"
  NOWHERE_ETAR="${NOWHERE_ETAR:-${NOWHERE_ETAR_VALUE:-0}}"
  NOWHERE_DIAL="${NOWHERE_DIAL:-${NOWHERE_DIAL_VALUE:-auto}}"
  NOWHERE_SOCKS="${NOWHERE_SOCKS:-${NOWHERE_SOCKS_VALUE:-$DEFAULT_SOCKS}}"
  NOWHERE_LOG="${NOWHERE_LOG:-${NOWHERE_LOG_VALUE:-$DEFAULT_LOG}}"
  NOWHERE_POOL="${NOWHERE_POOL:-${NOWHERE_POOL_VALUE:-$DEFAULT_POOL}}"
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
    info "Configure Nowhere Portal. Press Enter to keep the value in brackets."
    NOWHERE_PUBLIC_HOST="$(read_value "Public domain/IP for Anywhere links" "$NOWHERE_PUBLIC_HOST")"
    NOWHERE_LISTEN_HOST="$(read_value "Listen host, empty = IPv4/IPv6 wildcard" "$NOWHERE_LISTEN_HOST")"
    NOWHERE_PORT="$(read_value "Listen port" "$NOWHERE_PORT")"
    NOWHERE_KEY="$(read_value "Shared key" "$NOWHERE_KEY")"
    NOWHERE_SPEC="$(read_value "Spec seed" "$NOWHERE_SPEC")"
    NOWHERE_NET="$(read_value "Server net (mix/tcp/udp)" "$NOWHERE_NET")"
    NOWHERE_ALPN="$(read_value "ALPN" "$NOWHERE_ALPN")"
    NOWHERE_TLS="$(read_value "TLS mode (1=self-signed, 2=PEM certificate)" "$NOWHERE_TLS")"
    if [[ "$NOWHERE_TLS" == "2" ]]; then
      NOWHERE_CRT="$(read_value "Certificate chain path" "$NOWHERE_CRT")"
      NOWHERE_TLS_KEY="$(read_value "Private key path" "$NOWHERE_TLS_KEY")"
    fi
    NOWHERE_RATE="$(read_value "Client-to-target limit Mbps, 0 disables" "$NOWHERE_RATE")"
    NOWHERE_ETAR="$(read_value "Target-to-client limit Mbps, 0 disables" "$NOWHERE_ETAR")"
    NOWHERE_DIAL="$(read_value "Outbound source IP or auto" "$NOWHERE_DIAL")"
    NOWHERE_SOCKS="$(read_value "SOCKS5 outbound proxy, none/host:port/user:pass@host:port" "$NOWHERE_SOCKS")"
    NOWHERE_LOG="$(read_value "Log level" "$NOWHERE_LOG")"
    NOWHERE_POOL="$(read_value "Anywhere TCP pool for net=tcp links (0..9)" "$NOWHERE_POOL")"
  fi

  validate_config_values
  NOWHERE_PORTAL="$(build_portal_url)"
}

save_config() {
  install -d -m 700 "$CONFIG_DIR"
  cat >"$CONFIG_FILE" <<EOF
NOWHERE_PORTAL=$(env_quote "$NOWHERE_PORTAL")
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

  local asset url tmpdir binary
  asset="$(detect_asset)"
  url="https://github.com/${REPO}/releases/latest/download/${asset}"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  info "Downloading ${asset} from latest ${REPO} release..."
  curl -fL --retry 3 --connect-timeout 10 -o "${tmpdir}/${asset}" "$url"
  tar -xzf "${tmpdir}/${asset}" -C "$tmpdir"
  binary="$(find "$tmpdir" -type f -name nowhere -perm -u+x | head -n 1)"
  if [[ -z "$binary" ]]; then
    binary="$(find "$tmpdir" -type f -name nowhere | head -n 1)"
  fi
  [[ -n "$binary" ]] || die "Could not find nowhere binary in release archive."
  install -m 755 "$binary" "$BIN_PATH"
  info "Installed ${BIN_PATH}"
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

print_links() {
  require_root
  load_config
  [[ -n "${NOWHERE_KEY_VALUE:-}" ]] || die "No config found. Run install or configure first."

  local host host_part encoded_key encoded_name base query udp_link tcp_link
  local import_udp import_tcp
  host="${NOWHERE_PUBLIC_HOST_VALUE:-}"
  [[ -n "$host" ]] || host="$(detect_public_host)"
  [[ -n "$host" ]] || die "Public host is empty. Re-run configure with --public-host."
  host_part="$(format_host_for_url "$host")"
  encoded_key="$(urlencode "$NOWHERE_KEY_VALUE")"
  encoded_name="$(urlencode "Nowhere VPS")"
  base="nowhere://${encoded_key}@${host_part}:${NOWHERE_PORT_VALUE}"

  query="net=udp"
  if [[ -n "${NOWHERE_SPEC_VALUE:-}" ]]; then
    query="${query}&spec=$(urlencode "$NOWHERE_SPEC_VALUE")"
  fi
  if [[ -n "${NOWHERE_ALPN_VALUE:-}" && "$NOWHERE_ALPN_VALUE" != "$DEFAULT_ALPN" ]]; then
    query="${query}&alpn=$(urlencode "$NOWHERE_ALPN_VALUE")"
  fi
  udp_link="${base}?${query}#${encoded_name}"

  query="net=tcp&pool=${NOWHERE_POOL_VALUE:-$DEFAULT_POOL}"
  if [[ -n "${NOWHERE_SPEC_VALUE:-}" ]]; then
    query="${query}&spec=$(urlencode "$NOWHERE_SPEC_VALUE")"
  fi
  if [[ -n "${NOWHERE_ALPN_VALUE:-}" && "$NOWHERE_ALPN_VALUE" != "$DEFAULT_ALPN" ]]; then
    query="${query}&alpn=$(urlencode "$NOWHERE_ALPN_VALUE")"
  fi
  tcp_link="${base}?${query}#${encoded_name}"

  import_udp="anywhere://add-proxy?link=${udp_link}"
  import_tcp="anywhere://add-proxy?link=${tcp_link}"

  echo
  echo "Portal URL:"
  echo "  ${NOWHERE_PORTAL:-}"
  echo
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
    echo
    echo "Anywhere deep link (QUIC/UDP):"
    echo "  ${import_udp}"
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
    echo "  tls=1 uses an ephemeral self-signed certificate. Prefer tls=2 with a valid domain certificate for daily use."
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
  install_binary
  configure_values
  save_config
  write_service
  systemctl enable --now "$SERVICE_NAME"
  info "Nowhere service enabled and started."
  print_links
}

configure_all() {
  require_root
  require_systemd
  configure_values
  save_config
  write_service
  if systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
    systemctl restart "$SERVICE_NAME"
    info "Nowhere service restarted."
  else
    warn "Service is configured but not enabled. Run: systemctl enable --now ${SERVICE_NAME}"
  fi
  print_links
}

update_all() {
  require_root
  require_systemd
  install_binary
  if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
    systemctl restart "$SERVICE_NAME"
  fi
  info "Nowhere binary updated."
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
  while true; do
    cat <<EOF

Nowhere VPS Manager
  1) Install or reinstall
  2) Configure
  3) Update binary
  4) Start service
  5) Stop service
  6) Restart service
  7) Status
  8) Logs
  9) Print Anywhere links
  0) Exit
EOF
    read -r -p "Choose: " choice
    case "$choice" in
      1) install_all ;;
      2) configure_all ;;
      3) update_all ;;
      4) service_cmd start ;;
      5) service_cmd stop ;;
      6) service_cmd restart ;;
      7) service_cmd status ;;
      8) journalctl -u "$SERVICE_NAME" -f ;;
      9) print_links ;;
      0) exit 0 ;;
      *) warn "Unknown choice: ${choice}" ;;
    esac
  done
}

case "$ACTION" in
  install) install_all ;;
  configure|config) configure_all ;;
  update) update_all ;;
  start|stop|restart|status) service_cmd "$ACTION" ;;
  logs|log) require_root; journalctl -u "$SERVICE_NAME" -f ;;
  link|links) print_links ;;
  uninstall|remove) uninstall_all ;;
  menu) menu ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
