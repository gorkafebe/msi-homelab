# 0024 — The repository adopts the running panel's volumes

**Status:** in force (chosen 2026-11-26; the move itself is the owner's step).

**Context.** The panel already runs from a private folder; its Prometheus
history and Grafana database live in volumes named `<project>_<key>`. A
compose file with other keys or another project name would start empty.

**Decision.** Keep the original volume keys (`prometheus-data`,
`grafana-data`, `textfile-gen` with identical options) and deploy from this
repository under the **same project name**, after a read-only tar backup
(`scripts/backup-volumes.sh`). Roll back by starting the old file under the
same name.

**Alternatives.** Fixed volume `name:`s (works with any project name, but
Compose warns that the volume belongs to another project); keep running from
the old folder and treat the repository as a publishable copy (two copies that
drift apart, and no place to plug in the Garmin module).

**Consequences.** One source of truth. `make` still refuses that name
([0023](0023-explicit-compose-project-name.md)): production is started by hand
with the documented commands.
