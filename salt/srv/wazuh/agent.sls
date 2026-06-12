# wazuh/agent.sls
# Installs and configures the Wazuh agent on client nodes

wazuh_agent:
  pkg.installed:
    - name: wazuh-agent
    - env:
      - WAZUH_MANAGER: {{ pillar['wazuh']['server_ip'] }}
    - require:
      - sls: wazuh.repo

wazuh_agent_service:
  service.running:
    - name: wazuh-agent
    - enable: True
    - require:
      - pkg: wazuh_agent
