#!/usr/bin/env bash
set -e

if [ -n "$ADDONS" ]; then
    IFS=',' read -ra ADDON_LIST <<< "${ADDONS// /}"
    for addon in "${ADDON_LIST[@]}"; do
        [ -z "$addon" ] && continue

        SRC_DIR="${ROOT_DIR}/addons/${addon}"
        STAGE_DIR="${WORKSPACE}/addons/${addon}"

        [ -d "$SRC_DIR" ] || error "Addon not found: ${addon} (expected ${SRC_DIR}) — add a dir with ${addon}.c + Makefile, see docs/ADDONS.md."
        [ -f "$SRC_DIR/${addon}.c" ] || error "${addon}: expected source file ${SRC_DIR}/${addon}.c not found (folder name must match the .c filename)."
        [ -f "$SRC_DIR/Makefile" ]   || error "${addon}: Makefile not found in ${SRC_DIR}."

        rm -rf "$STAGE_DIR"
        mkdir -p "$STAGE_DIR"
        cp -a "$SRC_DIR"/. "$STAGE_DIR"/

        ok "${addon}: staged at ${STAGE_DIR} (compiled in stages/70-addons-compile.sh)."
    done
fi
