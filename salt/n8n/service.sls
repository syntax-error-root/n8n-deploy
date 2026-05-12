{% set deploy_dir = pillar['n8n']['deploy_dir'] %}

n8n_compose_up:
  cmd.run:
    - name: podman-compose up -d
    - cwd: {{ deploy_dir }}
    - require:
      - file: n8n_env_file
      - file: n8n_compose_file
      - service: podman_socket
    - watch:
      - file: n8n_env_file
      - file: n8n_compose_file
