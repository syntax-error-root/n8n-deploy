{% set deploy_dir = pillar['n8n']['deploy_dir'] %}

ufw_installed:
  pkg.installed:
    - name: ufw

ufw_defaults:
  cmd.run:
    - names:
      - ufw default deny incoming
      - ufw default allow outgoing
    - unless: ufw status | grep -q "deny (incoming)"

ufw_allow_ssh:
  cmd.run:
    - name: ufw allow 22/tcp
    - unless: ufw status | grep -q "22/tcp"

ufw_allow_http:
  cmd.run:
    - name: ufw allow 80/tcp
    - unless: ufw status | grep -q "80/tcp"

ufw_allow_https:
  cmd.run:
    - name: ufw allow 443/tcp
    - unless: ufw status | grep -q "443/tcp"

ufw_enable:
  cmd.run:
    - name: ufw --force enable
    - unless: ufw status | grep -q "Status: active"
    - require:
      - cmd: ufw_allow_ssh
      - cmd: ufw_allow_http
      - cmd: ufw_allow_https
