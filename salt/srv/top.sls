base:
  'indexer.wazuh.local':
    - wazuh.repo
    - wazuh.certs
    - wazuh.indexer

  'server.wazuh.local':
    - wazuh.repo
    - wazuh.certs
    - wazuh.server

  'dashboard.wazuh.local':
    - wazuh.repo
    - wazuh.certs
    - wazuh.dashboard

  'client*.wazuh.local':
    - wazuh.repo
    - wazuh.agent

  'build.wazuh.local':
    - wazuh.build_schedule
  'wazuh5.wazuh.local':
    - wazuh.docker
