# wazuh/docker.sls
# Deploys Wazuh 5.0 stack via Docker Compose on a single node.

{% set wazuh_dir = '/opt/wazuh-docker' %}

# ── Docker installatie ────────────────────────────────────────────────────────

wazuh_docker_deps:
  pkg.installed:
    - pkgs:
      - ca-certificates
      - curl
      - gnupg

wazuh_docker_gpg:
  cmd.run:
    - name: |
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
          -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
    - unless: test -f /etc/apt/keyrings/docker.asc
    - require:
      - pkg: wazuh_docker_deps

wazuh_docker_repo:
  file.managed:
    - name: /etc/apt/sources.list.d/docker.list
    - contents: |
        deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable
    - require:
      - cmd: wazuh_docker_gpg

wazuh_docker_install:
  pkg.installed:
    - pkgs:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-buildx-plugin
      - docker-compose-plugin
    - refresh: True
    - require:
      - file: wazuh_docker_repo

wazuh_docker_service:
  service.running:
    - name: docker
    - enable: True
    - require:
      - pkg: wazuh_docker_install

# ── Directories ───────────────────────────────────────────────────────────────

wazuh_docker_dirs:
  file.directory:
    - names:
      - {{ wazuh_dir }}
      - {{ wazuh_dir }}/config/root-ca/certs
      - {{ wazuh_dir }}/config/wazuh_manager/certs
      - {{ wazuh_dir }}/config/wazuh_indexer/certs
      - {{ wazuh_dir }}/config/wazuh_dashboard/certs
    - makedirs: True

# ── Certs ─────────────────────────────────────────────────────────────────────

# ── Certs ─────────────────────────────────────────────────────────────────────

wazuh_docker_cert_root_ca:
  file.managed:
    - name: {{ wazuh_dir }}/config/root-ca/certs/root-ca.pem
    - source: salt://wazuh/certs/root-ca.pem
    - require:
      - file: wazuh_docker_dirs

wazuh_docker_cert_manager:
  file.managed:
    - name: {{ wazuh_dir }}/config/wazuh_manager/certs/wazuh.manager.pem
    - source: salt://wazuh/certs/server.pem
    - require:
      - file: wazuh_docker_dirs

wazuh_docker_cert_manager_key:
  file.managed:
    - name: {{ wazuh_dir }}/config/wazuh_manager/certs/wazuh.manager-key.pem
    - source: salt://wazuh/certs/server-key.pem
    - require:
      - file: wazuh_docker_dirs

wazuh_docker_cert_indexer:
  file.managed:
    - name: {{ wazuh_dir }}/config/wazuh_indexer/certs/wazuh.indexer.pem
    - source: salt://wazuh/certs/indexer.pem
    - require:
      - file: wazuh_docker_dirs

wazuh_docker_cert_indexer_key:
  file.managed:
    - name: {{ wazuh_dir }}/config/wazuh_indexer/certs/wazuh.indexer-key.pem
    - source: salt://wazuh/certs/indexer-key.pem
    - require:
      - file: wazuh_docker_dirs

wazuh_docker_cert_admin:
  file.managed:
    - name: {{ wazuh_dir }}/config/wazuh_indexer/certs/admin.pem
    - source: salt://wazuh/certs/admin.pem
    - require:
      - file: wazuh_docker_dirs

wazuh_docker_cert_admin_key:
  file.managed:
    - name: {{ wazuh_dir }}/config/wazuh_indexer/certs/admin-key.pem
    - source: salt://wazuh/certs/admin-key.pem
    - require:
      - file: wazuh_docker_dirs

wazuh_docker_cert_dashboard:
  file.managed:
    - name: {{ wazuh_dir }}/config/wazuh_dashboard/certs/wazuh.dashboard.pem
    - source: salt://wazuh/certs/dashboard.pem
    - require:
      - file: wazuh_docker_dirs

wazuh_docker_cert_dashboard_key:
  file.managed:
    - name: {{ wazuh_dir }}/config/wazuh_dashboard/certs/wazuh.dashboard-key.pem
    - source: salt://wazuh/certs/dashboard-key.pem
    - require:
      - file: wazuh_docker_dirs

# ── docker-compose.yml ────────────────────────────────────────────────────────

