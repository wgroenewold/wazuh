# wazuh/server.sls
# Installs and configures the Wazuh manager and Filebeat

wazuh_manager:
  pkg.installed:
    - name: wazuh-manager
    - require:
      - sls: wazuh.repo
      - sls: wazuh.certs

wazuh_manager_service:
  service.running:
    - name: wazuh-manager
    - enable: True
    - require:
      - pkg: wazuh_manager

filebeat:
  pkg.installed:
    - name: filebeat
    - require:
      - sls: wazuh.repo

filebeat_config:
  file.managed:
    - name: /etc/filebeat/filebeat.yml
    - source: https://packages.wazuh.com/4.14/tpl/wazuh/filebeat/filebeat.yml
    - skip_verify: True
    - require:
      - pkg: filebeat

filebeat_indexer_host:
  file.replace:
    - name: /etc/filebeat/filebeat.yml
    - pattern: 'hosts: \[".*"\]'
    - repl: 'hosts: ["{{ pillar["wazuh"]["indexer_ip"] }}:9200"]'
    - require:
      - file: filebeat_config

filebeat_keystore_username:
  cmd.run:
    - name: echo admin | filebeat keystore add username --stdin --force
    - require:
      - file: filebeat_config

filebeat_keystore_password:
  cmd.run:
    - name: echo admin | filebeat keystore add password --stdin --force
    - require:
      - cmd: filebeat_keystore_username

filebeat_wazuh_module:
  cmd.run:
    - name: curl -so /etc/filebeat/wazuh-template.json https://raw.githubusercontent.com/wazuh/wazuh/v4.14.1/extensions/elasticsearch/7.x/wazuh-template.json
    - unless: test -f /etc/filebeat/wazuh-template.json
    - require:
      - pkg: filebeat

filebeat_wazuh_module_install:
  cmd.run:
    - name: curl -s https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.4.tar.gz | tar -xvz -C /usr/share/filebeat/module
    - unless: test -d /usr/share/filebeat/module/wazuh
    - require:
      - pkg: filebeat

filebeat_certs:
  file.managed:
    - name: /etc/filebeat/certs/root-ca.pem
    - source: salt://wazuh/certs/root-ca.pem
    - makedirs: True
    - require:
      - sls: wazuh.certs

filebeat_service:
  service.running:
    - name: filebeat
    - enable: True
    - require:
      - pkg: filebeat
      - file: filebeat_config
      - file: filebeat_certs
      - cmd: filebeat_keystore_password
      - cmd: filebeat_wazuh_module_install
    - watch:
      - file: filebeat_config
