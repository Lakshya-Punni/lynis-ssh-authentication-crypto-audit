# Demo Explanation for Lakshya Punni

## One-Minute Project Summary

"Lynis already has a built-in SSH configuration audit. My revision adds two custom tests for settings absent from the saved Lynis 3.0.9 reference. The first checks every allowed authentication chain in two selected connection contexts. The second searches effective cryptographic algorithm lists for selected legacy families. Both report through Lynis without changing SSH policy. I demonstrate compliant and noncompliant offline configuration files using the real OpenSSH parser."

Do not claim that the new scripts were the exact scripts used in the earlier DA1 classroom demo. They are a later revision.

## Script 1

- SSH: Secure Shell, an encrypted remote-access protocol.
- `sshd`: the SSH server program. The final `d` means daemon, a background server process.
- `-T`: print effective configuration values; it does not start a listening server.
- `-f`: choose the configuration file to read.
- `-C`: supply connection information so OpenSSH can evaluate `Match` rules.
- `Match`: a configuration section that applies only when stated conditions match.
- Loopback: the local computer's own network interface; `127.0.0.1` refers to itself.
- `192.0.2.10`: a documentation address used only as a parser input, not a contacted host.
- `publickey`: proving possession of the private key corresponding to an accepted public key.
- `keyboard-interactive:pam`: an interactive authentication step handled through PAM.
- PAM: Pluggable Authentication Modules. PAM may ask for a password or another configured challenge; this audit does not verify an OTP setup.
- `AuthenticationMethods`: allowed sequences of successful authentication steps.
- A comma means AND within one chain. A space separates alternatives, meaning OR. Every alternative must meet the project policy; one weaker alternative can bypass it.
- Repeating `publickey` is not the same as requiring PAM. Two keys are still not proof of two different factor categories.

## Script 2

- Cryptography: techniques for protecting data and verifying identities.
- Key exchange: establishing shared secrets used by a connection.
- Cipher: an encryption algorithm.
- Signature: evidence that a key holder approved particular data.
- SHA-1 / SHA-2: different hash algorithm families; the code flags selected SHA-1 signature/key-exchange names.
- `ssh-rsa`: the RSA/SHA-1 signature algorithm, not every use of an RSA key.
- `rsa-sha2-256` / `rsa-sha2-512`: RSA signatures using SHA-2, not rejected by this policy.
- CBC: Cipher Block Chaining, a mode the project's legacy policy rejects. A passing denylist check is not a proof that every unlisted choice is safe.
- Algorithm lists: comma-separated allowed choices, printed by OpenSSH after it processes additions, removals and defaults.
- Allowed versus negotiated: configuration permits an algorithm; a real connection may select a different one. This project does not prove negotiation occurred.

## Shell Syntax

- `Register`: a Lynis helper that registers the test number and description.
- `CUST-0200` / `CUST-0210`: unique IDs for these two custom tests.
- `SKIPTEST`: Lynis's decision about whether the registered test should run.
- `LogText`: write details to Lynis's audit log.
- `Display`: show a status in Lynis's console output.
- `ReportWarning`: record a warning in Lynis's report.
- `$NAME`: use the value of a shell variable.
- `$(command)`: run a command and capture its output.
- Double quotes protect spaces and stop unwanted splitting or filename expansion.
- `${NAME:-default}`: use a default when the variable is missing or empty.
- `if` / `then` / `else` / `fi`: conditional execution.
- `for` / `do` / `done`: iterate over a list.
- `case` / `esac`: choose a branch based on a value.
- `&&`: run the next command only if the previous command succeeds.
- `||`: run the next command only if the previous command fails.
- `2>&1`: include error output in the captured text, allowing a failed query to be explained.
- `awk`: a text-processing tool. Here it parses OpenSSH's already-generated structured output, not the raw configuration file.
- `$1` in an awk program is the first field; inside a shell function it is the first argument. The surrounding language determines its meaning.
- `NF`: awk's number of fields; `split`: divide text into array elements.
- `^` / `$` in a regular expression: beginning / end of a string.
- `exit 1`: report failure to the calling condition; it does not necessarily stop the whole Lynis audit.

## Meaning of Results

- `OK`: this check met this project's policy. Not a guarantee that the machine is secure.
- `WARNING`: the configuration did not meet the policy. This is an audit finding, not a crashed script or evidence of a successful attack.
- `SKIPPED`: a prerequisite, query or value was unavailable. It must not be presented as a pass.
- Exit code `0`: the audit process completed normally. It can still contain security warnings.

## Live Demonstration Order

1. Show Lynis's version and the saved original `tests_ssh` option list.
2. Explain the eight new settings absent from that reference.
3. Show both revised source fragments and their `Register` IDs.
4. Run the real audit against the system configuration and interpret its values.
5. Run the custom tests against the compliant offline fixture.
6. Run them against the bypass-and-legacy offline fixture.
7. Show the loopback authentication override and exact legacy names responsible for warnings.
8. Show `Performing test ID CUST-0200` and `CUST-0210` in the saved Lynis logs.
9. Explain why neither demonstration file changed the system configuration and why this is not a live-login or OTP test.
10. Show the repository and blog, with source versions matching the evidence.
