# wazuh/certs.sls
# Distributes Wazuh TLS certificates to each node.
# Certs must be generated first via:
#   salt-run state.orchestrate wazuh.orch.generate_certs

{% set node_name = grains['id'].split('.')[0] %}

{% set cert_dir_map = {
  'indexer':   '/etc/wazuh-indexer/certs',
  'server':    '/etc/wazuh-manager/certs',
  'dashboard': '/etc/wazuh-dashboard/certs',
} %}

{% set cert_dir = cert_dir_map.get(node_name, '/etc/wazuh-agent/certs') %}

wazuh_certs_dir:
  file.directory:
    - name: {{ cert_dir }}
    - makedirs: True
    - mode: '0500'

wazuh_cert_root_ca:
  file.managed:
    - name: {{ cert_dir }}/root-ca.pem
    - source: salt://wazuh/certs/root-ca.pem
    - mode: '0400'
    - require:
      - file: wazuh_certs_dir

{% if node_name in cert_dir_map %}
wazuh_cert_node:
  file.managed:
    - name: {{ cert_dir }}/{{ node_name }}.pem
    - source: salt://wazuh/certs/{{ node_name }}.pem
    - mode: '0400'
    - require:
      - file: wazuh_certs_dir

wazuh_cert_node_key:
  file.managed:
    - name: {{ cert_dir }}/{{ node_name }}-key.pem
    - source: salt://wazuh/certs/{{ node_name }}-key.pem
    - mode: '0400'
    - require:
      - file: wazuh_certs_dir
{% endif %}
