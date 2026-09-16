#!/usr/bin/env bash
set -e

MODULES_ZIP_NAME="${ZIP_PREFIX}$(get_root_suffix)-modules.zip"
STAGE_DIR="$(mktemp -d)"

KO_COUNT=0
while IFS= read -r ko; do
    name="$(basename "$ko")"
    if [ -n "${MODULES_FILTER:-}" ] && [[ "${name,,}" != *"${MODULES_FILTER,,}"* ]]; then
        continue
    fi
    cp -f "$ko" "$STAGE_DIR/"
    KO_COUNT=$((KO_COUNT + 1))
    log "Module staged: ${name}"
done < <(find "$OUT_DIR" -type f -name '*.ko' 2>/dev/null | sort)

if [ "$KO_COUNT" -eq 0 ]; then
    if [ -n "${MODULES_FILTER:-}" ]; then
        warn "No .ko under \$OUT_DIR matched MODULES_FILTER='${MODULES_FILTER}' — skipping modules zip."
    else
        warn "No .ko found under \$OUT_DIR — skipping modules zip."
    fi
    rm -rf "$STAGE_DIR"
    return 0
fi

ZIP_OUT="$RELEASE_DIR/$MODULES_ZIP_NAME"
rm -f "$ZIP_OUT"
( cd "$STAGE_DIR" && zip -r9 "$ZIP_OUT" . >/dev/null )
rm -rf "$STAGE_DIR"

ok "Modules ZIP: $MODULES_ZIP_NAME (${KO_COUNT} .ko, $(du -sh "$ZIP_OUT" | cut -f1))"
