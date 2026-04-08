#!/usr/bin/env bash
# rimshot installer - Installs rimshot into ~/.claude/rimshot
# https://github.com/dbfarias/rimshot
#
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly INSTALL_DIR="${HOME}/.claude/rimshot"
readonly SETTINGS_FILE="${HOME}/.claude/settings.json"
readonly HOOK_COMMAND="${INSTALL_DIR}/scripts/rimshot.sh"

# --- Colors (disabled if not a terminal) -------------------------------------

if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# --- Helpers -----------------------------------------------------------------

info()  { printf "${BLUE}[info]${NC}  %s\n" "$1"; }
ok()    { printf "${GREEN}[ok]${NC}    %s\n" "$1"; }
warn()  { printf "${YELLOW}[warn]${NC}  %s\n" "$1"; }
error() { printf "${RED}[error]${NC} %s\n" "$1" >&2; }
die()   { error "$1"; exit 1; }

usage() {
    cat <<'EOF'
Usage: install.sh [OPTIONS]

Options:
    --lang LANG     Set default language (en, pt-BR, es, fr)
    --frequency N   Joke frequency 0-100 (default: 30)
    --cooldown N    Min seconds between jokes (default: 10)
    --dry-run       Show what would be done without doing it
    --uninstall     Remove rimshot (alias for uninstall.sh)
    -h, --help      Show this help message
EOF
}

# --- Argument parsing --------------------------------------------------------

DRY_RUN=false
LANG_OPT=""
FREQUENCY_OPT=""
COOLDOWN_OPT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lang)
            [[ -z "${2:-}" ]] && die "--lang requires a value"
            LANG_OPT="$2"
            shift 2
            ;;
        --frequency)
            [[ -z "${2:-}" ]] && die "--frequency requires a value"
            FREQUENCY_OPT="$2"
            shift 2
            ;;
        --cooldown)
            [[ -z "${2:-}" ]] && die "--cooldown requires a value"
            COOLDOWN_OPT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --uninstall)
            if [[ -f "${SCRIPT_DIR}/uninstall.sh" ]]; then
                exec "${SCRIPT_DIR}/uninstall.sh"
            else
                die "uninstall.sh not found"
            fi
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1 (use --help for usage)"
            ;;
    esac
done

# --- Dependency checks -------------------------------------------------------

check_dependencies() {
    local missing=()

    if ! command -v jq &>/dev/null; then
        missing+=("jq")
    fi

    if ! command -v bash &>/dev/null; then
        missing+=("bash")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required dependencies: ${missing[*]}. Install them first."
    fi

    # Check bash version >= 4 (for associative arrays / mapfile)
    local bash_version
    bash_version="${BASH_VERSINFO[0]}"
    if (( bash_version < 4 )); then
        warn "Bash ${BASH_VERSION} detected. Version 4+ recommended."
        warn "On macOS, install with: brew install bash"
    fi
}

# --- Validation --------------------------------------------------------------

validate_lang() {
    local lang="$1"

    # Validate against available joke files (auto-discovers new languages)
    if [[ -f "${SCRIPT_DIR}/jokes/${lang}.txt" ]]; then
        return 0
    fi

    local available
    available=$(find "${SCRIPT_DIR}/jokes" -name '*.txt' -exec basename {} .txt \; | sort | tr '\n' ', ' | sed 's/,$//')
    die "Invalid language: ${lang}. Available: ${available}"
}

validate_frequency() {
    local freq="$1"

    if ! [[ "${freq}" =~ ^[0-9]+$ ]] || (( freq < 0 || freq > 100 )); then
        die "Invalid frequency: ${freq}. Must be 0-100."
    fi
}

validate_cooldown() {
    local cd="$1"

    if ! [[ "${cd}" =~ ^[0-9]+$ ]]; then
        die "Invalid cooldown: ${cd}. Must be a positive integer."
    fi
}

# --- Installation ------------------------------------------------------------

install_files() {
    info "Installing rimshot to ${INSTALL_DIR}"

    if [[ "${DRY_RUN}" == true ]]; then
        info "[dry-run] Would copy files to ${INSTALL_DIR}"
        return
    fi

    mkdir -p "${INSTALL_DIR}"

    # Copy project files
    cp -r "${SCRIPT_DIR}/scripts" "${INSTALL_DIR}/"
    cp -r "${SCRIPT_DIR}/jokes" "${INSTALL_DIR}/"

    # Make hook script executable
    chmod +x "${INSTALL_DIR}/scripts/rimshot.sh"

    ok "Files installed to ${INSTALL_DIR}"
}

