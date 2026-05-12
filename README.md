# n8n Production Deployment

SaltStack states for deploying [n8n](https://n8n.io) on a VPS with Podman, Traefik, and PostgreSQL.

## What gets deployed

| Component | Purpose |
|-----------|---------|
| Podman + podman-compose | Container runtime (rootless-capable, no Docker daemon) |
| Traefik v3 | Reverse proxy with automatic Let's Encrypt TLS |
| PostgreSQL 16 | Production database for n8n |
| n8n | Workflow automation |

## Security hardening

- UFW firewall: only 22 (SSH), 80 (HTTP), 443 (HTTPS)
- SSH: key-only auth, no root login, max 3 retries
- Fail2ban: 1-hour ban after 3 failed SSH attempts
- Sysctl: ASLR, no IP forwarding, no ICMP redirects, martian logging
- Unattended security updates

## Requirements

- Fresh Ubuntu 22.04/24.04 or Debian 12 VPS
- Root access
- Domain name pointing to the VPS IP
- SSH key already configured on the server

## Setup

### 1. Clone on your VPS

```bash
git clone https://github.com/syntax-error-root/n8n-deploy.git
cd n8n-deploy
```

### 2. Run the installer

```bash
sudo ./install.sh
```

This will:
1. Install SaltStack in local mode
2. Copy Salt states to `/srv/salt/`
3. Generate random passwords and encryption key
4. Apply all states (Podman, containers, firewall, hardening)

### 3. Configure with your domain (unattended)

```bash
N8N_DOMAIN=example.com \
N8N_SSL_EMAIL=admin@example.com \
N8N_SUBDOMAIN=n8n \
N8N_TIMEZONE=UTC \
sudo ./install.sh
```

### 4. Verify

```bash
# Check containers
podman ps

# Check firewall
ufw status verbose

# Check fail2ban
sudo fail2ban-client status sshd
```

n8n will be available at `https://n8n.yourdomain.com`.

## Configuration

### Secrets

Secrets are generated at runtime and stored in `/srv/pillar/n8n.sls`. Back up this file:

```bash
cp /srv/pillar/n8n.sls ~/n8n-secrets-backup.sls
```

**Do not lose this file.** The encryption key is required to decrypt stored credentials.

### Custom pillar values

Edit `pillar/n8n.sls` before running `install.sh`, or override via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `N8N_DOMAIN` | `yourdomain.com` | Your domain |
| `N8N_SUBDOMAIN` | `n8n` | Subdomain for n8n |
| `N8N_SSL_EMAIL` | `admin@domain` | Let's Encrypt email |
| `N8N_TIMEZONE` | Auto-detected | Timezone |
| `N8N_POSTGRES_PASSWORD` | Auto-generated | PostgreSQL password |
| `N8N_ENCRYPTION_KEY` | Auto-generated | n8n credential encryption key |
| `N8N_DEPLOY_DIR` | `/opt/n8n` | Deployment directory |

### Re-apply after changes

```bash
salt-call --local state.apply
```

### Update n8n

```bash
cd /opt/n8n
podman-compose pull
podman-compose up -d
```

## Troubleshooting

```bash
# Container logs
podman logs <container-name>

# Salt state debug
salt-call --local state.apply -l debug

# Traefik logs
podman logs traefik

# PostgreSQL connection
podman exec -it postgres psql -U n8n -d n8n
```

## File structure

```
├── install.sh                # Bash installer
├── top.sls                   # Salt top file
├── pillar/
│   ├── top.sls               # Pillar top file
│   └── n8n.sls               # Config template (placeholders)
├── salt/
│   ├── files/
│   │   ├── compose.yaml      # Podman Compose definition
│   │   └── env.jinja         # .env Jinja template
│   └── n8n/
│       ├── init.sls          # Orchestrator
│       ├── container.sls     # Podman install
│       ├── directories.sls   # Directory setup
│       ├── config.sls        # Config file templating
│       ├── service.sls       # podman-compose up
│       ├── firewall.sls      # UFW rules
│       └── hardening.sls     # SSH, fail2ban, sysctl, auto-updates
```

## License

MIT
