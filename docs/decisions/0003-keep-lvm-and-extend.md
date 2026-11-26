# 0003 — Keep LVM and extend the root volume

**Status:** executed 2026-11-02. **Source:** D-23.

**Context.** The installer's LVM default left the root at about 98 GB of a
477 GiB disk; the rest was unallocated. The disk space was the point of the
machine: the hosted web app stores audio on it.

**Decision.** Keep LVM and grow the volume online:
`lvextend -l +100%FREE -r` ([runbook 02](../runbook/02-disk-lvm.md)).

**Alternatives.** Reinstall without LVM (an hour lost, nothing gained);
leave it (the disk fills at 98 GB).

**Consequences.** LVM stays available for snapshots or a second disk. Next
time: untick LVM, or extend right after the first boot.
