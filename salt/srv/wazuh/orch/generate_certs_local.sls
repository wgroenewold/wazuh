# wazuh/orch/generate_certs_local.sls
# Runs on the salt-master itself to generate Wazuh TLS certificates.
# Called by generate_certs.sls via orchestration.

wazuh_certs_workdir:
  file.directory:
    - name: /tmp/wazuh-certs-gen
    - makedirs: True

wazuh_certs_tool:
  cmd.run:
    - name: curl -fsSL -o /tmp/wazuh-certs-gen/wazuh-certs-tool.sh
    - unless: test -f /tmp/wazuh-certs-gen/wazuh-certs-tool.sh
    - require:
      - file: wazuh_certs_workdir

wazuh_certs_config:
  file.managed:
    - name: /tmp/wazuh-certs-gen/config.yml
    - template: jinja
    - source: salt://wazuh/files/config.yml.jinja
    - require:
      - file: wazuh_certs_workdir

wazuh_certs_generate:
  cmd.run:
    - name: bash /tmp/wazuh-certs-gen/wazuh-certs-tool.sh -A
    - cwd: /tmp/wazuh-certs-gen
    - unless: test -f /srv/salt/wazuh/certs/root-ca.pem
    - require:
      - cmd: wazuh_certs_tool
      - file: wazuh_certs_config

wazuh_certs_dir:
  file.directory:
    - name: /srv/salt/wazuh/certs
    - makedirs: True
    - require:
      - cmd: wazuh_certs_generate

wazuh_certs_copy:
  cmd.run:
    - name: |
        cp /tmp/wazuh-certs-gen/wazuh-certificates/root-ca.pem /srv/salt/wazuh/certs/
        cp /tmp/wazuh-certs-gen/wazuh-certificates/admin.pem /srv/salt/wazuh/certs/
        cp /tmp/wazuh-certs-gen/wazuh-certificates/admin-key.pem /srv/salt/wazuh/certs/
        cp /tmp/wazuh-certs-gen/wazuh-certificates/indexer.pem /srv/salt/wazuh/certs/
        cp /tmp/wazuh-certs-gen/wazuh-certificates/indexer-key.pem /srv/salt/wazuh/certs/
        cp /tmp/wazuh-certs-gen/wazuh-certificates/server.pem /srv/salt/wazuh/certs/
        cp /tmp/wazuh-certs-gen/wazuh-certificates/server-key.pem /srv/salt/wazuh/certs/
        cp /tmp/wazuh-certs-gen/wazuh-certificates/dashboard.pem /srv/salt/wazuh/certs/
        cp /tmp/wazuh-certs-gen/wazuh-certificates/dashboard-key.pem /srv/salt/wazuh/certs/
        chown root:salt /srv/salt/wazuh/certs/*.pem
        chmod 440 /srv/salt/wazuh/certs/*.pem
    - unless: test -f /srv/salt/wazuh/certs/root-ca.pem
    - require:
      - file: wazuh_certs_dir
