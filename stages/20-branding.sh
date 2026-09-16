#!/usr/bin/env bash

set -e
ROCK_FRAG="$KERNEL_DIR/arch/arm64/configs/rock.fragment"

if [ -f "$ROCK_FRAG" ]; then
    sed -i '/CONFIG_LOCALVERSION/d' "$ROCK_FRAG"
    echo "CONFIG_LOCALVERSION=\"-${KERNEL_NAME}\"" >> "$ROCK_FRAG"
    echo "CONFIG_LOCALVERSION_AUTO=n" >> "$ROCK_FRAG"
    ok "rock.fragment: LOCALVERSION -> -${KERNEL_NAME}"
else
    warn "rock.fragment not found, skipping LOCALVERSION patch."
fi

echo "" > "$KERNEL_DIR/.scmversion"

export KBUILD_BUILD_USER="$BUILD_USER_NAME"
export KBUILD_BUILD_HOST="$BUILD_HOST_NAME"
log "KBUILD_BUILD_USER/HOST -> ${BUILD_USER_NAME}@${BUILD_HOST_NAME}"

MKCOMPILE_H="$KERNEL_DIR/scripts/mkcompile_h"
if [ -f "$MKCOMPILE_H" ] && ! grep -q "Rock_Project: patched" "$MKCOMPILE_H"; then
    cp -f "$MKCOMPILE_H" "${MKCOMPILE_H}.orig"
    sed -i "1i # Rock_Project: patched" "$MKCOMPILE_H"

    polly_flag=""
    clang_has_polly && polly_flag=" (+Polly)"
    COMPILER_STRING="$(clang_vendor_label) $(get_clang_version)${polly_flag}"

    if grep -q 'printf .#define LINUX_COMPILER' "$MKCOMPILE_H"; then
        sed -i '/printf .#define LINUX_COMPILER/c\printf '\''#define LINUX_COMPILER "%s"\\n'\'' "'"$COMPILER_STRING"'"' "$MKCOMPILE_H"
    elif grep -q '^echo "#define LINUX_COMPILER' "$MKCOMPILE_H"; then
        sed -i '/^echo "#define LINUX_COMPILER/c\echo "#define LINUX_COMPILER \"'"$COMPILER_STRING"'\""' "$MKCOMPILE_H"
    else
        echo "#define LINUX_COMPILER \"$COMPILER_STRING\"" >> "$MKCOMPILE_H"
    fi
    ok "mkcompile_h patched -> LINUX_COMPILER: ${COMPILER_STRING} (stable across CI reruns, no host toolchain junk in /proc/version)."
fi
