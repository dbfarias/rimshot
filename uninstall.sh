#!/usr/bin/env bash
# rimshot uninstaller - Removes rimshot from ~/.claude/rimshot
# https://github.com/dbfarias/rimshot
#
# SPDX-License-Identifier: MIT

set -euo pipefail

readonly INSTALL_DIR="${HOME}/.claude/rimshot"
readonly SETTINGS_FILE="${HOME}/.claude/settings.json"
readonly HOOK_COMMAND="${INSTALL_DIR}/scripts/rimshot.sh"
readonly COOLDOWN_FILE="${TMPDIR:-/tmp}/rimshot_cooldown_${UID}"

# --- Colors ------------------------------------------------------------------

if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

info()  { printf "${BLUE}[info]${NC}  %s\n" "$1"; }
ok()    { printf "${GREEN}[ok]${NC}    %s\n" "$1"; }
warn()  { printf "${YELLOW}[warn]${NC}  %s\n" "$1"; }
error() { printf "${RED}[error]${NC} %s\n" "$1" >&2; }

# --- Uninstallation ----------------------------------------------------------

remove_hook() {
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        info "No settings.json found, nothing to remove"
        return
    fi

    if ! command -v jq &>/dev/null; then
        error "jq is required to safely modify settings.json"
        error "Please manually remove the rimshot hook from ${SETTINGS_FILE}"
        error "Files not removed to avoid leaving a dangling hook."
        return 1
    fi

    # Check if hook exists
    local hook_count
    hook_count=$(jq --arg cmd "${HOOK_COMMAND}" '
        (.hooks.PreToolUse // [])
        | map(.hooks // [])
        | flatten
        | map(select(.command == $cmd))
        | length
    ' "${SETTINGS_FILE}" 2>/dev/null || echo "0")

    if (( hook_count == 0 )); then
        info "No rimshot hook found in settings.json"
        return
    fi

    # Backup before modifying
    cp "${SETTINGS_FILE}" "${SETTINGS_FILE}.rimshot-uninstall-backup"
    info "Backup saved: ${SETTINGS_FILE}.rimshot-uninstall-backup"

    # Remove hook entries that reference rimshot
    local tmp_file
    tmp_file=$(mktemp "${SETTINGS_FILE}.tmp.XXXXXX")
    trap 'rm -f "${tmp_file}"' EXIT

    jq --arg cmd "${HOOK_COMMAND}" '
        .hooks.PreToolUse = [
            .hooks.PreToolUse[]
            | select(
                (.hooks // [])
                | map(select(.command == $cmd))
                | length == 0
            )
        ]
        | if (.hooks.PreToolUse | length) == 0 then del(.hooks.PreToolUse) else . end
        | if (.hooks | length) == 0 then del(.hooks) else . end
    ' "${SETTINGS_FILE}" > "${tmp_file}"

    mv "${tmp_file}" "${SETTINGS_FILE}"
    trap - EXIT
    ok "Hook removed from settings.json"
}

remove_files() {
    if [[ -d "${INSTALL_DIR}" ]]; then
        rm -rf "${INSTALL_DIR}"
        ok "Removed ${INSTALL_DIR}"
    else
        info "Install directory not found: ${INSTALL_DIR}"
    fi

    # Clean up cooldown file
    if [[ -f "${COOLDOWN_FILE}" ]]; then
        rm -f "${COOLDOWN_FILE}"
    fi
}

# --- Main --------------------------------------------------------------------

main() {
    printf '\n'
    info "rimshot uninstaller"
    printf '\n'

    if ! remove_hook; then
        exit 1
    fi
    remove_files

    printf '\n'
    ok "rimshot has been uninstalled. We'll miss the laughs!"
    printf '\n'
}

main
