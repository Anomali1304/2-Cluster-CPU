#!/usr/bin/env bash

set -e
ROOT_SUFFIX="$(get_root_suffix)"
ZIP_NAME="${ZIP_PREFIX}${ROOT_SUFFIX}.zip"

if [ ! -d "$ANYKERNEL_DIR/.git" ]; then
    log "Cloning AnyKernel3..."
    git clone --depth=1 -b rock https://github.com/Anomali1304/AnyKernel3.git "$ANYKERNEL_DIR"
fi

rm -f "$ANYKERNEL_DIR"/Image "$ANYKERNEL_DIR"/Image.gz "$ANYKERNEL_DIR"/Image.gz-dtb

BUILT_IMAGE="$(find "$OUT_DIR" -type f \( -name Image.gz -o -name Image.gz-dtb \) -not -path '*/obj/*' 2>/dev/null | head -1)"

if [ -n "$BUILT_IMAGE" ]; then
    cp -f "$BUILT_IMAGE" "$ANYKERNEL_DIR/$(basename "$BUILT_IMAGE")"
    log "Using pre-compressed image: $(basename "$BUILT_IMAGE")"
else
    RAW_IMAGE="$(find "$OUT_DIR" -type f -name Image -not -path '*/obj/*' 2>/dev/null | head -1)"
    [ -n "$RAW_IMAGE" ] || error "No kernel Image found in \$OUT_DIR — build must complete first."
    log "No pre-compressed image found — gzip-ing $(basename "$RAW_IMAGE") myself"
    gzip -c "$RAW_IMAGE" > "$ANYKERNEL_DIR/Image.gz"
fi

ZIP_OUT="$RELEASE_DIR/$ZIP_NAME"
rm -f "$ZIP_OUT"
( cd "$ANYKERNEL_DIR" && zip -r9 "$ZIP_OUT" . -x '*.git*' '*.DS_Store*' 'README.md' 'modules/*' >/dev/null )

ok "Flashable ZIP: $ZIP_NAME ($(du -sh "$ZIP_OUT" | cut -f1)) — kernel image only, no modules"
