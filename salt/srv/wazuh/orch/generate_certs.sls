# wazuh/orch/generate_certs.sls
# Generates Wazuh TLS certificates on the salt-master and places them
# in /srv/salt/wazuh/certs/ for distribution to minions via certs.sls.
#
# Triggered automatically by the CI/CD pipeline:
#   sudo salt-run state.orchestrate wazuh.orch.generate_certs

{% set internal_domain = salt['pillar.get']('wazuh:internal_domain', 'wazuh.local') %}

generate_wazuh_certs:
  salt.state:
    - tgt: 'salt-master.{{ internal_domain }}'
    - sls:
      - wazuh.orch.generate_certs_local
