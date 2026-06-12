# wazuh/indexer.sls
# Installs and configures the Wazuh indexer (OpenSearch-based)

wazuh_indexer_deps:
  pkg.installed:
    - pkgs:
      - debconf
      - adduser
      - procps

wazuh_indexer:
  pkg.installed:
    - name: wazuh-indexer
    - require:
      - pkg: wazuh_indexer_deps
      - sls: wazuh.repo
      - sls: wazuh.certs

wazuh_indexer_config:
  file.managed:
    - name: /etc/wazuh-indexer/opensearch.yml
    - contents: |
        network.host: {{ grains['ip4_interfaces']['enp3s0'][0] }}
        node.name: indexer
        cluster.initial_master_nodes:
          - indexer
        discovery.seed_hosts:
          - indexer
        plugins.security.ssl.http.pemcert_filepath: /etc/wazuh-indexer/certs/indexer.pem
        plugins.security.ssl.http.pemkey_filepath: /etc/wazuh-indexer/certs/indexer-key.pem
        plugins.security.ssl.http.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/root-ca.pem
        plugins.security.ssl.transport.pemcert_filepath: /etc/wazuh-indexer/certs/indexer.pem
        plugins.security.ssl.transport.pemkey_filepath: /etc/wazuh-indexer/certs/indexer-key.pem
        plugins.security.ssl.transport.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/root-ca.pem
        plugins.security.ssl.http.enabled: true
        plugins.security.ssl.transport.enforce_hostname_verification: false
        plugins.security.ssl.transport.resolve_hostname: false
        plugins.security.authcz.admin_dn:
          - CN=admin,OU=Wazuh,O=Wazuh,L=California,C=US
        plugins.security.check_snapshot_restore_write_privileges: true
        plugins.security.enable_snapshot_restore_privilege: true
        plugins.security.nodes_dn:
          - CN=indexer,OU=Wazuh,O=Wazuh,L=California,C=US
        plugins.security.restapi.roles_enabled:
          - all_access
          - security_rest_api_access
        plugins.security.system_indices.enabled: true
        plugins.security.system_indices.indices:
          [".opendistro-alerting-config", ".opendistro-alerting-alert*",
           ".opendistro-anomaly-results*", ".opendistro-anomaly-detector*",
           ".opendistro-anomaly-checkpoints", ".opendistro-anomaly-detection-state",
           ".opendistro-reports-*", ".opendistro-notifications-*",
           ".opendistro-notebooks", ".opensearch-observability", ".ql-datasources",
           ".opendistro-asynchronous-search-response*", ".replication-metadata-store",
           ".opensearch-sap-log-types-config", ".opensearch-sap-pre-packaged-rules-config",
           ".plugins-ml-commons-config", ".plugins-ml-task*"]
        compatibility.override_main_response_version: true
    - require:
      - pkg: wazuh_indexer

wazuh_indexer_service:
  service.running:
    - name: wazuh-indexer
    - enable: True
    - require:
      - pkg: wazuh_indexer
      - file: wazuh_indexer_config
    - watch:
      - file: wazuh_indexer_config

wazuh_indexer_security_init:
  cmd.run:
    - name: /usr/share/wazuh-indexer/bin/indexer-security-init.sh
    - unless: curl -sk -u admin:admin https://localhost:9200/_cluster/health | grep -q '"status":"green"'
    - require:
      - service: wazuh_indexer_service
