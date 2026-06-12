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
