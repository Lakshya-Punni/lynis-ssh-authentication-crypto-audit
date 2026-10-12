#!/bin/sh
# Unit tests with fake sshd output, not a real Lynis audit.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT_DIR="$ROOT/test-results"
mkdir -p "$OUTPUT_DIR"
if command -v chmod >/dev/null 2>&1; then chmod +x "$ROOT/tests/bin/sshd"; fi
PATH="$ROOT/tests/bin:$PATH"
export PATH
LYNIS_SSH_CONFIG=/unit-test/sshd_config
LYNIS_SSH_AUDIT_USER=demo
export LYNIS_SSH_CONFIG LYNIS_SSH_AUDIT_USER

Register() {
    SKIPTEST=0
    while [ "$#" -gt 0 ]; do
        case "$1" in --test-no) TEST_NO=$2; shift ;; esac
        shift
    done
}
LogText() { printf 'SIMULATED LOG %s\n' "$*"; }
ReportWarning() { printf 'SIMULATED RECOMMENDATION %s\n' "$*"; }
Display() {
    UNIT_TEXT=''
    UNIT_RESULT=''
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --text) UNIT_TEXT=$2; shift ;;
            --result) UNIT_RESULT=$2; shift ;;
        esac
        shift
    done
    printf 'SIMULATED RESULT %s %s [ %s ]\n' "$TEST_NO" "$UNIT_TEXT" "$UNIT_RESULT"
}

run_case() {
    UNIT_CASE=$1
    export UNIT_CASE
    (
        . "$ROOT/scripts/authentication-chain.sh"
        . "$ROOT/scripts/legacy-cryptography.sh"
    ) > "$OUTPUT_DIR/$UNIT_CASE.txt"
    UNIT_COUNTS=$(awk '
        /^SIMULATED RESULT/ {
            if ($0 ~ /\[ OK \]/) ok++
            if ($0 ~ /\[ WARNING \]/) warning++
            if ($0 ~ /\[ SKIPPED \]/) skipped++
        }
        END {printf "%d %d %d", ok, warning, skipped}
    ' "$OUTPUT_DIR/$UNIT_CASE.txt")
    if [ "$UNIT_COUNTS" != "$2 $3 $4" ]; then
        printf 'FAIL %s: expected %s %s %s, got %s\n' "$1" "$2" "$3" "$4" "$UNIT_COUNTS"
        cat "$OUTPUT_DIR/$UNIT_CASE.txt"
        exit 1
    fi
    printf 'PASS %-22s OK=%s WARNING=%s SKIPPED=%s (simulated)\n' "$1" "$2" "$3" "$4"
}

run_case compliant 8 0 0
run_case defaults 4 4 0
run_case alternative-bypass 6 2 0
run_case match-bypass 7 1 0
run_case repeated-publickey 6 2 0
run_case method-off 6 2 0
run_case legacy 4 4 0
run_case multi-alternative 8 0 0
run_case missing-method 6 0 2
run_case missing-crypto 4 0 4
run_case empty-output 0 0 8
run_case query-failure 0 0 3
LYNIS_SSH_AUDIT_USER='bad,name'
run_case invalid-user 0 0 2
printf '%s\n' 'All 13 simulated logic tests passed. Real Linux evidence must be collected separately.'
