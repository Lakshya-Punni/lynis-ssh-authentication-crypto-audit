# Lynis fragment CUST-0200, revision 2.0, author Lakshya Punni.
# Audit two synthetic connection contexts; do not change SSH settings.

LPA_Value() {
    printf '%s\n' "$1" | awk -v key="$2" '$1 == key {sub(/^[^[:space:]]+[[:space:]]+/, ""); print; exit}'
}

LPA_ChainCompliant() {
    printf '%s\n' "$1" | awk '
        NF {
            for (i = 1; i <= NF; i++) {
                n = split($i, steps, ",")
                if (n < 2 || steps[1] != "publickey") exit 1
                pam = 0
                for (j = 2; j <= n; j++) {
                    if (steps[j] == "keyboard-interactive:pam") pam = 1
                    if (steps[j] == "none") exit 1
                }
                if (!pam) exit 1
            }
            valid = 1
        }
        END {if (!valid) exit 1}
    '
}

Register --test-no CUST-0200 --weight M --network NO --category security --description "Audit SSH authentication chains in two Match contexts"
if [ "${SKIPTEST:-0}" -eq 0 ]; then
    LPA_CONFIG="${LYNIS_SSH_CONFIG:-/etc/ssh/sshd_config}"
    LPA_USER="${LYNIS_SSH_AUDIT_USER:-${SUDO_USER:-$(id -un)}}"
    LPA_READY=yes
    command -v sshd >/dev/null 2>&1 || LPA_READY=no
    command -v awk >/dev/null 2>&1 || LPA_READY=no
    case "$LPA_CONFIG" in /*) ;; *) LPA_READY=no ;; esac
    case "$LPA_USER" in ''|*[!a-zA-Z0-9_.-]*) LPA_READY=no ;; esac

    if [ "$LPA_READY" != yes ]; then
        Display --indent 4 --text "- Auth chain audit: prerequisites unavailable" --result SKIPPED --color YELLOW
        LogText "CUST-0200: require sshd, awk, absolute config path and a simple username"
    else
        for LPA_CONTEXT in loopback external-sample; do
            case "$LPA_CONTEXT" in
                loopback) LPA_CONNECTION="user=$LPA_USER,host=localhost,addr=127.0.0.1,laddr=127.0.0.1,lport=22" ;;
                external-sample) LPA_CONNECTION="user=$LPA_USER,host=client.example,addr=192.0.2.10,laddr=127.0.0.1,lport=22" ;;
            esac
            if LPA_OUTPUT="$(sshd -T -f "$LPA_CONFIG" -C "$LPA_CONNECTION" 2>&1)"; then
                LPA_METHODS="$(LPA_Value "$LPA_OUTPUT" authenticationmethods)"
                LPA_KEY="$(LPA_Value "$LPA_OUTPUT" pubkeyauthentication)"
                LPA_INTERACTIVE="$(LPA_Value "$LPA_OUTPUT" kbdinteractiveauthentication)"
                LPA_PAM="$(LPA_Value "$LPA_OUTPUT" usepam)"
                LogText "CUST-0200 context=$LPA_CONTEXT user=$LPA_USER config=$LPA_CONFIG authenticationmethods=$LPA_METHODS pubkeyauthentication=$LPA_KEY kbdinteractiveauthentication=$LPA_INTERACTIVE usepam=$LPA_PAM"

                if [ -z "$LPA_METHODS" ]; then
                    Display --indent 4 --text "- Auth chain ($LPA_CONTEXT): value unavailable" --result SKIPPED --color YELLOW
                elif LPA_ChainCompliant "$LPA_METHODS"; then
                    Display --indent 4 --text "- Auth chain ($LPA_CONTEXT): publickey then PAM" --result OK --color GREEN
                else
                    Display --indent 4 --text "- Auth chain ($LPA_CONTEXT): policy bypass possible" --result WARNING --color RED
                    ReportWarning "${TEST_NO}" "Auth-chain policy fails in $LPA_CONTEXT: every alternative must start with publickey and require keyboard-interactive:pam"
                fi

                if [ -z "$LPA_KEY" ] || [ -z "$LPA_INTERACTIVE" ] || [ -z "$LPA_PAM" ]; then
                    Display --indent 4 --text "- Auth methods ($LPA_CONTEXT): values unavailable" --result SKIPPED --color YELLOW
                elif [ "$LPA_KEY" = yes ] && [ "$LPA_INTERACTIVE" = yes ] && [ "$LPA_PAM" = yes ]; then
                    Display --indent 4 --text "- Auth methods ($LPA_CONTEXT): key and PAM enabled" --result OK --color GREEN
                else
                    Display --indent 4 --text "- Auth methods ($LPA_CONTEXT): required method off" --result WARNING --color RED
                    ReportWarning "${TEST_NO}" "Enable PubkeyAuthentication, KbdInteractiveAuthentication and UsePAM for the chosen publickey/PAM chain in $LPA_CONTEXT"
                fi
            else
                Display --indent 4 --text "- Auth chain ($LPA_CONTEXT): sshd query failed" --result SKIPPED --color YELLOW
                LogText "CUST-0200 query failed: $LPA_OUTPUT"
            fi
        done
    fi
fi
