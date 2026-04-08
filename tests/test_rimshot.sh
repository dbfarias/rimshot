#!/usr/bin/env bash
# rimshot test suite - Plain bash assertions (no external dependencies)
# https://github.com/dbfarias/rimshot
#
# Usage: bash tests/test_rimshot.sh
#
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_DIR
readonly RIMSHOT_SCRIPT="${PROJECT_DIR}/scripts/rimshot.sh"
readonly JOKES_DIR="${PROJECT_DIR}/jokes"

# --- Test framework ----------------------------------------------------------

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' NC=''
fi

pass() {
    TESTS_PASSED=$(( TESTS_PASSED + 1 ))
    printf "${GREEN}  PASS${NC} %s\n" "$1"
}

fail() {
    TESTS_FAILED=$(( TESTS_FAILED + 1 ))
    printf "${RED}  FAIL${NC} %s: %s\n" "$1" "$2"
}

run_test() {
    TESTS_RUN=$(( TESTS_RUN + 1 ))
    "$1"
}

# --- Joke file tests ---------------------------------------------------------

test_joke_files_exist() {
    local name="joke files exist"
    local required=("en.txt" "pt-BR.txt")

    for file in "${required[@]}"; do
        if [[ ! -f "${JOKES_DIR}/${file}" ]]; then
            fail "${name}" "missing ${file}"
            return
        fi
    done

    pass "${name}"
}

