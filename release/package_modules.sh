#!/usr/bin/env bash

set -e

if [ -z "$ADDONS" ]; then
    log "No addons enabled (\$ADDONS empty) — skipping addons modules zip."
    return 0
fi

ADDONS_ZIP_NAME="${ZIP_PREFIX}$(get_root_suffix)-addons.zip"
STAGE_DIR="$(mktemp -d)"

KO_COUNT=0
IFS=',' read -ra ADDON_LIST <<< "${ADDONS// /}"
for addon in "${ADDON_LIST[@]}"; do
    [ -z "$addon" ] && continue
    ADDON_OUT_DIR="$OUT_DIR/$addon"
    [ -d "$ADDON_OUT_DIR" ] || continue

    while IFS= read -r ko; do
        cp -f "$ko" "$STAGE_DIR/"
        KO_COUNT=$((KO_COUNT + 1))
        log "Addon module staged: $(basename "$ko") (from ${addon})"
    done < <(find "$ADDON_OUT_DIR" -maxdepth 1 -name '*.ko' 2>/dev/null)
done

if [ "$KO_COUNT" -eq 0 ]; then
    warn "Addons enabled (\$ADDONS=$ADDONS) but no .ko files found under \$OUT_DIR/<addon>/ — skipping addons zip."
    rm -rf "$STAGE_DIR"
    return 0
fi

ZIP_OUT="$RELEASE_DIR/$ADDONS_ZIP_NAME"
rm -f "$ZIP_OUT"
( cd "$STAGE_DIR" && zip -r9 "$ZIP_OUT" . >/dev/null )
rm -rf "$STAGE_DIR"

ok "Addons ZIP: $ADDONS_ZIP_NAME (${KO_COUNT} .ko, $(du -sh "$ZIP_OUT" | cut -f1))"