wazuh_docker_compose:
  file.managed:
    - name: {{ wazuh_dir }}/docker-compose.yml
    - contents: |
        services:
          wazuh.manager:
            image: wazuh/wazuh-manager:5.0.0-beta3
            hostname: wazuh.manager
            container_name: wazuh5-manager
            restart: always
            depends_on:
              wazuh.indexer:
                condition: service_healthy
            healthcheck:
              test: ["CMD-SHELL", "/var/wazuh-manager/bin/wazuh-manager-control status 2>/dev/null | grep -q 'not running' && exit 1 || exit 0"]
              interval: 15s
              timeout: 5s
              retries: 5
              start_period: 60s
            ulimits:
              memlock:
                soft: -1
                hard: -1
              nofile:
                soft: 655360
                hard: 655360
            ports:
              - "1514:1514"
              - "1515:1515"
              - "514:514/udp"
              - "55000:55000"
            environment:
              - WAZUH_INDEXER_HOSTS=wazuh.indexer:9200
              - WAZUH_NODE_NAME=manager
              - WAZUH_CLUSTER_NODES=wazuh.manager
              - WAZUH_CLUSTER_BIND_ADDR=wazuh.manager
              - INDEXER_USERNAME=admin
              - INDEXER_PASSWORD=admin
            volumes:
              - wazuh_api_configuration:/var/wazuh-manager/api/configuration
              - wazuh_etc:/var/wazuh-manager/etc
              - wazuh_logs:/var/wazuh-manager/logs
              - wazuh_queue:/var/wazuh-manager/queue
              - wazuh_var_multigroups:/var/wazuh-manager/var/multigroups
              - ./config/root-ca/certs/root-ca.pem:/var/wazuh-manager/etc/certs/root-ca.pem
              - ./config/wazuh_manager/certs/wazuh.manager.pem:/var/wazuh-manager/etc/certs/manager.pem
              - ./config/wazuh_manager/certs/wazuh.manager-key.pem:/var/wazuh-manager/etc/certs/manager-key.pem

          wazuh.indexer:
            image: wazuh/wazuh-indexer:5.0.0-beta3
            hostname: wazuh.indexer
            container_name: wazuh5-indexer
            restart: always
            ports:
              - "9200:9200"
            environment:
              - OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g
              - bootstrap.memory_lock=true
              - network.host=0.0.0.0
              - node.name=wazuh.indexer
              - cluster.initial_cluster_manager_nodes=wazuh.indexer
              - node.max_local_storage_nodes=1
              - plugins.security.allow_default_init_securityindex=true
              - NODES_DN=CN=wazuh.indexer,OU=Wazuh,O=Wazuh,L=California,C=US
            ulimits:
              memlock:
                soft: -1
                hard: -1
              nofile:
                soft: 65536
                hard: 65536
            healthcheck:
              test: ["CMD-SHELL", "curl -fks https://localhost:9200/_plugins/_security/health | grep -q '\"status\":\"UP\"'"]
              interval: 30s
              timeout: 10s
              retries: 5
              start_period: 60s
            volumes:
              - wazuh-indexer-data:/var/lib/wazuh-indexer
              - ./config/root-ca/certs/root-ca.pem:/usr/share/wazuh-indexer/config/certs/root-ca.pem
              - ./config/wazuh_indexer/certs/wazuh.indexer-key.pem:/usr/share/wazuh-indexer/config/certs/indexer-key.pem
              - ./config/wazuh_indexer/certs/wazuh.indexer.pem:/usr/share/wazuh-indexer/config/certs/indexer.pem
              - ./config/wazuh_indexer/certs/admin.pem:/usr/share/wazuh-indexer/config/certs/admin.pem
              - ./config/wazuh_indexer/certs/admin-key.pem:/usr/share/wazuh-indexer/config/certs/admin-key.pem

          wazuh.dashboard:
            image: wazuh/wazuh-dashboard:5.0.0-beta3
            hostname: wazuh.dashboard
            container_name: wazuh5-dashboard
            restart: always
            healthcheck:
              test: ["CMD", "curl", "-k", "-s", "-o", "/dev/null", "https://localhost:5601/login"]
              interval: 30s
              timeout: 10s
              retries: 3
              start_period: 30s
            ports:
              - "443:5601"
            environment:
              - SERVER_PORT=5601
              - SERVER_HOST=0.0.0.0
              - OPENSEARCH_HOSTS=https://wazuh.indexer:9200
              - INDEXER_USERNAME=admin
              - INDEXER_PASSWORD=admin
              - WAZUH_API_URL=https://wazuh.manager
              - DASHBOARD_USERNAME=kibanaserver
              - DASHBOARD_PASSWORD=kibanaserver
              - SERVER_SSL_CERTIFICATE=/usr/share/wazuh-dashboard/config/certs/dashboard.pem
              - SERVER_SSL_KEY=/usr/share/wazuh-dashboard/config/certs/dashboard-key.pem
              - OPENSEARCH_SSL_CERTIFICATE_AUTHORITIES=/usr/share/wazuh-dashboard/config/certs/root-ca.pem
            volumes:
              - ./config/wazuh_dashboard/certs/wazuh.dashboard.pem:/usr/share/wazuh-dashboard/config/certs/dashboard.pem
              - ./config/wazuh_dashboard/certs/wazuh.dashboard-key.pem:/usr/share/wazuh-dashboard/config/certs/dashboard-key.pem
              - ./config/root-ca/certs/root-ca.pem:/usr/share/wazuh-dashboard/config/certs/root-ca.pem
              - wazuh-dashboard-config:/usr/share/wazuh-dashboard/config
              - wazuh-dashboard-custom:/usr/share/wazuh-dashboard/plugins/wazuh/public/assets/custom
            depends_on:
              wazuh.indexer:
                condition: service_healthy
              wazuh.manager:
                condition: service_healthy

        volumes:
          wazuh_api_configuration:
          wazuh_etc:
          wazuh_logs:
          wazuh_queue:
          wazuh_var_multigroups:
          wazuh-indexer-data:
          wazuh-dashboard-config:
          wazuh-dashboard-custom:
    - require:
      - file: wazuh_docker_dirs

# ── vm.max_map_count voor OpenSearch ─────────────────────────────────────────

wazuh_docker_sysctl:
  sysctl.present:
    - name: vm.max_map_count
    - value: 262144

# ── Stack opstarten ───────────────────────────────────────────────────────────

wazuh_docker_up:
  cmd.run:
    - name: docker compose -f {{ wazuh_dir }}/docker-compose.yml up -d
    - cwd: {{ wazuh_dir }}
    - require:
      - service: wazuh_docker_service
      - file: wazuh_docker_compose
      - file: wazuh_docker_cert_root_ca
      - file: wazuh_docker_cert_manager
      - file: wazuh_docker_cert_indexer
      - file: wazuh_docker_cert_dashboard
      - sysctl: wazuh_docker_sysctl
    - unless: docker ps | grep -q wazuh5-indexer
