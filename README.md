# Lynis SSH Authentication and Cryptography Audits

**Author:** Lakshya Punni  
**Course:** Cyber Security, SCOPE, VIT Chennai, Fall Semester 2026-2027

Two custom Lynis tests extend SSH configuration auditing with authentication-chain validation and detection of selected legacy cryptographic algorithms. These enhanced scripts are a post-DA1 revision prepared for Blog 1.

## Enhanced Scripts

| Script | Lynis test ID | Purpose |
|---|---|---|
| [authentication-chain.sh](scripts/authentication-chain.sh) | `CUST-0200` | Checks that every permitted authentication alternative starts with a public key and includes a later PAM keyboard-interactive step, with the required methods enabled. |
| [legacy-cryptography.sh](scripts/legacy-cryptography.sh) | `CUST-0210` | Flags selected legacy key-exchange, cipher, host-key signature and user-key signature algorithms in the effective SSH configuration. |

The first script samples loopback and a documentation-only client address to evaluate selected `Match` rules. The second flags SHA-1 Diffie-Hellman families, CBC/Arcfour ciphers and RSA/SHA-1 or DSA signatures. RSA/SHA-2 signatures are not rejected by this policy.

## Enhancement Scope

The reference is Lynis 3.0.9's built-in `include/tests_ssh`, including `SSH-7408`. The custom tests add coverage of eight settings absent from the saved reference:

- Authentication: `AuthenticationMethods`, `PubkeyAuthentication`, `KbdInteractiveAuthentication`, `UsePAM`.
- Cryptography: `KexAlgorithms`, `Ciphers`, `HostKeyAlgorithms`, `PubkeyAcceptedAlgorithms`.

This comparison is specific to the inspected Lynis version; it is not a claim that these checks are unique across all security tools.

## Verified Results

Real Lynis runs were collected on **12 October 2026** using Ubuntu 24.04.3 LTS (WSL2), Lynis 3.0.9 and OpenSSH 9.6p1.

| Audited configuration | Authentication checks | Cryptography checks |
|---|---|---|
| Existing system configuration | 4 warnings | 4 OK |
| Compliant offline test configuration | 4 OK | 4 OK |
| Authentication-bypass and legacy-algorithm test configuration | 1 warning, 3 OK | 4 warnings |

All eight custom checks executed without skips in these runs. The controlled configurations were parser inputs only; they were not installed as the system's SSH policy. Code, descriptions and saved output screenshots are presented together in Blog 1.

## Running Through Lynis

Requirements: Linux, Lynis, OpenSSH server, `awk`, `grep`, and administrative access. The files are **Lynis test fragments**, not standalone shell programs; Lynis provides their reporting functions.

1. Find the Lynis include directory:

   ```bash
   sudo lynis show includedir
   ```

2. Back up the directory's existing `tests_custom` file. Append both fragments to that file, preserving existing tests. Keep it root-owned and not writable by ordinary users. If these test IDs are already installed, do not append duplicate copies.
3. Run both registered tests:

   ```bash
   sudo env LYNIS_SSH_AUDIT_USER="$(id -un)" lynis audit system --quick --no-colors --tests "CUST-0200 CUST-0210"
   ```

By default, the tests read `/etc/ssh/sshd_config`. `LYNIS_SSH_CONFIG` can select an absolute path to another configuration for offline auditing. Neither script changes SSH configuration or initiates a network connection.

`OK` means the selected check passed; `WARNING` means the project's policy was not met; `SKIPPED` means the check could not be evaluated. An audit can complete successfully while reporting warnings.

## Limitations

- The authentication check does not prove working MFA, an OTP setup, independent authentication factors or a successful login. PAM can simply request a password.
- Only two selected connection contexts are checked, not every possible `Match` condition.
- The cryptography check uses a bounded denylist; it does not certify every unlisted algorithm or prove what a live connection negotiated.
- `sshd -T` evaluates files on disk, not whether a running daemon has reloaded them.

## References and Acknowledgements

- [Lynis 3.0.9 SSH reference source](https://github.com/CISOfy/lynis/blob/3.0.9/include/tests_ssh) and [Lynis documentation](https://cisofy.com/documentation/lynis/).
- [OpenSSH configuration manual](https://man.openbsd.org/sshd_config), [daemon options](https://man.openbsd.org/sshd) and [legacy algorithms](https://www.openssh.org/legacy.html).
- Dr. T. Subbulakshmi, SCOPE, VIT Chennai; Michael Boelen, CISOfy and Lynis contributors.

AI assistance was used for implementation, testing and documentation.
