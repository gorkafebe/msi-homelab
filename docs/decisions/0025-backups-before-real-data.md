# 0025 — Backups ready before real data; a restore test decides

**Status:** planned (tools ready; no device chosen; no real backup yet).
**Source:** D-07, D-66, D-67 (adapted to this repository).

**Context.** The requirement comes from the hosted web app: no real recordings
on the server before a backup has been restored successfully. The same rule now
applies to the Garmin health history.

**Decision.** 3-2-1 (three copies, two media, one off-site); encrypted before
leaving the machine (restic planned, in a pinned container); a backup counts
only after a restore test into a throwaway project. Session tokens are not
backed up: a fresh login is safer.

**Consequences.** See [runbook 15](../runbook/15-backups.md). The dashboard's
"Last backup" and "Last restore test" panels stay red until this is done.
