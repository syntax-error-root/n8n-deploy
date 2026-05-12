{% set deploy_dir = pillar['n8n']['deploy_dir'] %}

n8n_env_file:
  file.managed:
    - name: {{ deploy_dir }}/.env
    - source: salt://n8n/files/env.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: n8n_deploy_dir

n8n_compose_file:
  file.managed:
    - name: {{ deploy_dir }}/compose.yaml
    - source: salt://n8n/files/compose.yaml
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: n8n_deploy_dir