test_joke_files_not_empty() {
    local name="joke files are not empty"

    for file in "${JOKES_DIR}"/*.txt; do
        local joke_count=0
        while IFS= read -r line; do
            [[ -z "${line}" || "${line}" == \#* ]] && continue
            joke_count=$(( joke_count + 1 ))
        done < "${file}"

        if (( joke_count < 10 )); then
            fail "${name}" "$(basename "${file}") has only ${joke_count} jokes (min 10)"
            return
        fi
    done

    pass "${name}"
}

test_joke_files_valid_utf8() {
    local name="joke files are valid UTF-8"

    for file in "${JOKES_DIR}"/*.txt; do
        if ! file "${file}" | grep -qi "text"; then
            fail "${name}" "$(basename "${file}") is not a text file"
            return
        fi
    done

    pass "${name}"
}

test_joke_files_no_trailing_whitespace() {
    local name="no trailing whitespace in joke files"

    for file in "${JOKES_DIR}"/*.txt; do
        local trailing
        trailing=$(grep -Pn '\s+$' "${file}" 2>/dev/null | head -1 || true)
        if [[ -n "${trailing}" ]]; then
            fail "${name}" "$(basename "${file}"):${trailing}"
            return
        fi
    done

    pass "${name}"
}

test_joke_lines_reasonable_length() {
    local name="jokes are reasonable length (< 300 chars)"

    for file in "${JOKES_DIR}"/*.txt; do
        local line_num=0
        local fname
        fname=$(basename "${file}")
        # shellcheck disable=SC2094  # false positive: basename doesn't write to file
        while IFS= read -r line; do
            line_num=$(( line_num + 1 ))
            [[ -z "${line}" || "${line}" == \#* ]] && continue

            if (( ${#line} > 300 )); then
                fail "${name}" "${fname}:${line_num} is ${#line} chars"
                return
            fi
        done < "${file}"
    done

    pass "${name}"
}

test_no_duplicate_jokes() {
    local name="no duplicate jokes"

    for file in "${JOKES_DIR}"/*.txt; do
        local dupes
        dupes=$(grep -v '^#' "${file}" | grep -v '^$' | sort | uniq -d | head -1)
        if [[ -n "${dupes}" ]]; then
            fail "${name}" "$(basename "${file}"): '${dupes}'"
            return
        fi
    done

    pass "${name}"
}

# --- Script tests ------------------------------------------------------------

test_script_is_executable_bash() {
    local name="rimshot.sh has bash shebang"

    local shebang
    shebang=$(head -1 "${RIMSHOT_SCRIPT}")

    if [[ "${shebang}" != "#!/usr/bin/env bash" ]]; then
        fail "${name}" "expected #!/usr/bin/env bash, got: ${shebang}"
        return
    fi

    pass "${name}"
}

test_script_uses_strict_mode() {
    local name="rimshot.sh uses strict mode"

    if ! grep -q 'set -euo pipefail' "${RIMSHOT_SCRIPT}"; then
        fail "${name}" "missing 'set -euo pipefail'"
        return
    fi

    pass "${name}"
}

test_script_no_eval() {
    local name="rimshot.sh does not use eval"

    if grep -qE '\beval\b' "${RIMSHOT_SCRIPT}"; then
        fail "${name}" "eval found in script (security risk)"
        return
    fi

    pass "${name}"
}

## Helper: create an isolated temp environment for rimshot tests
## Sets RIMSHOT_HOME and TMPDIR to the same temp dir for full isolation
make_test_env() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local tmp_jokes="${tmp_dir}/jokes"
    mkdir -p "${tmp_jokes}"
    echo "${tmp_dir}"
}

## Helper: run rimshot.sh with isolated env
run_rimshot() {
    local tmp_dir="$1" lang="$2" freq="$3" cooldown="$4"
    TMPDIR="${tmp_dir}" \
    RIMSHOT_HOME="${tmp_dir}" \
    RIMSHOT_LANG="${lang}" \
    RIMSHOT_FREQUENCY="${freq}" \
    RIMSHOT_COOLDOWN="${cooldown}" \
        bash "${RIMSHOT_SCRIPT}" < /dev/null
}

test_script_exits_zero() {
    local name="rimshot.sh exits 0"

    local tmp_dir
    tmp_dir=$(make_test_env)
    echo "Test joke" > "${tmp_dir}/jokes/en.txt"

    local exit_code=0
    run_rimshot "${tmp_dir}" "en" 100 0 2>/dev/null || exit_code=$?

    rm -rf "${tmp_dir}"

    if (( exit_code != 0 )); then
        fail "${name}" "exit code was ${exit_code}"
        return
    fi

    pass "${name}"
}

test_script_outputs_json_to_stdout() {
    local name="rimshot.sh outputs valid JSON with joke to stdout"

    local tmp_dir
    tmp_dir=$(make_test_env)
    echo "Test joke for stdout" > "${tmp_dir}/jokes/en.txt"

    local stdout
    stdout=$(run_rimshot "${tmp_dir}" "en" 100 0 2>/dev/null || true)

    rm -rf "${tmp_dir}"

    if [[ -z "${stdout}" ]]; then
        fail "${name}" "no output on stdout"
        return
    fi

    if [[ "${stdout}" != *"additionalContext"* ]]; then
        fail "${name}" "expected JSON with additionalContext, got: ${stdout}"
        return
    fi

    if [[ "${stdout}" != *"Test joke for stdout"* ]]; then
        fail "${name}" "joke text not found in output: ${stdout}"
        return
    fi

    # Validate JSON is parseable (catches missing escapes for control chars)
    if command -v jq &>/dev/null; then
        if ! printf '%s' "${stdout}" | jq empty 2>/dev/null; then
            fail "${name}" "output is not valid JSON: ${stdout}"
            return
        fi
    fi

    pass "${name}"
}

test_script_outputs_to_stderr() {
    local name="rimshot.sh also outputs joke to stderr"

    local tmp_dir
    tmp_dir=$(make_test_env)
    echo "Stderr test joke" > "${tmp_dir}/jokes/en.txt"

    local stderr
    stderr=$(run_rimshot "${tmp_dir}" "en" 100 0 2>&1 1>/dev/null || true)

    rm -rf "${tmp_dir}"

    if [[ -z "${stderr}" ]]; then
        fail "${name}" "no output on stderr"
        return
    fi

    if [[ "${stderr}" != *"Stderr test joke"* ]]; then
        fail "${name}" "joke text not in stderr: ${stderr}"
        return
    fi

    pass "${name}"
}

test_script_json_handles_special_chars() {
    local name="rimshot.sh escapes special chars in JSON"

    if ! command -v jq &>/dev/null; then
        pass "${name} (skipped: jq not available)"
        return
    fi

    local tmp_dir
    tmp_dir=$(make_test_env)
    printf 'Joke with "quotes" and back\\slash\n' > "${tmp_dir}/jokes/en.txt"

    local stdout
    stdout=$(run_rimshot "${tmp_dir}" "en" 100 0 2>/dev/null || true)

    rm -rf "${tmp_dir}"

    if ! printf '%s' "${stdout}" | jq empty 2>/dev/null; then
        fail "${name}" "invalid JSON for special chars: ${stdout}"
        return
    fi

    pass "${name}"
}

test_script_respects_language() {
    local name="rimshot.sh respects RIMSHOT_LANG"

    local tmp_dir
    tmp_dir=$(make_test_env)
    echo "English joke" > "${tmp_dir}/jokes/en.txt"
    echo "Piada brasileira" > "${tmp_dir}/jokes/pt-BR.txt"

    local output
    output=$(run_rimshot "${tmp_dir}" "pt-BR" 100 0 2>/dev/null || true)

    rm -rf "${tmp_dir}"

    if [[ "${output}" != *"Piada brasileira"* ]]; then
        fail "${name}" "expected pt-BR joke, got: ${output}"
        return
    fi

    pass "${name}"
}

test_script_fallback_to_english() {
    local name="rimshot.sh falls back to English"

    local tmp_dir
    tmp_dir=$(make_test_env)
    echo "English fallback" > "${tmp_dir}/jokes/en.txt"

    local output
    output=$(run_rimshot "${tmp_dir}" "xx-INVALID" 100 0 2>/dev/null || true)

    rm -rf "${tmp_dir}"

    if [[ "${output}" != *"English fallback"* ]]; then
        fail "${name}" "expected English fallback, got: ${output}"
        return
    fi

    pass "${name}"
}

test_script_frequency_zero_no_output() {
    local name="rimshot.sh with frequency=0 produces no output"

    local tmp_dir
    tmp_dir=$(make_test_env)
    echo "Should not appear" > "${tmp_dir}/jokes/en.txt"

    local output
    output=$(run_rimshot "${tmp_dir}" "en" 0 0 2>&1 || true)

    rm -rf "${tmp_dir}"

    if [[ -n "${output}" ]]; then
        fail "${name}" "expected no output, got: ${output}"
        return
    fi

    pass "${name}"
}

test_script_cooldown_suppresses_second_joke() {
    local name="rimshot.sh cooldown suppresses rapid invocations"

    local tmp_dir
    tmp_dir=$(make_test_env)
    echo "Cooldown test joke" > "${tmp_dir}/jokes/en.txt"

    # First call should produce output
    local first
    first=$(run_rimshot "${tmp_dir}" "en" 100 60 2>/dev/null || true)

    # Second call within cooldown (60s) should be silent
    local second
    second=$(run_rimshot "${tmp_dir}" "en" 100 60 2>/dev/null || true)

    rm -rf "${tmp_dir}"

    if [[ -z "${first}" ]]; then
        fail "${name}" "first invocation should produce a joke"
        return
    fi

    if [[ -n "${second}" ]]; then
        fail "${name}" "second invocation within cooldown should be silent, got: ${second}"
        return
    fi

    pass "${name}"
}

# --- Install/uninstall tests -------------------------------------------------

test_install_script_exists() {
    local name="install.sh exists and is valid bash"

    if [[ ! -f "${PROJECT_DIR}/install.sh" ]]; then
        fail "${name}" "install.sh not found"
        return
    fi

    if ! bash -n "${PROJECT_DIR}/install.sh" 2>/dev/null; then
        fail "${name}" "syntax error in install.sh"
        return
    fi

    pass "${name}"
}

test_uninstall_script_exists() {
    local name="uninstall.sh exists and is valid bash"

    if [[ ! -f "${PROJECT_DIR}/uninstall.sh" ]]; then
        fail "${name}" "uninstall.sh not found"
        return
    fi

    if ! bash -n "${PROJECT_DIR}/uninstall.sh" 2>/dev/null; then
        fail "${name}" "syntax error in uninstall.sh"
        return
    fi

    pass "${name}"
}

# --- Runner ------------------------------------------------------------------

main() {
    printf '\n'
    printf '  rimshot test suite\n'
    printf '  ==================\n\n'

    # Joke file tests
    run_test test_joke_files_exist
    run_test test_joke_files_not_empty
    run_test test_joke_files_valid_utf8
    run_test test_joke_files_no_trailing_whitespace
    run_test test_joke_lines_reasonable_length
    run_test test_no_duplicate_jokes

    # Script tests
    run_test test_script_is_executable_bash
    run_test test_script_uses_strict_mode
    run_test test_script_no_eval
    run_test test_script_exits_zero
    run_test test_script_outputs_json_to_stdout
    run_test test_script_outputs_to_stderr
    run_test test_script_json_handles_special_chars
    run_test test_script_respects_language
    run_test test_script_fallback_to_english
    run_test test_script_frequency_zero_no_output
    run_test test_script_cooldown_suppresses_second_joke

    # Install/uninstall tests
    run_test test_install_script_exists
    run_test test_uninstall_script_exists

    # Summary
    printf '\n'
    printf '  Results: %d tests, %d passed, %d failed\n\n' \
        "${TESTS_RUN}" "${TESTS_PASSED}" "${TESTS_FAILED}"

    if (( TESTS_FAILED > 0 )); then
        exit 1
    fi
}

main
