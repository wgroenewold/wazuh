# wazuh/build.sls
# Builds Wazuh .deb packages from the latest pre-release GitHub tag
# and publishes them via a local apt repository served by nginx.
#
# Triggered via CI: salt 'build.wazuh.local' state.apply wazuh.build

{% set repo_root = '/mnt/wazuh-build/apt' %}
{% set pool_dir  = repo_root + '/pool/main' %}
{% set dists_dir = repo_root + '/dists/stable/main/binary-amd64' %}
{% set src_dir   = '/mnt/wazuh-build/src' %}
{% set next_major = pillar.get('wazuh', {}).get('next_major', '') %}

# ── Prerequisites ─────────────────────────────────────────────────────────────

wazuh_build_deps:
  pkg.installed:
    - pkgs:
      - git
      - curl
      - jq
      - dpkg-dev
      - apt-utils
      - python3-pip
      - python3-venv

# ── Fetch latest pre-release tag from GitHub ──────────────────────────────────

wazuh_fetch_tag:
  cmd.run:
    - name: |
        {% if not next_major %}
        echo "ERROR: wazuh:next_major not set in pillar" >&2
        exit 1
        {% endif %}
        TAG=$(curl -sf https://api.github.com/repos/wazuh/wazuh/releases \
          | jq -r '[.[] | select(.prerelease == true) | select(.tag_name | startswith("v{{ next_major }}") and ({{ next_major | tojson }} != ""))] | first | .tag_name')
        if [ -z "$TAG" ] || [ "$TAG" = "null" ]; then
          echo "ERROR: could not determine latest next-major pre-release tag" >&2
          exit 1
        fi
        VERSION=${TAG#v}
        echo "Latest next-major pre-release tag: $TAG ($VERSION)"
        if curl -sf "https://packages.wazuh.com/{{ next_major }}.x/apt/pool/main/w/wazuh-manager/wazuh-manager_${VERSION}-1_amd64.deb" \
            --head --output /dev/null 2>/dev/null; then
          echo "Version $VERSION already available on packages.wazuh.com — skipping build"
          echo "SKIP" > /mnt/wazuh-build/build-status
        else
          echo "Version $VERSION not yet on packages.wazuh.com — build needed"
          echo "BUILD" > /mnt/wazuh-build/build-status
        fi
        echo "$TAG" > /mnt/wazuh-build/current-tag
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

# ── Clean up old packages ─────────────────────────────────────────────────────

wazuh_cleanup_old_packages:
  cmd.run:
    - name: |
        TAG=$(cat /mnt/wazuh-build/current-tag)
        COMMIT=${TAG#v}
        # Remove any .deb files that don't match the current tag's commit hash
        find {{ pool_dir }} -name "*.deb" | while read f; do
          if ! echo "$f" | grep -q "$(git -C {{ src_dir }} rev-parse --short HEAD)"; then
            echo "Removing old package: $f"
            rm -f "$f"
          fi
        done
    - unless: grep -q "SKIP" /mnt/wazuh-build/build-status
    - require:
      - cmd: wazuh_clone

# ── Build packages ────────────────────────────────────────────────────────────

{% for component in ['manager', 'agent'] %}
wazuh_build_{{ component }}:
  cmd.run:
    - name: |
        TAG=$(cat /mnt/wazuh-build/current-tag)
        VERSION=${TAG#v}
        bash /mnt/wazuh-build/src/packages/generate_package.sh \
          --target {{ component }} \
          --architecture amd64 \
          --revision 1 \
          --store {{ pool_dir }} \
          --sources /mnt/wazuh-build/src \
          --system deb
    - unless: grep -q "SKIP" /mnt/wazuh-build/build-status
    - require:
      - cmd: wazuh_clone
    - timeout: 3600
{% endfor %}

# ── Build Engine tarball (needed by indexer builder) ─────────────────────────
wazuh_engine_venv:
  cmd.run:
    - name: |
        python3 -m venv /mnt/wazuh-build/engine-venv
        /mnt/wazuh-build/engine-venv/bin/pip install --upgrade pip
    - unless: test -f /mnt/wazuh-build/engine-venv/bin/pip
    - require:
      - cmd: wazuh_clone

wazuh_build_engine:
  cmd.run:
    - name: |
        mkdir -p {{ pool_dir }}/engine
        source /mnt/wazuh-build/engine-venv/bin/activate
        bash {{ src_dir }}/src/engine/standalone/generate_package.sh \
          --architecture amd64 \
          --store {{ pool_dir }}/engine \
          --dont-build-docker
    - shell: /bin/bash
    - unless: grep -q "SKIP" /mnt/wazuh-build/build-status
    - require:
      - cmd: wazuh_engine_venv
      - cmd: wazuh_cleanup_old_packages
    - timeout: 3600

# ── Clone wazuh-indexer repo ──────────────────────────────────────────────────

wazuh_clone_indexer:
  cmd.run:
    - name: |
        TAG=$(cat /mnt/wazuh-build/current-tag)
        INDEXER_DIR=/mnt/wazuh-build/src-indexer
        if [ -d "$INDEXER_DIR/.git" ]; then
          CURRENT=$(git -C $INDEXER_DIR describe --tags --exact-match 2>/dev/null || echo "none")
          if [ "$CURRENT" = "$TAG" ]; then
            echo "Indexer source already at $TAG, skipping clone"
            exit 0
          fi
          rm -rf $INDEXER_DIR
        fi
        git clone --depth 1 --branch "$TAG" \
          https://github.com/wazuh/wazuh-indexer.git $INDEXER_DIR
    - unless: grep -q "SKIP" /mnt/wazuh-build/build-status
    - require:
      - cmd: wazuh_fetch_tag
    - timeout: 600

# ── Build indexer package ─────────────────────────────────────────────────────

wazuh_build_indexer:
  cmd.run:
    - name: |
        ENGINE_TARBALL=$(ls {{ pool_dir }}/engine/wazuh-engine-*.tar.gz 2>/dev/null | head -1)
        if [ -z "$ENGINE_TARBALL" ]; then
          echo "ERROR: engine tarball not found" >&2
          exit 1
        fi
        cd /mnt/wazuh-build/src-indexer/build-scripts
        bash builder.sh \
          -d deb \
          -a x64 \
          -R 1 \
          -S true \
          -e "$ENGINE_TARBALL"
        find /mnt/wazuh-build/src-indexer/artifacts/dist -name "*.deb" \
          -exec cp {} {{ pool_dir }}/ \;
    - unless: grep -q "SKIP" /mnt/wazuh-build/build-status
    - require:
      - cmd: wazuh_build_engine
      - cmd: wazuh_clone_indexer
    - timeout: 7200

# ── Generate apt repository metadata ──────────────────────────────────────────

wazuh_repo_packages:
  cmd.run:
    - name: |
        cd {{ repo_root }}
        dpkg-scanpackages pool/main /dev/null > {{ dists_dir }}/Packages
        gzip -9 -k -f {{ dists_dir }}/Packages
    - onchanges:
      - cmd: wazuh_build_manager
      - cmd: wazuh_build_agent
      - cmd: wazuh_build_indexer

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
