#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${WORKSPACE:-${ROOT_DIR}/workspace}"
KERNEL_DIR="${WORKSPACE}/common"
OUT_DIR="${WORKSPACE}/out"
VENDOR_MODULES_DIR="${WORKSPACE}/vendor/mediatek/kernel_modules"
ANYKERNEL_DIR="${WORKSPACE}/AnyKernel3"
RELEASE_DIR="${ROOT_DIR}/release-out"

mkdir -p "$WORKSPACE" "$RELEASE_DIR"

export ROOT_DIR WORKSPACE KERNEL_DIR OUT_DIR VENDOR_MODULES_DIR ANYKERNEL_DIR RELEASE_DIR

log "Workspace     : $WORKSPACE"
log "Kernel source : $KERNEL_DIR"
log "Output dir    : $OUT_DIR"
log "Release dir   : $RELEASE_DIR"
