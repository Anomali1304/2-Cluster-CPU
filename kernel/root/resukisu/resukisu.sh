#!/usr/bin/env bash

set -e
cd "$KERNEL_DIR"
ROCK_FRAG="arch/arm64/configs/rock.fragment"
[ -f "$ROCK_FRAG" ] || error "rock.fragment not found — clone kernel source first."

source "${ROOT_DIR}/kernel/root/_shared/strip_root.sh"

log "Cloning ReSukiSU (branch main)..."
git clone -b main https://github.com/ReSukiSU/ReSukiSU.git KernelSU

if [ -f "KernelSU/kernel/setup.sh" ]; then
    bash KernelSU/kernel/setup.sh main
else
    warn "setup.sh not found, symlinking manually..."
    ln -sf ../KernelSU/kernel drivers/kernelsu
fi
[ -d drivers/kernelsu ] || { [ -d KernelSU/kernel ] && ln -sf ../KernelSU/kernel drivers/kernelsu; }
grep -q "obj-y += kernelsu/" drivers/Makefile || echo "obj-y += kernelsu/" >> drivers/Makefile
grep -q 'source "drivers/kernelsu/Kconfig"' drivers/Kconfig || echo 'source "drivers/kernelsu/Kconfig"' >> drivers/Kconfig

MANUAL_HOOK_AVAIL=0
if grep -q "ksu_handle_newfstat_ret" fs/stat.c 2>/dev/null; then
    MANUAL_HOOK_AVAIL=1
    ok "Manual (inline) hook detected in fs/stat.c"
else
    warn "Manual hook not detected — falling back to KPROBE."
fi

source "${ROOT_DIR}/kernel/root/_shared/susfs.sh"
susfs_install

echo "CONFIG_KSU=y" >> "$ROCK_FRAG"
if [ "$MANUAL_HOOK_AVAIL" -eq 1 ]; then
    echo "CONFIG_KSU_MANUAL_HOOK=y" >> "$ROCK_FRAG"
    ok "Mode: inline hook (manual hook) ACTIVE."
else
    echo "# CONFIG_KSU_MANUAL_HOOK is not set" >> "$ROCK_FRAG"
    printf "CONFIG_KPROBES=y\nCONFIG_KPROBE_EVENTS=y\n" >> "$ROCK_FRAG"
    ok "Mode: KPROBE (fallback)."
fi
[ "$SUSFS_AVAIL" -eq 1 ] && echo "CONFIG_KSU_SUSFS=y" >> "$ROCK_FRAG" \
    || echo "# CONFIG_KSU_SUSFS is not set" >> "$ROCK_FRAG"

ok "ReSukiSU + SUSFS ready."
