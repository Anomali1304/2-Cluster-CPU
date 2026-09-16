#!/usr/bin/env bash
set -e

if [ -n "$ADDONS" ]; then
    IFS=',' read -ra ADDON_LIST <<< "${ADDONS// /}"
    for addon in "${ADDON_LIST[@]}"; do
        [ -z "$addon" ] && continue

        STAGE_DIR="${WORKSPACE}/addons/${addon}"
        [ -d "$STAGE_DIR" ] || error "${addon}: staged source missing — did stages/50-addons-stage.sh run?"

        log "Compiling addon: ${addon}"

        SYMVERS="$(find "$OUT_DIR" "$KERNEL_DIR" -maxdepth 4 -name Module.symvers 2>/dev/null | head -1)"
        [ -n "$SYMVERS" ] || error "${addon}: Module.symvers not found under \$OUT_DIR or \$KERNEL_DIR — kernel build stage must complete first."

        KBUILD_DIR="$(dirname "$SYMVERS")"
        log "${addon}: building against KDIR=$KBUILD_DIR"

        CLANG_BIN="$(clang_bin_path)"
        [ -x "$CLANG_BIN" ] || error "${addon}: clang not found at $CLANG_BIN (CLANG_VENDOR=${CLANG_VENDOR:-GKI})"
        CLANG_BIN_DIR="$(dirname "$CLANG_BIN")"
        log "${addon}: using ${CLANG_VENDOR:-GKI} clang -> $CLANG_BIN ($("$CLANG_BIN" --version | head -1))"

        : "${CROSS_COMPILE:=aarch64-linux-gnu-}"
        : "${CLANG_TRIPLE:=aarch64-linux-gnu-}"

        PATH="$CLANG_BIN_DIR:$PATH" \
        make -C "$STAGE_DIR" \
            KDIR="$KBUILD_DIR" \
            ARCH=arm64 \
            CROSS_COMPILE="$CROSS_COMPILE" \
            CC="$CLANG_BIN_DIR/clang" \
            CLANG_TRIPLE="$CLANG_TRIPLE" \
            LLVM=1 \
            LLVM_IAS=1 \
            KCFLAGS="${KCFLAGS:--Wno-unused-command-line-argument}"

        KO="$STAGE_DIR/${addon}.ko"
        [ -f "$KO" ] || error "${addon}: build finished but ${addon}.ko not found (obj-m target must match the addon's dir/file name)."

        mkdir -p "$OUT_DIR/${addon}"
        cp -f "$KO" "$OUT_DIR/${addon}/"
        ok "${addon}.ko built -> $OUT_DIR/${addon}/${addon}.ko"
    done
fi
