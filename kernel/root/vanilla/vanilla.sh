#!/usr/bin/env bash

set -e
cd "$KERNEL_DIR"

source "${ROOT_DIR}/kernel/root/_shared/strip_root.sh"

ok "Root disabled (Vanilla)."
