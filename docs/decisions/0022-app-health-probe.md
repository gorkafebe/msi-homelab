# 0022 — App health with blackbox_exporter, GET only, ≥ 30 s

**Status:** in force; optional profile (`apphealth`) in this repository.
**Source:** D-82.

**Decision.** blackbox_exporter asks the hosted web app's health URLs with a
GET every 30 seconds (not 15: real requests to a production service, kept to a
minimum), never following redirects. The URLs live in an ignored file
(`prometheus/targets/apphealth.yml`), not in the repository.

**Consequences.** The panel shows up/down, response time and HTTP status per
URL. Without the profile and the file, nothing is probed.
