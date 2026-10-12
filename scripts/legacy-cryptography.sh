# Lynis fragment CUST-0210, revision 2.0, author Lakshya Punni.
# Check selected legacy families, not every possible cryptographic weakness.

LPC_Value() {
    printf '%s\n' "$1" | awk -v key="$2" '$1 == key {sub(/^[^[:space:]]+[[:space:]]+/, ""); print; exit}'
}

LPC_FindLegacy() {
    printf '%s\n' "$1" | awk -F ',' -v family="$2" '
        {
            for (i = 1; i <= NF; i++) {
                bad = (family == "kex" && $i ~ /^diffie-hellman-.*-sha1$/) ||
                      (family == "cipher" && ($i ~ /-cbc$/ || $i ~ /^arcfour/)) ||
                      (family == "signature" && ($i == "ssh-rsa" || $i == "ssh-rsa-cert-v01@openssh.com" || $i ~ /^ssh-dss/))
                if (bad) {printf "%s%s", separator, $i; separator = ","}
            }
        }
    '
}

Register --test-no CUST-0210 --weight M --network NO --category security --description "Audit legacy SSH key exchange, ciphers and signatures"
if [ "${SKIPTEST:-0}" -eq 0 ]; then
    LPC_CONFIG="${LYNIS_SSH_CONFIG:-/etc/ssh/sshd_config}"
    LPC_USER="${LYNIS_SSH_AUDIT_USER:-${SUDO_USER:-$(id -un)}}"
    LPC_READY=yes
    command -v sshd >/dev/null 2>&1 || LPC_READY=no
    command -v awk >/dev/null 2>&1 || LPC_READY=no
    case "$LPC_CONFIG" in /*) ;; *) LPC_READY=no ;; esac
    case "$LPC_USER" in ''|*[!a-zA-Z0-9_.-]*) LPC_READY=no ;; esac

    if [ "$LPC_READY" != yes ]; then
        Display --indent 4 --text "- Crypto audit: prerequisites unavailable" --result SKIPPED --color YELLOW
        LogText "CUST-0210: require sshd, awk, absolute config path and a simple username"
    elif LPC_OUTPUT="$(sshd -T -f "$LPC_CONFIG" -C "user=$LPC_USER,host=client.example,addr=192.0.2.10,laddr=127.0.0.1,lport=22" 2>&1)"; then
        for LPC_SETTING in kexalgorithms ciphers hostkeyalgorithms pubkeyacceptedalgorithms; do
            case "$LPC_SETTING" in
                kexalgorithms) LPC_FAMILY=kex ;;
                ciphers) LPC_FAMILY=cipher ;;
                *) LPC_FAMILY=signature ;;
            esac
            LPC_VALUE="$(LPC_Value "$LPC_OUTPUT" "$LPC_SETTING")"
            if [ -z "$LPC_VALUE" ]; then
                Display --indent 4 --text "- Crypto $LPC_SETTING: value unavailable" --result SKIPPED --color YELLOW
                LogText "CUST-0210: missing $LPC_SETTING in sshd output"
            else
                LPC_LEGACY="$(LPC_FindLegacy "$LPC_VALUE" "$LPC_FAMILY")"
                LogText "CUST-0210 setting=$LPC_SETTING configured=$LPC_VALUE legacy=$LPC_LEGACY"
                if [ -n "$LPC_LEGACY" ]; then
                    Display --indent 4 --text "- Crypto $LPC_SETTING: legacy enabled" --result WARNING --color RED
                    ReportWarning "${TEST_NO}" "Review legacy $LPC_SETTING algorithms: $LPC_LEGACY"
                else
                    Display --indent 4 --text "- Crypto $LPC_SETTING: no listed legacy" --result OK --color GREEN
                fi
            fi
        done
    else
        Display --indent 4 --text "- Crypto audit: sshd query failed" --result SKIPPED --color YELLOW
        LogText "CUST-0210 query failed: $LPC_OUTPUT"
    fi
fi
