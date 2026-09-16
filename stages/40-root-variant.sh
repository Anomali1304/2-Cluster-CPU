#!/usr/bin/env bash

set -e
script="${ROOT_DIR}/kernel/root/${ROOT_TYPE,,}/${ROOT_TYPE,,}.sh"
[ -f "$script" ] || error "Unknown ROOT_TYPE=${ROOT_TYPE} (no ${script})"
source "$script"
