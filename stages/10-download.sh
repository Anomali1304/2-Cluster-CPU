#!/usr/bin/env bash

set -e
cd "$WORKSPACE"

if [ ! -d ".repo" ]; then
    log "repo init (${GKI_MANIFEST_BRANCH})..."
    repo init --no-repo-verify \
        -u https://android.googlesource.com/kernel/manifest \
        -b "${GKI_MANIFEST_BRANCH}" \
        --repo-rev=main \
        --depth=1
else
    ok ".repo already present, skipping repo init."
fi

CACHED_COMMON=""
if [ -d "common" ]; then
    log "Quarantining cache-restored common/ before repo sync..."
    rm -rf common.cache
    mv common common.cache
    CACHED_COMMON="$WORKSPACE/common.cache"
fi

log "repo sync..."
if ! repo sync -j"$(nproc)" --no-tags --no-clone-bundle --current-branch -f; then
    warn "repo sync failed — retrying with --force-sync."
    if ! repo sync -j"$(nproc)" --no-tags --no-clone-bundle --current-branch -f --force-sync; then
        warn "repo sync still failing — cached repo metadata is unusable. Wiping .repo and rebuilding it cleanly."
        rm -rf .repo
        repo init --no-repo-verify \
            -u https://android.googlesource.com/kernel/manifest \
            -b "${GKI_MANIFEST_BRANCH}" \
            --repo-rev=main \
            --depth=1
        repo sync -j"$(nproc)" --no-tags --no-clone-bundle --current-branch -f --force-sync
    fi
fi

if [ -d "common" ]; then
    for f in build.config.common build.config.aarch64; do
        if [ -f "common/$f" ]; then
            cp -f "common/$f" "$WORKSPACE/$f"
            ok "$f saved to $WORKSPACE/$f"
        else
            warn "common/$f not found — GKI sync may have changed structure."
        fi
    done

    warn "Removing AOSP-provided common/ before cloning ${KERNEL_REPO}..."
    rm -rf common
fi

CLONE_CMD=(git clone --depth=1)
if [ -n "${KERNEL_BRANCH:-}" ]; then
    CLONE_CMD+=(-b "$KERNEL_BRANCH")
fi

CLONE_CMD+=("$KERNEL_REPO" common)

log "Cloning kernel source: ${KERNEL_REPO} ${KERNEL_BRANCH:+(branch: $KERNEL_BRANCH)} -> common/"
"${CLONE_CMD[@]}"
rm -rf "$CACHED_COMMON"
ok "Kernel source ready at $KERNEL_DIR"

if [ "${VIRTUAL_A55_POLICY_SPLIT:-y}" = "y" ]; then
    PATCH_SCRIPT="$ROOT_DIR/kernel/patches/apply_virtual_a55_policy_split.py"
    if [ -f "$PATCH_SCRIPT" ]; then
        log "Applying MT6789 dual-domain unified 16-state cpufreq table..."
        python3 "$PATCH_SCRIPT" "$KERNEL_DIR/drivers/cpufreq/mediatek-cpufreq-hw.c"
        ok "Unified 16-state table applied: CPU0-5 remain one A55 policy; CPU6-7 remain one A76 policy."
    else
        error "Virtual A55 policy split script missing: $PATCH_SCRIPT"
    fi
fi

for f in build.config.common build.config.aarch64; do
    if [ -f "$WORKSPACE/$f" ]; then
        cp -f "$WORKSPACE/$f" "$KERNEL_DIR/$f"
        ok "$f restored to $KERNEL_DIR/$f"
    else
        error "$f not found in workspace — cannot proceed."
    fi
done

if [ "${USE_EXT_MODULES:-y}" = "y" ]; then
    log "Cloning vendor MTK kernel modules (branch: ${VENDOR_MODULES_BRANCH})..."
    mkdir -p "$(dirname "$VENDOR_MODULES_DIR")"
    rm -rf "$VENDOR_MODULES_DIR"
    git clone --depth=1 -b "$VENDOR_MODULES_BRANCH" "$VENDOR_MODULES_REPO" "$VENDOR_MODULES_DIR"
    ok "Vendor modules ready at $VENDOR_MODULES_DIR"
else
    log "USE_EXT_MODULES=n — disabling EXT_MODULES in build.config.rock"
    BUILD_ROCK="$KERNEL_DIR/build.config.rock"
    if [ -f "$BUILD_ROCK" ]; then
        sed -i '/^# Rock_Project: EXT_MODULES override/,+1d' "$BUILD_ROCK"
        printf '\n# Rock_Project: EXT_MODULES override\nEXT_MODULES=""\n' >> "$BUILD_ROCK"
    fi
fi

build_fingerprint > "$WORKSPACE/.fingerprint"
