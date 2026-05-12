{% set deploy_dir = pillar['n8n']['deploy_dir'] %}

n8n_deploy_dir:
  file.directory:
    - name: {{ deploy_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

n8n_local_files:
  file.directory:
    - name: {{ deploy_dir }}/local-files
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: n8n_deploy_dir
