podman_deps:
  pkg.installed:
    - pkgs:
      - podman
      - podman-compose
      - curl
      - gnupg

podman_service:
  service.running:
    - name: podman
    - enable: True
    - require:
      - pkg: podman_deps

podman_socket:
  service.running:
    - name: podman.socket
    - enable: True
    - require:
      - pkg: podman_deps
