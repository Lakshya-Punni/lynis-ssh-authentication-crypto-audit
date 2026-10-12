#!/usr/bin/env bash
# Real Linux evidence only. Preserve DA1 tests and do not edit SSH policy.
set -euo pipefail
umask 077
[[ $(uname -s) == Linux ]] || { printf '%s\n' 'Run this in Linux/WSL.' >&2; exit 2; }
export PATH="$PATH:/usr/sbin:/sbin"
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
workspace=$(cd -- "$root/.." && pwd)
for tool in lynis sshd awk grep sha256sum pgrep ss; do
    command -v "$tool" >/dev/null || { printf 'Missing program: %s\n' "$tool" >&2; exit 2; }
done
lynis=$(command -v lynis)
sshd=$(command -v sshd)
audit_user=$(id -un)
case "$audit_user" in ''|*[!a-zA-Z0-9_.-]*) printf '%s\n' 'Username requires an explicitly supported audit context.' >&2; exit 2 ;; esac
sudo -v
mkdir -p "$workspace/evidence"
run=$(mktemp -d "$workspace/evidence/blog1-revision-$(date +%Y%m%d-%H%M%S)-XXXXXX")
printf '%s\n' "$run" > "$workspace/evidence/latest-revision-run.txt"
mkdir -p "$run/live" "$run/compliant" "$run/bypass-and-legacy" "$run/commands"
{
    printf 'Collection started: %s\n' "$(date --iso-8601=seconds)"
    printf 'Audit user: %s\n' "$audit_user"
    printf 'OS: '; . /etc/os-release; printf '%s\n' "$PRETTY_NAME"
    uname -sr
    printf 'Lynis version: '; "$lynis" show version
    printf 'OpenSSH: '; "$sshd" -V 2>&1
} > "$run/environment.txt"
include=$(sudo "$lynis" show includedir)
[[ $include == /* && -d $include ]] || { printf '%s\n' 'Invalid include directory.' >&2; exit 2; }
sudo cat "$include/tests_ssh" > "$run/reference-tests_ssh.sh"
if [[ -f /usr/share/common-licenses/GPL-3 ]]; then cp /usr/share/common-licenses/GPL-3 "$run/GPL-3.txt"; fi
cp "$root/scripts/authentication-chain.sh" "$run/authentication-chain-used.sh"
cp "$root/scripts/legacy-cryptography.sh" "$run/legacy-cryptography-used.sh"

# Build a candidate while retaining the existing DA1 file byte for byte.
candidate="$run/tests_custom-candidate.sh"
if sudo test -e "$include/tests_custom"; then
    sudo cat "$include/tests_custom" > "$run/tests_custom-before.sh"
    cp "$run/tests_custom-before.sh" "$candidate"
else
    printf '%s\n' '# Custom Lynis tests' > "$candidate"
fi
if grep -Eq 'Register[[:space:]]+--test-no[[:space:]]+CUST-02(00|10)([[:space:]]|$)' "$candidate"; then
    # Idempotent only if both exact current fragments are already installed.
    if ! grep -Fq 'Register --test-no CUST-0200 ' "$candidate" || ! grep -Fq 'Register --test-no CUST-0210 ' "$candidate"; then
        printf '%s\n' 'A conflicting revised test ID exists; no file was changed.' >&2; exit 2
    fi
    for fragment in authentication-chain legacy-cryptography; do
        fragment_text=$(cat "$root/scripts/$fragment.sh")
        candidate_text=$(cat "$candidate")
        [[ $candidate_text == *"$fragment_text"* ]] || { printf '%s\n' 'A different revision is already installed; no file was changed.' >&2; exit 2; }
    done
else
    printf '\n' >> "$candidate"
    cat "$root/scripts/authentication-chain.sh" "$root/scripts/legacy-cryptography.sh" >> "$candidate"
fi
bash -n "$candidate"
sh -n "$candidate"
sudo install -o root -g root -m 0640 "$candidate" "$include/tests_custom"
printf '%s\n' 'New tests appended; original DA1 blocks preserved. Syntax checks passed.' > "$run/installation.txt"
sudo cat "$include/tests_custom" > "$run/tests_custom-used.sh"
sudo test -d /run/sshd || sudo install -d -o root -g root -m 0755 /run/sshd
sudo "$sshd" -t
for fixture in compliant bypass-and-legacy; do
    sudo "$sshd" -t -f "$root/fixtures/$fixture.conf" > "$run/$fixture/validation.txt" 2>&1
    cp "$root/fixtures/$fixture.conf" "$run/$fixture/sshd_config-used.conf"
done

# Brief loopback-only listener makes the built-in daemon prerequisite real.
# It uses the existing config, never either offline demonstration fixture.
daemon_pid=''
daemon_job=''
stop_demo_daemon() {
    if [[ $daemon_pid =~ ^[0-9]+$ ]]; then
        sudo kill "$daemon_pid" 2>/dev/null || true
        if [[ -n $daemon_job ]]; then wait "$daemon_job" 2>/dev/null || true; fi
        daemon_pid=''
        printf '%s\n' 'Temporary loopback SSH daemon stopped.' >> "$run/environment.txt"
    fi
}
trap stop_demo_daemon EXIT
trap 'exit 130' INT TERM
if pgrep -x sshd >/dev/null; then
    printf '%s\n' 'Existing SSH daemon found; it was not changed or stopped.' >> "$run/environment.txt"
else
    listeners=$(sudo "$sshd" -T -o ListenAddress=127.0.0.1 -p 22222 | awk '$1 == "listenaddress" {print $2}')
    if [[ $listeners != '127.0.0.1:22222' ]]; then
        printf 'Refusing to start a daemon: unexpected addresses: %s\n' "$listeners" >&2; exit 2
    fi
    if [[ -n $(ss -H -ltn '( sport = :22222 )') ]]; then
        printf '%s\n' 'Port 22222 is occupied. No service was changed; stop and choose another demo port.' >&2; exit 2
    fi
    sudo bash -c 'printf "%s\n" "$$" > "$1"; exec "$2" -D -e -o ListenAddress=127.0.0.1 -p 22222' bash "$run/demo-daemon.pid" "$sshd" > "$run/demo-daemon.txt" 2>&1 &
    daemon_job=$!
    for attempt in {1..30}; do
        if sudo test -s "$run/demo-daemon.pid"; then daemon_pid=$(sudo cat "$run/demo-daemon.pid"); fi
        if [[ -n $(ss -H -ltn '( sport = :22222 )') ]]; then break; fi
        sleep 0.1
    done
    [[ $daemon_pid =~ ^[0-9]+$ ]] && sudo kill -0 "$daemon_pid"
    ss -H -ltn '( sport = :22222 )' > "$run/demo-listener.txt"
    [[ -s $run/demo-listener.txt ]] || { printf '%s\n' 'Loopback SSH listener failed to start.' >&2; exit 2; }
    printf '%s\n' 'Temporary real SSH daemon: 127.0.0.1:22222 only. No SSH login was attempted. Built-in queries read on-disk defaults, not command-line listener overrides.' >> "$run/environment.txt"
fi

collect_settings() {
    local config=$1 directory=$2 context address host
    for context in loopback external-sample; do
        if [[ $context == loopback ]]; then address=127.0.0.1; host=localhost; else address=192.0.2.10; host=client.example; fi
        sudo "$sshd" -T -f "$config" -C "user=$audit_user,host=$host,addr=$address,laddr=127.0.0.1,lport=22" > "$directory/$context-full.txt"
        grep -E '^(authenticationmethods|pubkeyauthentication|kbdinteractiveauthentication|usepam|kexalgorithms|ciphers|hostkeyalgorithms|pubkeyacceptedalgorithms) ' "$directory/$context-full.txt" > "$directory/$context-settings.txt"
    done
}
collect_settings /etc/ssh/sshd_config "$run/live"
collect_settings "$root/fixtures/compliant.conf" "$run/compliant"
collect_settings "$root/fixtures/bypass-and-legacy.conf" "$run/bypass-and-legacy"

capture_command() {
    local number=$1
    shift
    printf '%q ' "$@" > "$run/commands/$number-command.txt"
    printf '\n' >> "$run/commands/$number-command.txt"
    set +e
    "$@" > "$run/commands/$number-output.txt" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status" > "$run/commands/$number-exit-code.txt"
    # --help normally returns 64 in this version; record it rather than hiding it.
    if [[ $number != 01 && $status != 0 && $status != 78 ]]; then
        cat "$run/commands/$number-output.txt" >&2; exit "$status"
    fi
    printf 'Collected Lynis command %s (exit %s)\n' "$number" "$status"
}
capture_command 01 "$lynis" --help
capture_command 02 "$lynis" show version
capture_command 03 "$lynis" show options
capture_command 04 sudo "$lynis" show includedir
capture_command 05 "$lynis" show groups
capture_command 06 "$lynis" show profiles
capture_command 07 sudo "$lynis" show settings
capture_command 08 sudo env "LYNIS_SSH_AUDIT_USER=$audit_user" "$lynis" audit system --quick --no-colors --tests CUST-0200
capture_command 09 sudo env "LYNIS_SSH_AUDIT_USER=$audit_user" "$lynis" audit system --quick --no-colors --tests CUST-0210
capture_command 10 sudo env "LYNIS_SSH_AUDIT_USER=$audit_user" "$lynis" audit system --quick --no-colors --tests 'SSH-7402 SSH-7404 SSH-7406 SSH-7408 SSH-7440 CUST-0200 CUST-0210'
cp "$run/commands/10-output.txt" "$run/live/lynis-audit.txt"
sudo cat /var/log/lynis.log > "$run/live/lynis.log"
sudo cat /var/log/lynis-report.dat > "$run/live/lynis-report.dat"
grep -E 'Auth chain|Auth methods|Crypto |OpenSSH option:|CUST-0200|CUST-0210' "$run/live/lynis-audit.txt" > "$run/live/focused-results.txt" || true
grep -E 'Performing test ID (SSH-7408|CUST-0200|CUST-0210)|Skipped test SSH-7408|CUST-0200 context=|CUST-0210 setting=' "$run/live/lynis.log" > "$run/live/execution-proof.txt" || true
stop_demo_daemon

for fixture in compliant bypass-and-legacy; do
    printf '\nRunning real Lynis against OFFLINE fixture: %s\n' "$fixture"
    set +e
    sudo env "LYNIS_SSH_AUDIT_USER=$audit_user" "LYNIS_SSH_CONFIG=$root/fixtures/$fixture.conf" "$lynis" audit system --quick --no-colors --tests 'CUST-0200 CUST-0210' > "$run/$fixture/lynis-audit.txt" 2>&1
    status=$?
    set -e
    printf '%s\n' "$status" > "$run/$fixture/audit-exit-code.txt"
    [[ $status == 0 || $status == 78 ]] || { cat "$run/$fixture/lynis-audit.txt" >&2; exit "$status"; }
    sudo cat /var/log/lynis.log > "$run/$fixture/lynis.log"
    sudo cat /var/log/lynis-report.dat > "$run/$fixture/lynis-report.dat"
    grep -E 'Auth chain|Auth methods|Crypto |CUST-0200|CUST-0210' "$run/$fixture/lynis-audit.txt" > "$run/$fixture/focused-results.txt" || true
    grep -E 'Performing test ID CUST-02(00|10)|CUST-0200 context=|CUST-0210 setting=' "$run/$fixture/lynis.log" > "$run/$fixture/execution-proof.txt" || true
done
sha256sum "$run/authentication-chain-used.sh" "$run/legacy-cryptography-used.sh" "$run/reference-tests_ssh.sh" "$run/tests_custom-used.sh" > "$run/source-sha256.txt"
printf '%s\n' 'Complete: actual Lynis evidence, not simulated output. System SSH configuration unchanged.' > "$run/COMPLETE.txt"
printf '\nEvidence collection complete: %s\n' "$run"
printf '%s\n' 'The original DA1 tests remain installed alongside the new tests. No fixture was installed as the system SSH configuration.'
