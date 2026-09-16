#!/usr/bin/env bash
set -eo pipefail
exec 2>&1

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${ROOT_DIR}/lib/functions.sh"
source "${ROOT_DIR}/config/defaults.env"

DRY_RUN="false"
[ "${RUN_MODE}" = "Dry Run" ] && DRY_RUN="true"
export DRY_RUN

source "${ROOT_DIR}/lib/paths.sh"

main() {
    print_banner

    stage "⚙️ Setup"          "${ROOT_DIR}/stages/00-deps.sh"
    stage "📥 Kernel Source"  "${ROOT_DIR}/stages/10-download.sh"
    stage "🛠️ Clang Vendor (${CLANG_VENDOR})" "${ROOT_DIR}/stages/15-clang-vendor.sh"
    stage "🔖 Branding"       "${ROOT_DIR}/stages/20-branding.sh"
    stage "🔧 Core"           "${ROOT_DIR}/stages/30-core.sh"
    stage "🍀 Root Solution (${ROOT_TYPE})" "${ROOT_DIR}/stages/40-root-variant.sh"
    stage "🧩 Addons: stage"  "${ROOT_DIR}/stages/50-addons-stage.sh"

    stage "🏗️ Build Kernel"   "${ROOT_DIR}/stages/60-build-kernel.sh"

    if [ "${DRY_RUN}" = "true" ]; then
        echo "========================================"
        echo " 🧪 Dry Run complete — no compile, no release."
        echo "========================================"
        exit 0
    fi

    stage "🧩 Addons: compile" "${ROOT_DIR}/stages/70-addons-compile.sh"
    stage "🚀 Release"         "${ROOT_DIR}/stages/80-release.sh"

    echo "========================================"
    echo " ✅ ${RUN_MODE} complete!"
    echo " 🏷️  ${KERNEL_NAME} ($(get_root_label))"
    [ -n "$ADDONS" ] && echo " ⚡ Addons packaged : ${ADDONS}"
    echo " 📦 Modules packaged: all .ko from this run${MODULES_FILTER:+ (filter: $MODULES_FILTER)}"
    echo "========================================"
}

print_banner() {
    echo "========================================"
    echo " 🪨  Rock Project"
    echo "========================================"
    echo " 🏷️  ${KERNEL_NAME} ($(get_root_label))"
    echo " 🔧 $(mode_emoji "$RUN_MODE") ${RUN_MODE}"
    echo " 🖥️  CPU: $(nproc) cores"
    echo " 📅 $(date)"
    echo " 🛠️  Clang: ${CLANG_VENDOR}"
    [ -n "$ADDONS" ] && echo " ⚡ Addons: ${ADDONS}"
    echo "========================================"
}

stage() {
    local title="$1" script="$2"
    echo "::group::${title}"
    source "$script"
    echo "::endgroup::"
}

main "$@"
