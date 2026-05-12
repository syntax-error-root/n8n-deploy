# --- SSH Hardening ---
ssh_hardening:
  file.keyvalue:
    - name: /etc/ssh/sshd_config
    - key_values:
        PermitRootLogin: "no"
        PasswordAuthentication: "no"
        PubkeyAuthentication: "yes"
        X11Forwarding: "no"
        MaxAuthTries: "3"
        ClientAliveInterval: "300"
        ClientAliveCountMax: "2"
        LoginGraceTime: "30"
        AllowTcpForwarding: "no"
        AllowAgentForwarding: "no"
    - separator: " "
    - uncomment: "# "
    - require_in:
      - service: sshd_restart

sshd_restart:
  service.running:
    - name: sshd
    - enable: True
    - watch:
      - file: ssh_hardening

# --- Fail2ban ---
fail2ban_installed:
  pkg.installed:
    - name: fail2ban

fail2ban_local:
  file.managed:
    - name: /etc/fail2ban/jail.local
    - contents: |
        [DEFAULT]
        bantime = 3600
        findtime = 600
        maxretry = 3
        banaction = ufw

        [sshd]
        enabled = true
        port = ssh
        filter = sshd
        logpath = /var/log/auth.log
        maxretry = 3
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - pkg: fail2ban_installed

fail2ban_service:
  service.running:
    - name: fail2ban
    - enable: True
    - require:
      - file: fail2ban_local

# --- Sysctl hardening ---
sysctl_hardening:
  sysctl.present:
    - names:
        net.ipv4.ip_forward:
          value: 0
        net.ipv4.conf.all.send_redirects:
          value: 0
        net.ipv4.conf.default.send_redirects:
          value: 0
        net.ipv4.conf.all.accept_redirects:
          value: 0
        net.ipv4.conf.default.accept_redirects:
          value: 0
        net.ipv4.conf.all.accept_source_route:
          value: 0
        net.ipv6.conf.all.accept_source_route:
          value: 0
        net.ipv4.conf.all.log_martians:
          value: 1
        net.ipv4.conf.default.log_martians:
          value: 1
        net.ipv4.icmp_echo_ignore_broadcasts:
          value: 1
        net.ipv4.icmp_ignore_bogus_error_responses:
          value: 1
        kernel.exec-shield:
          value: 1
        kernel.randomize_va_space:
          value: 2

# --- Automatic security updates ---
unattended_upgrades:
  pkg.installed:
    - name: unattended-upgrades

unattended_config:
  file.managed:
    - name: /etc/apt/apt.conf.d/50unattended-upgrades
    - contents: |
        Unattended-Upgrade::Allowed-Origins {
            "${distro_id}:${distro_codename}-security";
        };
        Unattended-Upgrade::AutoFixInterruptedDpkg "true";
        Unattended-Upgrade::Remove-Unused-Dependencies "true";
        Unattended-Upgrade::Automatic-Reboot "false";
    - require:
      - pkg: unattended_upgrades

auto_upgrades:
  file.managed:
    - name: /etc/apt/apt.conf.d/20auto-upgrades
    - contents: |
        APT::Periodic::Update-Package-Lists "1";
        APT::Periodic::Unattended-Upgrade "1";
        APT::Periodic::Download-Upgradeable-Packages "1";

# --- Remove unnecessary services ---
disable_services:
  service.dead:
    - names:
      - avahi-daemon
      - cups
      - bluetooth
    - enable: False
    - onlyif:
      - systemctl list-unit-files avahi-daemon.service
      - systemctl list-unit-files cups.service
