#!/usr/bin/env bash

set -e
cd "$WORKSPACE"

[ -f "build/build.sh" ]                || error "build/build.sh not found — did repo sync run?"
[ -f "$KERNEL_DIR/build.config.rock" ]  || error "common/build.config.rock not found."

sed -i '/build.config.common/d; /build.config.aarch64/d' "$KERNEL_DIR/build.config.rock"
sed -i '1i . ./build.config.common' "$KERNEL_DIR/build.config.rock"
sed -i '2i . ./build.config.aarch64' "$KERNEL_DIR/build.config.rock"
sed -i 's|\${ROOT_DIR}/\${KERNEL_DIR}/|${KERNEL_DIR}/|g' "$KERNEL_DIR/build.config.rock"
log "build.config.rock: source paths fixed."

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

export KBUILD_BUILD_VERSION="1"
export KBUILD_BUILD_USER="$BUILD_USER_NAME"
export KBUILD_BUILD_HOST="$BUILD_HOST_NAME"

if [ "${CLANG_VENDOR:-GKI}" != "GKI" ] && [ -x "${CLANG_CUSTOM_PATH}/bin/clang" ]; then
    rel_clang_bin="$(realpath --relative-to="$WORKSPACE" "${CLANG_CUSTOM_PATH}/bin")"
    common_cfg="$KERNEL_DIR/build.config.common"
    if [ -f "$common_cfg" ] && grep -q '^CLANG_PREBUILT_BIN=' "$common_cfg"; then
        sed -i "s|^CLANG_PREBUILT_BIN=.*|CLANG_PREBUILT_BIN=${rel_clang_bin}|" "$common_cfg"
        log "build.config.common: CLANG_PREBUILT_BIN -> ${rel_clang_bin}"
    else
        error "common/build.config.common missing CLANG_PREBUILT_BIN — cannot force ${CLANG_VENDOR} clang onto the GKI build."
    fi

    export PATH="${CLANG_CUSTOM_PATH}/bin:${PATH}"
    export LD_LIBRARY_PATH="${CLANG_CUSTOM_PATH}/lib:${LD_LIBRARY_PATH:-}"
    log "Using ${CLANG_VENDOR} clang from ${CLANG_CUSTOM_PATH}"
fi
export KBUILD_COMPILER_STRING="$(clang_vendor_label) $(get_clang_version)"
log "KBUILD_COMPILER_STRING -> ${KBUILD_COMPILER_STRING}"

export KCFLAGS="${KCFLAGS:+$KCFLAGS }-Wno-unused-command-line-argument"
log "KCFLAGS -> ${KCFLAGS}"

if [ "${DRY_RUN:-false}" = "true" ]; then
    warn "DRY_RUN=true — skipping actual compile."
else
    log "Building (BUILD_CONFIG=common/build.config.rock)..."
    start_time=$(date +%s)

    set -o pipefail
    BUILD_CONFIG=common/build.config.rock bash build/build.sh 2>&1 | tee "$WORKSPACE/build.log"
    build_exit=${PIPESTATUS[0]}
    set +o pipefail

    elapsed=$(( $(date +%s) - start_time ))
    echo "$(fmt_duration "$elapsed")" > "$OUT_DIR/.build_time"

    built_image="$(find "$OUT_DIR" -type f \( -name Image -o -name Image.gz -o -name Image.gz-dtb \) -not -path '*/obj/*' 2>/dev/null | head -1)"

    if [ "$build_exit" -ne 0 ] && [ -z "$built_image" ]; then
        error "Build failed after $(fmt_duration "$elapsed") (exit $build_exit) — see build.log"
    fi

    ok "Build finished in $(fmt_duration "$elapsed")."
fi