create_config() {
    local config_file="${INSTALL_DIR}/rimshot.conf"
    local lang="${LANG_OPT:-en}"
    local freq="${FREQUENCY_OPT:-30}"
    local cooldown="${COOLDOWN_OPT:-10}"

    if [[ -n "${LANG_OPT}" ]]; then
        validate_lang "${LANG_OPT}"
    fi

    if [[ -n "${FREQUENCY_OPT}" ]]; then
        validate_frequency "${FREQUENCY_OPT}"
    fi

    if [[ -n "${COOLDOWN_OPT}" ]]; then
        validate_cooldown "${COOLDOWN_OPT}"
    fi

    if [[ "${DRY_RUN}" == true ]]; then
        info "[dry-run] Would create config: LANG=${lang}, FREQUENCY=${freq}, COOLDOWN=${cooldown}"
        return
    fi

    # Don't overwrite existing config
    if [[ -f "${config_file}" ]]; then
        warn "Config file already exists. Keeping existing: ${config_file}"
        return
    fi

    cat > "${config_file}" <<EOF
# rimshot configuration
# See: https://github.com/dbfarias/rimshot#configuration

# Language for jokes (en, pt-BR, es, fr)
LANG=${lang}

# Percentage chance of showing a joke per tool call (0-100)
FREQUENCY=${freq}

# Minimum seconds between jokes to avoid noise (0 to disable)
COOLDOWN=${cooldown}
EOF

    ok "Config created: ${config_file}"
}

patch_settings() {
    info "Configuring Claude Code hook"

    if [[ "${DRY_RUN}" == true ]]; then
        info "[dry-run] Would add PreToolUse hook to ${SETTINGS_FILE}"
        return
    fi

    # Create settings directory if needed
    mkdir -p "$(dirname "${SETTINGS_FILE}")"

    # Create settings file if it doesn't exist
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        echo '{}' > "${SETTINGS_FILE}"
        info "Created ${SETTINGS_FILE}"
    fi

    # Validate existing JSON
    if ! jq empty "${SETTINGS_FILE}" 2>/dev/null; then
        die "${SETTINGS_FILE} contains invalid JSON. Please fix it manually."
    fi

    # Check if hook is already installed (idempotent)
    local already_installed
    already_installed=$(jq --arg cmd "${HOOK_COMMAND}" '
        (.hooks.PreToolUse // [])
        | map(.hooks // [])
        | flatten
        | map(select(.command == $cmd))
        | length
    ' "${SETTINGS_FILE}" 2>/dev/null || echo "0")

    if (( already_installed > 0 )); then
        ok "Hook already configured in settings.json"
        return
    fi

    # Backup before modifying
    cp "${SETTINGS_FILE}" "${SETTINGS_FILE}.rimshot-backup"
    info "Backup saved: ${SETTINGS_FILE}.rimshot-backup"

    # Add hook using jq (safe JSON manipulation)
    local hook_entry
    hook_entry=$(jq -n --arg cmd "${HOOK_COMMAND}" '{
        matcher: ".*",
        hooks: [{
            type: "command",
            command: $cmd
        }]
    }')

    local tmp_file
    tmp_file=$(mktemp "${SETTINGS_FILE}.tmp.XXXXXX")
    trap 'rm -f "${tmp_file}"' EXIT

    jq --argjson hook "${hook_entry}" '
        .hooks //= {} |
        .hooks.PreToolUse //= [] |
        .hooks.PreToolUse += [$hook]
    ' "${SETTINGS_FILE}" > "${tmp_file}"

    mv "${tmp_file}" "${SETTINGS_FILE}"
    trap - EXIT

    ok "Hook added to ${SETTINGS_FILE}"
}

# --- Summary -----------------------------------------------------------------

print_summary() {
    printf '\n'
    printf "${GREEN}%s${NC}\n" "============================================"
    printf "${GREEN}%s${NC}\n" "  rimshot installed successfully!"
    printf "${GREEN}%s${NC}\n" "============================================"
    printf '\n'
    printf "  Jokes directory:  %s\n" "${INSTALL_DIR}/jokes/"
    printf "  Config file:      %s\n" "${INSTALL_DIR}/rimshot.conf"
    printf "  Hook script:      %s\n" "${HOOK_COMMAND}"
    printf '\n'
    printf "  Edit config:      %s\n" "\$EDITOR ${INSTALL_DIR}/rimshot.conf"
    printf "  Test it:          %s\n" "${HOOK_COMMAND}"
    printf "  Uninstall:        %s\n" "${SCRIPT_DIR}/uninstall.sh"
    printf '\n'
}

# --- Main --------------------------------------------------------------------

main() {
    printf '\n'
    info "rimshot installer"
    printf '\n'

    check_dependencies
    install_files
    create_config
    patch_settings

    if [[ "${DRY_RUN}" == false ]]; then
        print_summary
    else
        printf '\n'
        ok "[dry-run] Complete. No changes were made."
    fi
}

main
