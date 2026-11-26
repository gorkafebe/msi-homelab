# 0026 — One Grafana, two folders, same port

**Status:** in force.

**Context.** Adding health data could have meant a second Grafana (as the
upstream garmin-grafana example does).

**Decision.** One Grafana on `127.0.0.1:3000` — the one already behind
`tailscale serve` — with two folders, "Server (MSI)" and "Garmin", and two
provisioned datasources: Prometheus and InfluxDB (InfluxQL, read-only account).
The Garmin module adds its files by mounting them next to the base ones.

**Alternatives.** A second Grafana (another port, another login, another
`serve` entry, double memory).

**Consequences.** One login, one URL, nothing changes in Tailscale. Grafana's
memory limit rises to 768M when the module is on (the demo reached ~500 MiB).
