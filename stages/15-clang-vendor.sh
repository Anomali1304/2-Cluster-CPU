#!/usr/bin/env bash
set -e

_extract_clang_archive() {
    local archive="$1" dest="$2"
    case "$archive" in
        *.tar.zst|*.zst)
            check_cmd zstd || error "zstd not installed — required to extract $archive (see stages/00-deps.sh)."
            tar --zstd -xf "$archive" -C "$dest"
            ;;
        *.tar.xz|*.xz) tar -xJf "$archive" -C "$dest" ;;
        *)             tar -xf "$archive" -C "$dest" ;;
    esac
}

case "${CLANG_VENDOR:-GKI}" in
    GKI)
        log "CLANG_VENDOR=GKI — using the clang GKI's build/build.sh brings on its own."
        ;;

    ZyC)
        log "CLANG_VENDOR=ZyC — resolving latest ZyCromerZ/Clang release..."
        check_cmd jq || error "jq not installed (see stages/00-deps.sh)."

        asset_url="$(curl -s https://api.github.com/repos/ZyCromerZ/Clang/releases/latest \
            | jq -r '.assets[].browser_download_url' \
            | grep -E 'Clang-.*\.(tar\.gz|tar\.zst|tar\.xz)' \
            | sort -V | tail -1)"
        [ -n "$asset_url" ] || error "No matching Clang asset found in ZyCromerZ/Clang latest release."
        log "ZyC Clang asset: $asset_url"

        target_dir="$WORKSPACE/clang-zyc"
        rm -rf "$target_dir"; mkdir -p "$target_dir"
        tmp_dir="$(mktemp -d)"
        filename="$(basename "${asset_url%%\?*}")"
        [ -n "$filename" ] || filename="clang.tar"
        wget -q "$asset_url" -O "$tmp_dir/$filename" \
            || { rm -rf "$tmp_dir"; error "ZyC Clang download failed."; }
        _extract_clang_archive "$tmp_dir/$filename" "$target_dir" \
            || { rm -rf "$tmp_dir" "$target_dir"; error "ZyC Clang extract failed."; }
        rm -rf "$tmp_dir"

        [ -x "$target_dir/bin/clang" ] || { rm -rf "$target_dir"; error "Extracted ZyC Clang has no bin/clang."; }
        CLANG_CUSTOM_PATH="$target_dir"
        export CLANG_CUSTOM_PATH
        ok "ZyC Clang $(get_clang_version) ready at $CLANG_CUSTOM_PATH"
        ;;

    Custom)
        if [ -x "${CLANG_CUSTOM_PATH}/bin/clang" ]; then
            ok "CLANG_VENDOR=Custom — reusing existing toolchain at $CLANG_CUSTOM_PATH"
        elif [ -n "${CLANG_CUSTOM_URL:-}" ]; then
            log "CLANG_VENDOR=Custom — downloading $CLANG_CUSTOM_URL ..."
            target_dir="$WORKSPACE/clang-custom"
            rm -rf "$target_dir"; mkdir -p "$target_dir"
            tmp_dir="$(mktemp -d)"
            filename="$(basename "${CLANG_CUSTOM_URL%%\?*}")"
            [ -n "$filename" ] || filename="clang.tar"
            wget -q "$CLANG_CUSTOM_URL" -O "$tmp_dir/$filename" \
                || { rm -rf "$tmp_dir"; error "Custom Clang download failed."; }
            _extract_clang_archive "$tmp_dir/$filename" "$target_dir" \
                || { rm -rf "$tmp_dir" "$target_dir"; error "Custom Clang extract failed."; }
            rm -rf "$tmp_dir"
            [ -x "$target_dir/bin/clang" ] || { rm -rf "$target_dir"; error "Extracted Custom Clang has no bin/clang."; }
            CLANG_CUSTOM_PATH="$target_dir"
            export CLANG_CUSTOM_PATH
            ok "Custom Clang $(get_clang_version) ready at $CLANG_CUSTOM_PATH"
        else
            error "CLANG_VENDOR=Custom requires CLANG_CUSTOM_PATH (existing bin/clang) or CLANG_CUSTOM_URL (archive to download)."
        fi
        ;;

    *)
        error "Unknown CLANG_VENDOR=${CLANG_VENDOR} (expected GKI, ZyC, or Custom)."
        ;;
esac
