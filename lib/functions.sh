#!/usr/bin/env bash

log()   { echo "  -> $*"; }
warn()  { echo "  [!] $*" >&2; }
error() { echo "  [x] $*" >&2; exit 1; }
ok()    { echo "  [ok] $*"; }

mode_emoji() {
    case "${1^^}" in
        "DRY RUN") echo "🧪" ;;
        *)         echo "🚀" ;;
    esac
}

check_cmd() { command -v "$1" &>/dev/null; }

fmt_duration() {
    local s=$1
    printf '%dm%02ds' $((s/60)) $((s%60))
}

resolve_android_version() { echo "android12"; }

get_root_suffix() {
    case "${ROOT_TYPE:-VANILLA}" in
        RESUKISU) echo "-ReSukiSU" ;;
        KSUN)     echo "-KSUN" ;;
        *)        echo "" ;;
    esac
}

get_root_label() {
    case "${ROOT_TYPE:-VANILLA}" in
        RESUKISU) echo "ReSukiSU + SUSFS" ;;
        KSUN)     echo "KernelSU-Next + SUSFS (Hybrid)" ;;
        *)        echo "Vanilla (no root)" ;;
    esac
}

build_fingerprint() {
    printf '%s|%s|%s|%s|%s' \
        "${KERNEL_REPO}" "${KERNEL_BRANCH}" "${GKI_MANIFEST_BRANCH}" \
        "${ROOT_TYPE}" "${LTO_MODE}"
}

clang_bin_path() {
    if [ "${CLANG_VENDOR:-GKI}" != "GKI" ] && [ -x "${CLANG_CUSTOM_PATH}/bin/clang" ]; then
        echo "${CLANG_CUSTOM_PATH}/bin/clang"
        return
    fi
    local rel_path common_cfg="${WORKSPACE}/common/build.config.common"
    if [ -f "$common_cfg" ]; then
        rel_path="$(grep -E '^CLANG_PREBUILT_BIN=' "$common_cfg" | head -1 | cut -d= -f2 | tr -d '"')"
        [ -n "$rel_path" ] && [ -x "${WORKSPACE}/${rel_path}/clang" ] && { echo "${WORKSPACE}/${rel_path}/clang"; return; }
    fi
    echo "clang"
}

get_clang_version() {
    local bin ver
    bin="$(clang_bin_path)"
    check_cmd "$bin" || { echo "Unknown"; return; }
    ver="$("$bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    [ -z "$ver" ] && ver="$("$bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    echo "${ver:-Unknown}"
}

clang_vendor_label() {
    case "${CLANG_VENDOR:-GKI}" in
        ZyC)    echo "ZyC Clang" ;;
        Custom) echo "Custom Clang" ;;
        *)      echo "Clang" ;;
    esac
}

clang_has_polly() {
    local bin; bin="$(clang_bin_path)"
    echo "" | "$bin" -mllvm -polly -O3 -c -x c - -o /dev/null 2>&1 \
        | grep -qi "unknown argument\|unrecognized" && return 1
    return 0
}
