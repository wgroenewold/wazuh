# wazuh/build.sls
# Builds Wazuh .deb packages from the latest pre-release GitHub tag
# and publishes them via a local apt repository served by nginx.
#
# Triggered via CI: salt 'build.wazuh.local' state.apply wazuh.build

{% set repo_root = '/mnt/wazuh-build/apt' %}
{% set pool_dir  = repo_root + '/pool/main' %}
{% set dists_dir = repo_root + '/dists/stable/main/binary-amd64' %}
{% set src_dir   = '/mnt/wazuh-build/src' %}

# ── Prerequisites ─────────────────────────────────────────────────────────────

wazuh_build_deps:
  pkg.installed:
    - pkgs:
      - git
      - curl
      - jq
      - dpkg-dev
      - apt-utils

# ── Fetch latest pre-release tag from GitHub ──────────────────────────────────

wazuh_fetch_tag:
  cmd.run:
    - name: |
        TAG=$(curl -sf https://api.github.com/repos/wazuh/wazuh/releases \
          | jq -r '[.[] | select(.prerelease == true)] | first | .tag_name')
        if [ -z "$TAG" ] || [ "$TAG" = "null" ]; then
          echo "ERROR: could not determine latest pre-release tag" >&2
          exit 1
        fi
        echo "$TAG" > /mnt/wazuh-build/current-tag
        echo "Latest pre-release tag: $TAG"
    - require:
      - pkg: wazuh_build_deps

# ── Clone source at that tag ──────────────────────────────────────────────────

wazuh_clone:
  cmd.run:
    - name: |
        TAG=$(cat /mnt/wazuh-build/current-tag)
        if [ -d "{{ src_dir }}/.git" ]; then
          CURRENT=$(git -C {{ src_dir }} describe --tags --exact-match 2>/dev/null || echo "none")
          if [ "$CURRENT" = "$TAG" ]; then
            echo "Source already at $TAG, skipping clone"
            exit 0
          fi
          rm -rf {{ src_dir }}
        fi
        git clone --depth 1 --branch "$TAG" \
          https://github.com/wazuh/wazuh.git {{ src_dir }}
    - require:
      - cmd: wazuh_fetch_tag

# ── Build packages ────────────────────────────────────────────────────────────

{% for component in ['wazuh-manager', 'wazuh-indexer', 'wazuh-dashboard', 'wazuh-agent'] %}
wazuh_build_{{ component | replace('-', '_') }}:
  cmd.run:
    - name: |
        TAG=$(cat /mnt/wazuh-build/current-tag)
        VERSION=${TAG#v}
        cd {{ src_dir }}/packages/debs/SPECS/{{ component }}
        bash ../../generate_debian_package.sh \
          --build-docker \
          --version "$VERSION" \
          --revision 1 \
          --architecture amd64 \
          --output-dir {{ pool_dir }}
    - require:
      - cmd: wazuh_clone
    - timeout: 3600
{% endfor %}

# ── Generate apt repository metadata ──────────────────────────────────────────

wazuh_repo_packages:
  cmd.run:
    - name: |
        cd {{ repo_root }}
        dpkg-scanpackages pool/main /dev/null > {{ dists_dir }}/Packages
        gzip -9 -k -f {{ dists_dir }}/Packages
    - require:
      - cmd: wazuh_build_wazuh_manager
      - cmd: wazuh_build_wazuh_indexer
      - cmd: wazuh_build_wazuh_dashboard
      - cmd: wazuh_build_wazuh_agent

wazuh_repo_release:
  file.managed:
    - name: {{ repo_root }}/dists/stable/Release
    - contents: |
        Origin: Wazuh Local Build
        Label: Wazuh
        Suite: stable
        Codename: stable
        Components: main
        Architectures: amd64
    - require:
      - cmd: wazuh_repo_packages

# ── Reload nginx ──────────────────────────────────────────────────────────────

wazuh_build_nginx_reload:
  service.running:
    - name: nginx
    - reload: True
    - watch:
      - cmd: wazuh_repo_packages
