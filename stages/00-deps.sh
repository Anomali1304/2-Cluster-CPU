#!/usr/bin/env bash

set -e

log "Installing build dependencies (apt)..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    bc bison flex libssl-dev libelf-dev dwarves \
    build-essential git curl wget python3 python-is-python3 \
    zip unzip jq ccache rsync zstd

if ! check_cmd repo; then
    log "Installing 'repo' launcher..."
    sudo curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo
    sudo chmod a+x /usr/local/bin/repo
fi

check_cmd gh || warn "gh CLI not found — release upload step will be skipped."

git config --global user.email "ci@rock-project.dev"
git config --global user.name "Rock-Project-CI"
git config --global advice.detachedHead false

ccache -M 8G >/dev/null 2>&1 || true
export USE_CCACHE=1
export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"

ok "Dependencies ready."
