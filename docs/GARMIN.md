# Garmin module

Your Garmin watch data — sleep, heart rate, stress, steps, activities — in the
same Grafana as the server's health, stored only on your machine.

> **Read this first.** The module uses an **unofficial** way into Garmin
> Connect (the [garmin-grafana](https://github.com/arpanghosh8453/garmin-grafana)
> fetcher and the [python-garminconnect](https://github.com/cyberjunky/python-garminconnect)
> library). Garmin does not offer this to individuals, it **may breach Garmin's
> terms of service**, and Garmin can block it or the account at any time. Read
> Garmin's terms yourself and decide. The safe alternative is Garmin's official
> data export ([below](#the-official-export-the-account-safe-alternative)).
> Nothing here is medical advice.

**Status:** planned on the real server. Verified without a Garmin account: the
demo with invented data (`make demo`) and the offline tests (`make garmin-test`).
Everything that needs a real account is **not verified**.

## What runs

| Piece | What it does | Network |
|---|---|---|
| `influxdb` (1.11.8) | stores the time series; authentication on; three accounts: admin, writer (fetcher), **read-only reader** (Grafana) | HTTP `127.0.0.1:8086`, backup RPC `127.0.0.1:8088` |
| `garmin-fetch` | garmin-grafana's fetcher, built from a pinned commit; every 5 minutes asks Garmin for new data and writes it | outbound to Garmin; InfluxDB on loopback |
| `garmin-login` | **one-shot**, run by hand once: makes the first login and saves session tokens | outbound only (bridge network) |
| Grafana (existing) | gets an InfluxDB datasource and a "Garmin" folder | unchanged: `127.0.0.1:3000` |

Volumes: `<project>_influxdb-data` (your health data) and
`<project>_garmin-tokens` (the session tokens). Design:
[decision 0027](decisions/0027-garmin-module-garmin-grafana.md),
[0028](decisions/0028-garmin-login-tokens-only.md).

## Install (from the repository root)

```sh
scripts/init-env.sh                     # adds the three InfluxDB passwords to .env, never printed
make garmin-build                       # builds both images from pinned sources
cd stacks/monitoring
docker compose -p <project> --env-file ../../.env -f compose.yaml -f ../garmin/compose.garmin.yaml up -d
docker compose -p <project> -f compose.yaml -f ../garmin/compose.garmin.yaml ps
```

`garmin-fetch` will show **unhealthy** and log `HOLD: no token file at ...`:
correct — it waits for the first login and makes no request meanwhile.

## The first login — once, by hand

```sh
cd stacks/monitoring
docker compose -p <project> --env-file ../../.env -f compose.yaml -f ../garmin/compose.garmin.yaml \
  --profile garmin-login run --rm garmin-login
```

It asks for your e-mail, your password (**hidden**, with `getpass`) and, if the
account has two-factor authentication, the code Garmin sends by e-mail or SMS.
Then:

- **One attempt.** The library normally tries up to five login strategies and
  several TLS fingerprints in one go; here it may try exactly **one**, so one
  run sends your credentials once. Nothing is retried.
- **Only tokens are kept**: `garmin_tokens.json` (mode 600) in the
  `garmin-tokens` volume. The password is never written to a file, the
  environment, an argument or a log; library logging is off. (Because the
  container has a terminal, Docker keeps its output — the typed e-mail, never the
  password — until the container is removed; `--rm` removes it at the end.)
- It checks the saved file really holds the long-lived tokens the fetcher
  needs; a web-only session that cannot be saved is reported, not used.

Then restart the fetcher and watch it work:

```sh
docker compose -p <project> -f compose.yaml -f ../garmin/compose.garmin.yaml restart garmin-fetch
docker compose -p <project> -f compose.yaml -f ../garmin/compose.garmin.yaml logs -f garmin-fetch
```

The first run fetches the last 7 days. Older history can be loaded later with
the upstream bulk options (`MANUAL_START_DATE`), slowly.

### If the login fails: 429 / 427, wrong password, bot challenge

| Message | What to do |
|---|---|
| rate-limited or blocked (HTTP 429/427) | **Do not try again now.** Wait several hours — a day is safer — and make **one** new attempt. Repeated attempts extend the block; users report account locks of a day or more after a few failures (reports, not verified). |
| e-mail/password rejected | Log in on the Garmin Connect website first to check them. Repeated wrong passwords can lock the account. |
| network problem or bot challenge | Check the connection; do not loop. |
| session that cannot be saved | The library got only a web cookie. Do not retry now; check for a newer garminconnect release and this file. |

**Why the fetcher never retries a login.** Upstream, a fetcher without valid
tokens asks for the password on the terminal; in a container with a restart
policy that becomes a new attempt at every restart. Here a wrapper decides
before the fetcher runs:

1. token folder not accessible, token file missing, unreadable (permissions: it must belong to uid 1000, mode 600) or with invalid content → **hold** with a message saying which (no network traffic at all);
2. a hold marker from a previous stop → **hold**;
3. otherwise run the fetcher with stdin closed and no credentials in the
   environment; if it ever exits — expired session, refused tokens, any error —
   write the marker and **hold**.

"Hold" means: log one line and sleep. The container stays up, so Docker never
restarts it, and a reboot comes back to rule 1 or 2. Tested offline, without
any network, with no tokens, fake tokens and restarts
(`stacks/garmin/tests/test-fetcher-wrapper.sh`).

**Release a hold** after fixing the cause (often: a new first login):

```sh
docker compose -p <project> -f compose.yaml -f ../garmin/compose.garmin.yaml exec garmin-fetch \
  cat /home/appuser/.garminconnect/fetcher.hold        # when it stopped and the exit code
docker compose -p <project> -f compose.yaml -f ../garmin/compose.garmin.yaml exec garmin-fetch \
  rm /home/appuser/.garminconnect/fetcher.hold
docker compose -p <project> -f compose.yaml -f ../garmin/compose.garmin.yaml restart garmin-fetch
```

(A successful `garmin-login` removes the marker by itself.)

## Token compatibility (read, not verified)

The login uses garminconnect **0.3.20** (its changelog says it fixed the mobile
login that returned 429 from April); the fetcher keeps garmin-grafana's
**0.3.7**. Reading both versions' source code: they store the same file
(`<dir>/garmin_tokens.json`), with the same three keys (`di_token`,
`di_refresh_token`, `di_client_id`), and refresh at the same endpoint with the
same client IDs. Whether Garmin accepts a 0.3.7 refresh of a 0.3.20 token has
**not** been tested — it needs a real account. If it fails, the fetcher holds
and the logs say so.

## Delete the tokens

```sh
docker compose -p <project> -f compose.yaml -f ../garmin/compose.garmin.yaml stop garmin-fetch
docker run --rm --network none -v <project>_garmin-tokens:/t busybox:1.37.0 \
  rm -f /t/garmin_tokens.json /t/garmin_tokens.json.old /t/fetcher.hold
```

Removing the file stops local use. Whether Garmin also ends the session on its
side (for example after a password change) is **to confirm**. To delete the
health data too: stop the module and remove the `<project>_influxdb-data`
volume — irreversible, back it up first if in doubt.

## The official export: the account-safe alternative

Garmin's account data management page has **Export Your Data**: Garmin e-mails a
link to a ZIP with your account data and the original activity files (FIT).
Third-party guides report 24–48 hours, sometimes up to 30 days, and no date
filter (sources: takeoutday.org and gneta.app guides, read 2026-11-26; Garmin's
own page not read). It is a one-off snapshot, not continuous, but it involves
no unofficial access. garmin-grafana has importers for FIT files
(`fit_activity_importer.py`, `garmin_bulk_importer.py`) — not used or tested here.

## What the demo shows

`make demo COMPOSE_PROJECT_NAME=homelab-dev` fills a throwaway InfluxDB (in RAM)
with a year of **invented** data — fixed random seed, GPS circling latitude 0,
longitude 0 — and opens a read-only Grafana on `http://127.0.0.1:13300`.
Measured: about 868,000 points, 28 MB on disk (16 MB data + 12 MB write-ahead
log, a few minutes after writing). 54 of the 55 data panels show data; "Battery
Level" needs a Home Assistant integration that is not simulated, and
"Activities (last 24 hours)" is empty whenever there was no activity in the
last day.

Differences from the upstream dashboard (all in
[THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)): no map panels (external
map tiles), no donation panel (external image), two plugin heatmaps converted to
the built-in heatmap.

## Data and privacy

- Health data, activity times and any location in activity files stay in
  `<project>_influxdb-data` on the machine; Grafana reads it with a read-only
  account; nothing is published.
- The fetcher writes no copies of FIT/TCX files (`KEEP_FIT_FILES=False`) and
  does not tag data with your account name.
- Screenshots in this repository use invented data only.
