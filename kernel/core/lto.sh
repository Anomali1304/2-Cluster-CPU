#!/usr/bin/env bash

set -e
ROCK_FRAG="$KERNEL_DIR/arch/arm64/configs/rock.fragment"
[ -f "$ROCK_FRAG" ] || { warn "rock.fragment not found, skipping LTO config."; return 0; }

sed -i '/CONFIG_LTO_CLANG/d;/CONFIG_THINLTO/d;/CONFIG_LTO_CLANG_FULL/d;/CONFIG_LTO_NONE/d' "$ROCK_FRAG"

case "${LTO_MODE:-THIN}" in
    NONE) echo "CONFIG_LTO_NONE=y" >> "$ROCK_FRAG" ;;
    FULL) printf "CONFIG_LTO_CLANG=y\nCONFIG_LTO_CLANG_FULL=y\n" >> "$ROCK_FRAG" ;;
    *)    printf "CONFIG_LTO_CLANG=y\nCONFIG_THINLTO=y\n" >> "$ROCK_FRAG" ;;
esac

ok "LTO mode -> ${LTO_MODE:-THIN}"
