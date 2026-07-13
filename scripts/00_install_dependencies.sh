#!/usr/bin/env bash
#
# 00_install_dependencies.sh — install the OS packages the pipeline needs.
#
# Run this once, before anything else. It detects your package manager
# (apt / pacman / dnf) and installs compilers, CMake, Ninja, Git, Git LFS,
# Python and a few CLI helpers (jq, bc, ...). Needs sudo.
#
# This is the only script that does NOT source lib/common.sh: it runs before
# the project is set up, so it defines its own tiny log/die helpers.

set -Eeuo pipefail
IFS=$'\n\t'

# Minimal local versions of the common.sh helpers (see lib/common.sh).
log() { printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Pick the right package manager for this distro and install the toolchain.
if command -v apt-get >/dev/null 2>&1; then
  log "Installing dependencies with apt"
  sudo apt-get update
  sudo apt-get install -y \
    build-essential cmake ninja-build git git-lfs \
    python3 python3-pip python3-venv \
    curl wget unzip jq bc pciutils
elif command -v pacman >/dev/null 2>&1; then
  log "Installing dependencies with pacman"
  sudo pacman -Syu --needed --noconfirm \
    base-devel cmake ninja git git-lfs \
    python python-pip \
    curl wget unzip jq bc pciutils
elif command -v dnf >/dev/null 2>&1; then
  log "Installing dependencies with dnf"
  sudo dnf install -y \
    gcc gcc-c++ make cmake ninja-build git git-lfs \
    python3 python3-pip \
    curl wget unzip jq bc pciutils
else
  die "Unsupported package manager. Install Git, CMake, Ninja, C/C++ build tools, Python 3, curl/wget, unzip and jq manually."
fi

# Git LFS is needed to fetch large model files from Hugging Face; enable it.
if command -v git-lfs >/dev/null 2>&1; then
  git lfs install
fi

log "Dependencies installed"
