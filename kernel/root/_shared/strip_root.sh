#!/usr/bin/env bash

rm -rf KernelSU KernelSU-Next
[ -L drivers/kernelsu ] && rm -f drivers/kernelsu
[ -d drivers/kernelsu ] && rm -rf drivers/kernelsu
sed -i '/kernelsu/d' drivers/Makefile 2>/dev/null || true
sed -i '/kernelsu/d' drivers/Kconfig 2>/dev/null || true

rm -f fs/susfs.c include/linux/susfs.h 2>/dev/null
sed -i '/susfs/d' fs/Makefile 2>/dev/null || true

ROCK_FRAG="arch/arm64/configs/rock.fragment"
if [ -f "$ROCK_FRAG" ]; then
    sed -i '/CONFIG_KSU/d;/CONFIG_KSU_SUSFS/d;/CONFIG_KSU_MANUAL_HOOK/d;/CONFIG_KPROBES/d;/CONFIG_KPROBE_EVENTS/d' "$ROCK_FRAG"
fi
