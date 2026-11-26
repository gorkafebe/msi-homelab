# Security model

What this setup protects, from whom, how — and what it does not protect.
It describes the intended configuration and how to check it; it is not a report
on any particular machine.

## Assets

| Asset | Where | Sensitivity |
|---|---|---|
| Garmin health and activity data | InfluxDB volume | **high** (personal health; activity files can include location) |
| Garmin session tokens | `garmin-tokens` volume, `garmin_tokens.json`, mode 600 | **high** (access to the Garmin account without the password) |
| Passwords (Grafana admin, InfluxDB accounts) | `.env`, mode 600, ignored by git | high |
| Host metrics | Prometheus volume | low/medium (reveals activity patterns, versions) |
| The server itself | the laptop | high: Docker access is root access |

## Threats and what answers them

| Threat | Answer | Check |
|---|---|---|
| Someone on the LAN or the internet reaches a dashboard or database | every service listens on `127.0.0.1`; no Docker-published ports (they would bypass ufw); InfluxDB's HTTP **and** RPC ports bound to loopback | `ss -tlnp` — private ports only on `127.0.0.1` |
| Someone in the tailnet opens Grafana | Grafana keeps its login; only port 3000 is served; never `funnel` | `tailscale serve status`, `tailscale funnel status` |
| Grafana is compromised | it reads InfluxDB with a **read-only** account; it cannot change or delete health data | InfluxDB `SHOW GRANTS FOR garmin_reader` |
| Garmin password leaks | it is never stored: typed once with `getpass` in a one-shot container; refused if found in the environment | `docker compose config` shows no `GARMINCONNECT_*` |
| A login loop gets the account blocked | one login strategy, one attempt; the fetcher holds without network instead of retrying | `make garmin-test` |
| Tokens leak | mode 600 in a 700 folder; not in backups; deletable ([GARMIN.md](GARMIN.md#delete-the-tokens)) | `ls -l` inside the volume |
| Passwords leak in logs | InfluxDB's HTTP access log is off (the Python client sends credentials as query parameters); the scripts never print values | `docker compose logs influxdb` |
| Secrets or personal data published in this repository | `.gitignore`; `scripts/audit-public.sh` on every commit and on the whole history (local denylist, addresses, `*.ts.net`, MAC, e-mails, gitleaks); screenshots from invented data | [PUBLISH_CHECKLIST.md](PUBLISH_CHECKLIST.md) |
| A tampered image or package | images pinned by tag **and** digest; the fetcher built from a pinned commit with upstream's hashed lock file; the login image installs with `pip --require-hashes`; CI actions pinned to commit SHAs | `THIRD_PARTY_NOTICES.md` |
| A container escapes its limits | unprivileged users, `cap_drop: ALL`, read-only root filesystems, `no-new-privileges`, memory limits (exceptions documented: node_exporter mounts `/` read-only; the RAPL exporter is root without capabilities) | `docker inspect` |
| Dashboards load third-party content | map tiles and external images removed from the Garmin dashboard; Grafana's update checks, news, gravatar and plugin downloads off | browser network tab |

## Known limits — not protected

- **The `docker` group equals root.** Anyone in it, or any process that can talk
  to the Docker socket, controls the machine.
- **Host networking**: containers are not isolated from each other at network
  level; the Garmin fetcher can reach every loopback service. Accepted because
  every loopback service still asks for credentials where it matters (Grafana,
  InfluxDB) and Prometheus holds no secrets.
- **No disk encryption** ([decision 0002](decisions/0002-no-disk-encryption.md)):
  physical theft exposes the data.
- **Plain HTTP inside the tailnet**: encrypted by WireGuard, but Grafana's cookie
  is not marked `Secure`.
- **Unofficial Garmin access** may breach Garmin's terms; Garmin may block it.
- **Third-party code**: the fetcher runs upstream code with the writer account
  and access to your Garmin session; it is pinned and reviewed only partially
  (login, token handling, network use).
- **No alerts**: nobody is notified of anything ([decision 0017](decisions/0017-grafana-login-alerts-design-only.md)).

## Reporting

This is a personal project. If you find a problem, open an issue without
details that would help an attacker, and you will be contacted.
