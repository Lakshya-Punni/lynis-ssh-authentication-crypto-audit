# Lynis SSH Authentication-Chain and Legacy-Cryptography Audits

Author: Lakshya Punni

Revision 2.0 is a follow-up to DA1, not the code used in the original classroom demo. The original DA1 scripts are retained separately in the parent workspace.

## Two Enhancements

1. `CUST-0200` checks every `AuthenticationMethods` alternative for a public-key step followed by a PAM keyboard-interactive step. It evaluates both loopback and an external example address, exposing a selected `Match` override that could otherwise go unnoticed. It also checks whether the required methods are enabled.
2. `CUST-0210` checks configured key-exchange, cipher, host-key signature and user-key signature lists for selected legacy families. It distinguishes RSA/SHA-1 (`ssh-rsa`) from RSA/SHA-2 (`rsa-sha2-256` and `rsa-sha2-512`).

These eight settings are absent from the saved Lynis 3.0.9 `include/tests_ssh` reference. This is a version-specific comparison, not a claim of worldwide novelty or absence from all security tools.

## Verified Results

A real evidence run completed on 12 October 2026 at 19:47 IST using Ubuntu 24.04.3 LTS, Lynis 3.0.9 and OpenSSH 9.6p1.

| Configuration audited | Authentication checks | Cryptography checks |
|---|---|---|
| Existing system configuration | 4 warnings | 4 OK |
| Compliant offline fixture | 4 OK | 4 OK |
| Bypass-and-legacy offline fixture | 1 warning, 3 OK | 4 warnings |

The built-in `SSH-7408` reference test also executed. None of the eight revised checks were skipped. Ten Lynis commands were recorded; the help command returned its normal help status `64`, and the other nine returned `0`. The original DA1 custom file was verified as an unchanged byte prefix of the combined installed file.

Screenshots show a saved-output evidence viewer, not a live terminal. No live login, OTP setup or negotiated algorithm was demonstrated.

## Requirements

- Ubuntu 24.04 / comparable Linux with Lynis and OpenSSH server installed.
- Administrative permission to read SSH configuration and install custom Lynis tests.
- `bash`, `awk`, `grep`, `pgrep`, `ss`, and `sha256sum`.

The `.sh` files are Lynis fragments, not standalone scripts. Lynis supplies `Register`, `Display`, `LogText`, and `ReportWarning`.

## Install and Collect Genuine Evidence

From this project directory in Linux:

```bash
bash capture-evidence.sh
```

The collector backs up and preserves existing custom tests, appends the two revised fragments, and installs the combined file as root-owned mode `0640`. It does not change `/etc/ssh/sshd_config` or install either demonstration configuration there.

If no `sshd` exists, it briefly starts a real SSH daemon listening only on `127.0.0.1:22222`, using the existing SSH configuration. It refuses unexpected listener addresses or an occupied demo port, and stops its own daemon when finished. Existing SSH daemons are never stopped. The built-in reference test reads on-disk defaults; it does not incorporate the temporary listener's command-line port/address overrides. No SSH login is attempted.

The collector runs ten Lynis commands and two extra real Lynis audits of offline fixture files, saving original output, exact source and hashes. Evidence is written to the parent `evidence` directory.

## Run the Revised Tests

After installation, run both through Lynis:

```bash
sudo env LYNIS_SSH_AUDIT_USER="$(id -un)" lynis audit system --quick --no-colors --tests "CUST-0200 CUST-0210"
```

`LYNIS_SSH_CONFIG` can point to an absolute offline configuration file for demonstrations. If unset, the scripts use `/etc/ssh/sshd_config`. The two sampled contexts use client addresses `127.0.0.1` and `192.0.2.10`, a local server address of `127.0.0.1` and server port `22`. The external address is documentation-only; the audit does not connect to it.

## Safe Pass/Fail Demonstrations

`fixtures/compliant.conf` defines a configuration that meets the chosen policy. `fixtures/bypass-and-legacy.conf` deliberately adds a single-step loopback authentication override and legacy algorithms. They are read by OpenSSH's configuration parser and never used to run a server.

```bash
sudo env LYNIS_SSH_AUDIT_USER="$(id -un)" LYNIS_SSH_CONFIG="$PWD/fixtures/compliant.conf" lynis audit system --quick --no-colors --tests "CUST-0200 CUST-0210"
sudo env LYNIS_SSH_AUDIT_USER="$(id -un)" LYNIS_SSH_CONFIG="$PWD/fixtures/bypass-and-legacy.conf" lynis audit system --quick --no-colors --tests "CUST-0200 CUST-0210"
```

Warnings mean the selected policy was not met. `SKIPPED` means the script could not evaluate that check; it is not a successful result. `OK` means this particular check passed, not that SSH or the whole computer is secure.

## Logic Tests

```bash
sh tests/check-logic.sh
```

The 13 unit cases use explicitly simulated `sshd` output. They are not proof of a real Lynis audit and must not be substituted for the collected Linux results.

## Limitations

- A key plus PAM chain is not proof of an OTP, independent authentication factors, a correct PAM stack or a successful real login. PAM can simply request the account password. This is an authentication-chain policy audit, not a certification of working MFA.
- Only two explicitly chosen `Match` contexts are checked. Other users, groups, source networks and server addresses/ports may behave differently.
- The algorithm policy is a bounded denylist of selected legacy families. Unlisted algorithms are not automatically proven safe. Configured allowances are not proof that an algorithm was negotiated or usable with the installed host keys.
- `sshd -T` evaluates files on disk. It does not prove a running daemon has reloaded them.
- Enabling this authentication policy on a real server without first provisioning keys and PAM can lock users out. These scripts only audit; they never apply it.

## References and Credits

- [Lynis 3.0.9 SSH source](https://raw.githubusercontent.com/CISOfy/lynis/3.0.9/include/tests_ssh), Michael Boelen and CISOfy.
- [Lynis documentation](https://cisofy.com/documentation/lynis/).
- [OpenSSH configuration manual](https://man.openbsd.org/sshd_config).
- [OpenSSH daemon options](https://man.openbsd.org/sshd).
- [OpenSSH legacy algorithms](https://www.openssh.org/legacy.html).

AI assistance was used for implementation, testing and explanation. Lakshya Punni remains responsible for understanding and explaining the submitted code.

This project uses Lynis shell tests, not Nmap NSE scripts. The `.sh` files are installed as Lynis test fragments; their extensions should not be changed to `.nse`.
