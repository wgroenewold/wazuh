# wazuh/build_schedule.sls
# Periodic check for new Wazuh pre-release tags.
# Only triggers wazuh.build if a newer tag is found than current-tag.

{% set next_major = pillar.get('wazuh', {}).get('next_major', '') %}

wazuh_build_check_script:
  file.managed:
    - name: /usr/local/bin/wazuh-build-check
    - mode: '0755'
    - contents: |
        #!/bin/bash
        # Check if a new Wazuh v{{ next_major }} pre-release tag is available.
        # If so, trigger salt state.apply wazuh.build.

        CURRENT_TAG=$(cat /mnt/wazuh-build/current-tag 2>/dev/null || echo "none")

        LATEST_TAG=$(curl -sf https://api.github.com/repos/wazuh/wazuh/releases \
          | jq -r '[.[] | select(.prerelease == true) | select(.tag_name | startswith("v{{ next_major }}"))] | first | .tag_name')

        if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "null" ]; then
          echo "$(date): No v{{ next_major }} pre-release tag found, skipping"
          exit 0
        fi

        if [ "$LATEST_TAG" = "$CURRENT_TAG" ]; then
          echo "$(date): Already at latest tag $CURRENT_TAG, skipping"
          exit 0
        fi

        echo "$(date): New tag found: $LATEST_TAG (was: $CURRENT_TAG) — triggering build"
        salt-call state.apply wazuh.build

wazuh_build_check_cron:
  cron.present:
    - name: /usr/local/bin/wazuh-build-check >> /var/log/wazuh-build-check.log 2>&1
    - user: root
    - hour: '*/6'
    - minute: '0'
    - require:
      - file: wazuh_build_check_script
