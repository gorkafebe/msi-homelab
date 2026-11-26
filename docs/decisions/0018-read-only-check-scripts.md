# 0018 — Host checks are read-only, sudo-free scripts

**Status:** in force. **Source:** D-74.

**Decision.** Checks of the server (after a reboot, before publishing) are
scripts that only read, need no `sudo`, and print redacted output (file:line,
never a secret or an address). In this repository: `scripts/audit-public.sh`,
`make config`, the verification commands on each runbook page.

**Why.** A check you can run at any time without risk gets run; its output can
be pasted into an issue or a log.
