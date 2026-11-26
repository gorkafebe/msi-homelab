# 14 — Garmin module

**Status:** planned on the real server. Verified with invented data and without
network: the demo (`make demo`), the offline tests (`make garmin-test`).

The module adds InfluxDB, the garmin-grafana fetcher and a "Garmin" folder to
the same Grafana. Health data stays on the machine.

Everything — installation, the one-time manual login, two-factor codes, rate
limits, Garmin's terms of service, the official export as an alternative and
how to delete the tokens — is in [docs/GARMIN.md](../GARMIN.md).
