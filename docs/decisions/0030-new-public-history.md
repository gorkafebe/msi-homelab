# 0030 — A new public repository with its own history

**Status:** executed (2026-11-26).

**Context.** The panel and the setup notes grew in private repositories whose
history mixes in personal details (one had commits with a personal e-mail).

**Decision.** A new repository whose history starts here; earlier work is
summarised, not imported. Commits use a noreply identity, carry their real
dates, and each one is audited before it is made (`scripts/audit-public.sh`).

**Consequences.** The early history of the panel is not visible here; the
runbook and decisions keep the dates of the original work.
