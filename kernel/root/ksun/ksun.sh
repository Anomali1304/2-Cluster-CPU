#!/usr/bin/env bash

set -e
cd "$KERNEL_DIR"
ROCK_FRAG="arch/arm64/configs/rock.fragment"
[ -f "$ROCK_FRAG" ] || error "rock.fragment not found — clone kernel source first."

source "${ROOT_DIR}/kernel/root/_shared/strip_root.sh"

log "Cloning KernelSU-Next (branch dev-susfs)..."
git clone -b dev-susfs https://github.com/pershoot/KernelSU-Next.git KernelSU-Next

if [ -f "KernelSU-Next/kernel/setup.sh" ]; then
    bash KernelSU-Next/kernel/setup.sh dev-susfs
else
    warn "setup.sh not found, symlinking manually..."
    ln -sf ../KernelSU-Next/kernel drivers/kernelsu
fi
[ -d drivers/kernelsu ] || { [ -d KernelSU-Next/kernel ] && ln -sf ../KernelSU-Next/kernel drivers/kernelsu; }
grep -q "obj-y += kernelsu/" drivers/Makefile || echo "obj-y += kernelsu/" >> drivers/Makefile
grep -q 'source "drivers/kernelsu/Kconfig"' drivers/Kconfig || echo 'source "drivers/kernelsu/Kconfig"' >> drivers/Kconfig

source "${ROOT_DIR}/kernel/root/_shared/susfs.sh"
susfs_install

printf "CONFIG_KSU=y\n# CONFIG_KSU_MANUAL_HOOK is not set\nCONFIG_KPROBES=y\nCONFIG_KPROBE_EVENTS=y\n" >> "$ROCK_FRAG"
[ "$SUSFS_AVAIL" -eq 1 ] && echo "CONFIG_KSU_SUSFS=y" >> "$ROCK_FRAG" \
    || echo "# CONFIG_KSU_SUSFS is not set" >> "$ROCK_FRAG"

ok "KernelSU-Next + SUSFS (optional) ready — Hybrid (KPROBE) mode."
