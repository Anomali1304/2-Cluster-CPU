#!/usr/bin/env bash

susfs_install() {
    SUSFS_AVAIL=0
    log "Adding SUSFS (optional)..."

    if ! git clone --depth=1 -b gki-android12-5.10 https://gitlab.com/simonpunk/susfs4ksu.git sus_tmp; then
        warn "Could not clone susfs4ksu — SUSFS skipped."
        return
    fi

    cp sus_tmp/kernel_patches/fs/* fs/ 2>/dev/null || true
    cp sus_tmp/kernel_patches/include/linux/* include/linux/ 2>/dev/null || true
    patch -p1 --forward --no-backup-if-mismatch < sus_tmp/kernel_patches/50_add_susfs_in_gki-android12-5.10.patch 2>/dev/null \
        || warn "SUSFS patch warning (may already be applied)."
    rm -rf sus_tmp

    if grep -q "set_nameidata(nd, old_dfd, fake_filename, NULL)" fs/namei.c 2>/dev/null; then
        sed -i 's/set_nameidata(nd, old_dfd, fake_filename, NULL)/set_nameidata(nd, old_dfd, fake_filename)/g' fs/namei.c
        ok "set_nameidata() fixed (3-arg signature)."
    fi

    if [ -f fs/susfs.c ] && [ -f include/linux/susfs.h ]; then
        grep -q "susfs.o" fs/Makefile || echo 'obj-$(CONFIG_KSU_SUSFS) += susfs.o' >> fs/Makefile
        SUSFS_AVAIL=1
        ok "SUSFS installed."
    else
        warn "SUSFS files missing after patch — skipping."
    fi
}
