#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# n8n Production Deployment with SaltStack + Podman
# Run as root on a fresh Ubuntu/Debian VPS
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# --- Preflight ---
[[ "$(id -u)" -ne 0 ]] && error "Run as root or with sudo"
[[ ! -f /etc/os-release ]] && error "Cannot detect OS"

source /etc/os-release
case "$ID" in
  ubuntu|debian) ;;
  *) warn "Tested on Ubuntu/Debian. YMMV on $ID" ;;
esac

# --- Configuration ---
SALT_ROOT="/srv/salt"
PILLAR_ROOT="/srv/pillar"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_DIR="${N8N_DEPLOY_DIR:-/opt/n8n}"

info "=== n8n Production Deployment ==="
info "Salt states:  $SALT_ROOT"
info "Pillar data:  $PILLAR_ROOT"
info "Deploy dir:   $DEPLOY_DIR"

# --- Generate secrets if not set ---
generate_password() {
  openssl rand -base64 32 | tr -d '=/+' | head -c 40
}

generate_hex() {
  openssl rand -hex 16
}

POSTGRES_PASSWORD="${N8N_POSTGRES_PASSWORD:-$(generate_password)}"
ENCRYPTION_KEY="${N8N_ENCRYPTION_KEY:-$(generate_hex)}"
DOMAIN="${N8N_DOMAIN:-yourdomain.com}"
SUBDOMAIN="${N8N_SUBDOMAIN:-n8n}"
TIMEZONE="${N8N_TIMEZONE:-$(timedatectl show -p Timezone --value 2>/dev/null || echo 'UTC')}"
SSL_EMAIL="${N8N_SSL_EMAIL:-admin@${DOMAIN}}"

info "Domain:       ${SUBDOMAIN}.${DOMAIN}"
info "SSL email:    ${SSL_EMAIL}"
info "Timezone:     ${TIMEZONE}"

# --- Install SaltStack ---
install_salt() {
  if command -v salt &>/dev/null; then
    info "SaltStack already installed: $(salt --version)"
    return
  fi

  info "Installing SaltStack..."
  curl -fsSL https://bootstrap.saltproject.io -o /tmp/bootstrap-salt.sh
  sh /tmp/bootstrap-salt.sh -X -M
  rm -f /tmp/bootstrap-salt.sh

  # Enable local mode
  sed -i 's/^#file_client: remote/file_client: local/' /etc/salt/minion 2>/dev/null || true
  systemctl restart salt-minion 2>/dev/null || true
  info "SaltStack installed."
}

# --- Deploy Salt states ---
deploy_states() {
  info "Deploying Salt states..."

  # Copy state tree
  mkdir -p "$SALT_ROOT" "$PILLAR_ROOT"
  cp -r "$SCRIPT_DIR/salt/"* "$SALT_ROOT/"
  cp -r "$SCRIPT_DIR/pillar/"* "$PILLAR_ROOT/"
  cp "$SCRIPT_DIR/top.sls" "$SALT_ROOT/top.sls"
  cp "$SCRIPT_DIR/pillar/top.sls" "$PILLAR_ROOT/top.sls"

  # Generate pillar with real secrets
  cat > "$PILLAR_ROOT/n8n.sls" <<PILLAR
n8n:
  domain: ${DOMAIN}
  subdomain: ${SUBDOMAIN}
  timezone: ${TIMEZONE}
  ssl_email: ${SSL_EMAIL}
  postgres_user: n8n
  postgres_password: "${POSTGRES_PASSWORD}"
  postgres_db: n8n
  encryption_key: "${ENCRYPTION_KEY}"
  deploy_dir: ${DEPLOY_DIR}
PILLAR

  chmod 600 "$PILLAR_ROOT/n8n.sls"
  info "Pillar configured with generated secrets."
}

# --- Apply Salt states ---
apply_states() {
  info "Applying Salt states (this may take a few minutes)..."

  salt-call --local state.apply saltenv=base \
    pillar="{'n8n': {'domain': '${DOMAIN}', 'subdomain': '${SUBDOMAIN}', 'timezone': '${TIMEZONE}', 'ssl_email': '${SSL_EMAIL}', 'postgres_user': 'n8n', 'postgres_password': '${POSTGRES_PASSWORD}', 'postgres_db': 'n8n', 'encryption_key': '${ENCRYPTION_KEY}', 'deploy_dir': '${DEPLOY_DIR}'}}" \
    --retcode-passthrough 2>&1 | tee /tmp/salt-apply.log

  if grep -q "Failed: *[1-9]" /tmp/salt-apply.log; then
    error "Salt apply had failures. Check /tmp/salt-apply.log"
  fi

  info "Salt states applied successfully."
}

# --- Verify ---
verify() {
  info "=== Verification ==="

  # Check containers
  if command -v podman &>/dev/null; then
    podman ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || true
  fi

  # Check ports
  info "Checking listening ports..."
  ss -tlnp | grep -E ':(80|443|5678)\b' || warn "Expected ports not listening yet"

  # Firewall
  if command -v ufw &>/dev/null; then
    ufw status verbose 2>/dev/null || true
  fi

  echo ""
  info "=== Deployment Complete ==="
  info "n8n URL: https://${SUBDOMAIN}.${DOMAIN}"
  info ""
  info "Secrets saved to: $PILLAR_ROOT/n8n.sls"
  warn "BACKUP $PILLAR_ROOT/n8n.sls somewhere safe!"
  info ""
  info "Troubleshooting:"
  info "  salt-call --local state.apply          # Re-apply all states"
  info "  podman ps                               # Check containers"
  info "  podman logs <container>                 # View logs"
  info "  journalctl -u fail2ban                  # Check fail2ban"
}

# --- Main ---
main() {
  install_salt
  deploy_states
  apply_states
  verify
}

main "$@"
