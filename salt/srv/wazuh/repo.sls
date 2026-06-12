# wazuh/repo.sls
# Installs the Wazuh APT repository and GPG key

wazuh_repo_dependencies:
  pkg.installed:
    - pkgs:
      - gnupg
      - apt-transport-https
      - curl

wazuh_gpg_key:
  cmd.run:
    - name: >
        curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH |
        gpg --no-default-keyring
        --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg
        --import &&
        chmod 644 /usr/share/keyrings/wazuh.gpg
    - unless: test -f /usr/share/keyrings/wazuh.gpg
    - require:
      - pkg: wazuh_repo_dependencies

wazuh_repo:
  file.managed:
    - name: /etc/apt/sources.list.d/wazuh.list
    - contents: |
        deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main
    - require:
      - cmd: wazuh_gpg_key

wazuh_repo_update:
  cmd.run:
    - name: apt-get update
    - onchanges:
      - file: wazuh_repo
