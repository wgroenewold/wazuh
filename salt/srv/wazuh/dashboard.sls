# wazuh/dashboard.sls
# Installs and configures the Wazuh dashboard

wazuh_dashboard_deps:
  pkg.installed:
    - pkgs:
      - debhelper
      - tar
      - curl

wazuh_dashboard:
  pkg.installed:
    - name: wazuh-dashboard
    - require:
      - pkg: wazuh_dashboard_deps
      - sls: wazuh.repo
      - sls: wazuh.certs

wazuh_dashboard_config:
  file.managed:
    - name: /etc/wazuh-dashboard/opensearch_dashboards.yml
    - contents: |
        server.host: 0.0.0.0
        server.port: 443
        opensearch.hosts: https://{{ pillar['wazuh']['indexer_ip'] }}:9200
        opensearch.ssl.verificationMode: certificate
        opensearch.username: kibanaserver
        opensearch.password: kibanaserver
        opensearch.requestHeadersAllowlist: ["securitytenant","Authorization"]
        opensearch_security.multitenancy.enabled: false
        opensearch_security.readonly_mode.roles: ["kibana_read_only"]
        server.ssl.enabled: true
        server.ssl.key: /etc/wazuh-dashboard/certs/dashboard-key.pem
        server.ssl.certificate: /etc/wazuh-dashboard/certs/dashboard.pem
        opensearch.ssl.certificateAuthorities: ["/etc/wazuh-dashboard/certs/root-ca.pem"]
        uiSettings.overrides.defaultRoute: /app/wazuh
        opensearch_security.cookie.secure: true
        csp.rules:
          - "script-src 'unsafe-eval' 'self' 'unsafe-inline'"
          - "worker-src 'self' blob:"

    - require:
      - pkg: wazuh_dashboard

wazuh_dashboard_certs_dir:
  file.directory:
    - name: /etc/wazuh-dashboard/certs
    - makedirs: True

wazuh_dashboard_cert:
  file.managed:
    - name: /etc/wazuh-dashboard/certs/dashboard.pem
    - source: salt://wazuh/certs/dashboard.pem
    - mode: '0400'
    - require:
      - file: wazuh_dashboard_certs_dir

wazuh_dashboard_cert_key:
  file.managed:
    - name: /etc/wazuh-dashboard/certs/dashboard-key.pem
    - source: salt://wazuh/certs/dashboard-key.pem
    - mode: '0400'
    - require:
      - file: wazuh_dashboard_certs_dir

wazuh_dashboard_root_ca:
  file.managed:
    - name: /etc/wazuh-dashboard/certs/root-ca.pem
    - source: salt://wazuh/certs/root-ca.pem
    - mode: '0400'
    - require:
      - file: wazuh_dashboard_certs_dir

wazuh_dashboard_api_host:
  file.replace:
    - name: /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml
    - pattern: 'url: https://localhost'
    - repl: 'url: https://{{ pillar["wazuh"]["server_ip"] }}'
    - require:
      - pkg: wazuh_dashboard

wazuh_dashboard_service:
  service.running:
    - name: wazuh-dashboard
    - enable: True
    - require:
      - pkg: wazuh_dashboard
      - file: wazuh_dashboard_config
      - file: wazuh_dashboard_cert
      - file: wazuh_dashboard_cert_key
      - file: wazuh_dashboard_root_ca
      - file: wazuh_dashboard_api_host
    - watch:
      - file: wazuh_dashboard_config
      - file: wazuh_dashboard_api_host
