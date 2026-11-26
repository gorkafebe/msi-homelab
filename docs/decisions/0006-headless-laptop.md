# 0006 — Ignore the lid, never sleep, blank the console

**Status:** in force (executed 2026-11-02). **Source:** D-26, D-38.

**Context.** Closing a laptop's lid suspends it; a suspended server is a dead
server. The machine once stopped responding with the lid closed (cause unknown).

**Decision.** logind ignores the lid in every power state; the four sleep
targets are masked; the console blanks after 60 s (`consoleblank=60`).

**Alternatives.** Keep the lid open (screen burn, dust, heat); only the logind
setting (other triggers could still suspend).

**Consequences.** Nothing can suspend the machine, including by mistake. The
cooling is worse with the lid closed: measured, acceptable at idle
([runbook 05](../runbook/05-headless.md)).
