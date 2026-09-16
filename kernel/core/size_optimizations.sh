#!/usr/bin/env bash

set -e
ROCK_FRAG="$KERNEL_DIR/arch/arm64/configs/rock.fragment"
[ -f "$ROCK_FRAG" ] || { warn "rock.fragment not found, skipping size optimizations."; return 0; }

sed -i '/CONFIG_KERNEL_/d' "$ROCK_FRAG"
echo "CONFIG_KERNEL_GZIP=y" >> "$ROCK_FRAG"
ok "Kernel compression -> GZIP"

if [ "${STRIP_DEBUG:-y}" = "y" ]; then
    sed -i '/CONFIG_DEBUG_INFO/d;/CONFIG_DEBUG_FS/d;/CONFIG_TRACING/d' "$ROCK_FRAG"
    {
        echo "CONFIG_DEBUG_INFO=n"
        echo "# CONFIG_DEBUG_INFO is not set"
        echo "# CONFIG_DEBUG_FS is not set"
        echo "# CONFIG_TRACING is not set"
    } >> "$ROCK_FRAG"
    ok "Debug info / tracing disabled."
else
    ok "STRIP_DEBUG=n — rock.fragment untouched, debug info left at defconfig defaults."
fi

BUILD_CONFIG_ROCK="$KERNEL_DIR/build.config.rock"
if [ -f "$BUILD_CONFIG_ROCK" ]; then
    sed -i '/KBUILD_CFLAGS.*-fno-unwind-tables/d;/KBUILD_CFLAGS.*-fno-asynchronous-unwind-tables/d' "$BUILD_CONFIG_ROCK"
    ok "Size-saving CFLAGS appended to build.config.rock."
fi
