# Lessons: real problems and how they were solved

Each entry: **symptom → cause → fix**, and how sure we are. Entries marked
`P-xx` come from the problem log of the private project this server was built
for (translated); the rest were met while building this repository.

## Installing and configuring the server

### The root filesystem had only 98 GB (P-09)
`df -h /` showed about 98 GB on a 477 GiB disk. **Cause:** the installer's
guided LVM layout leaves most of the volume group unallocated. **Fix:**
`lvextend -l +100%FREE -r` online ([runbook 02](runbook/02-disk-lvm.md)). Verified.

### Wi-Fi never connected: wpasupplicant was missing (P-10)
The interface stayed `NO-CARRIER`; the service failed with `status=203/EXEC`.
**Cause:** exit code 203 means "the program to run does not exist" —
`/sbin/wpa_supplicant` was not installed. **Fix:** install `wpasupplicant`
while the cable works, then `netplan apply`. Verified.

### ssh-keygen replaced an existing key (P-02)
Answering "yes" to "Overwrite?" destroys the old private key and every login
that used it. **Fix:** always `ls -la ~/.ssh` first; create a key only if none
exists.

### An SSH test run on the server itself proved nothing (P-11)
A "must fail" password test was typed on the server, whose own name points to
itself, so it tested the wrong thing. **Fix:** run SSH tests from another machine.

### The server stopped responding with the lid closed (P-20)
Idle, lid closed (ignored as configured), then silence; the kernel log ends
with a USB controller error and no clean shutdown. **Cause:** unknown; no sleep
attempt was logged. **Precaution:** mask the sleep targets; if it happens again,
read `journalctl -b -1 | tail -n 50` after the reboot. Open.

### The time zone changed, but /etc/timezone did not (P-17, P-40)
The server ran on UTC (times one hour off); after changing it,
`/etc/localtime` was right and `/etc/timezone` still said `Etc/UTC`. To confirm
whether a second `timedatectl set-timezone` aligns both.

### The cable was down and nobody noticed (P-42)
The server had silently moved to Wi-Fi. **Fix:** the panel shows link state,
"Active uplink" and link-change counters.

### Load average about 1 at idle (P-25)
USB power-management kernel threads sit in uninterruptible state (`D`), which
counts towards load without using CPU. No effect measured. Open.

## Docker

### Permission denied on the Docker socket after joining the group (P-01)
`usermod -aG docker` applies to **new** sessions. **Fix:** log out and in.
Remember: the `docker` group is root-equivalent.

### Published ports bypass ufw (principle behind decision 0010)
`ufw deny` does not stop a port published by Docker. **Fix:** do not publish
private services; bind them to `127.0.0.1` ([runbook 08](runbook/08-firewall-docker.md)).

### `docker kill` does not test the restart policy (P-23)
A container stopped by the user is not restarted, by design. To test
`restart: unless-stopped`, kill the main process inside the container or reboot.

### Docker cannot add a file inside a read-only bind mount
Mounting `datasource.yaml` into a folder that was itself mounted `:ro` failed:
`make mountpoint ... read-only file system`. **Fix:** mount each provisioning
file individually into the image's own (writable-layer) folders, so another
compose file can add more ([decision 0026](decisions/0026-single-grafana-two-folders.md)).

### `COPY --chmod` also set the mode of the folder it created
`COPY --chmod=644 login.py /app/login.py` created `/app` without the execute
bit, so nobody could enter it ("Permission denied" listing `/app`). **Fix:**
create the folder first with its own mode (`install -d -m 755 /app`).

### The InfluxDB image runs as uid 1500
A test InfluxDB on a tmpfs never finished its init: `mkdir /var/lib/influxdb/meta:
permission denied`. **Fix:** `--tmpfs /var/lib/influxdb:uid=1500,gid=1500`.
(Named volumes copy the image folder's owner and do not have this problem.)

### The InfluxDB init script uses port 8086, whatever you configure
The official 1.x entrypoint starts a temporary server on `127.0.0.1:8086` to
create users. A second InfluxDB on another port, next to a real one on 8086,
would clash. **Fix (demo):** run `influxd` directly and create the accounts from
the seeder.

## Monitoring

### A Grafana image stopped updating (P-16)
`grafana/grafana-oss` stopped receiving updates. **Fix:** `grafana/grafana`, pinned.

### node_exporter logged an error at every start (P-15)
The disk-stats collector could not find udev data under the host mount.
**Fix:** `--path.udev.data=/host/run/udev/data`.

### Battery power read 0 W on mains; another panel showed 9.1 W plugged in (P-44, P-48)
On mains the battery is idle: current × voltage is not the laptop's consumption.
**Fix:** show battery power only while discharging, and model the total
([decision 0021](decisions/0021-power-total-is-a-model.md)).

### The RAPL collector "worked" but exported nothing (P-45)
Its files are root-only since kernel 5.10. **Fix:** a second, capability-less
root exporter that only sees `/sys` ([decision 0019](decisions/0019-rapl-capless-root-exporter.md)).

### RAPL psys is not the whole laptop here (P-47)
Measured on battery: psys 0.22 W against 7.91 W from the battery. Discarded.

### busybox wget does not validate TLS certificates (P-46)
Fine for loopback health checks; never use it to fetch from the internet.
The price fetcher uses Python with certificate checks.

### Experiment marks were invisible; "no backup" showed green (P-50)
Grafana expects annotation times in milliseconds (the metric was in seconds),
and a panel with no data takes the base threshold colour. **Fix:** multiply by
1000; return −1 when the metric is missing and colour it red with a text.

### Reading the GPU wakes it up (P-39)
`lspci`, `current_link_*` and `ubuntu-drivers` power the GPU on for 0.7–7 s and
spoil "how long was it off". **Fix:** read IDs and power state from sysfs
([runbook 11](runbook/11-gpu-power.md)).

### The documented access was not the real one (P-51)
Docs said HTTPS on 8443; `tailscale serve status` showed HTTP on 3000.
**Fix:** check the real state with a read-only command before documenting it.

### A disk forecast said "full in 6 days"
Right after a reboot, `predict_linear` over a short window saw a burst of image
builds and extrapolated it. Not a fault, but a reminder that a forecast needs
a long, quiet window.

## Screenshots and dashboards

### State-timeline panels were empty in headless screenshots (P-49)
Some `state-timeline` panels drew no bars in headless Chromium although the
queries returned data. **Fix that worked for the Garmin dashboard:** give
Chromium virtual time to finish (`--virtual-time-budget=20000`). Two panels of
the server dashboard still came out empty right after a reboot; they are kept
out of published screenshots.

### Grafana's memory includes its tmpfs
The demo Grafana keeps its database in RAM; with the Garmin dashboard open it
reached 507 of 512 MiB. **Fix:** 768M for the demo and for the real Grafana
with the module.

### "58 datasource references" were 202
The upstream dashboard has 58 panel-level references to `${DS_GARMIN_STATS}`
and 144 more inside queries. The transform script now expects exactly 202 and
stops on any other count.

## Working method

### A here-document ran documentation as commands (P-07, P-57)
A shell here-document that was not closed where expected executed the rest of
a pasted text as commands. **Fix:** write files with an editor; keep shell
commands short. (While building this repository, short Python here-documents
were still used for a few scripted edits before the rule was applied; no
unexpected text ran, and later edits used files.)

### Commits with the wrong identity (P-03, P-26, P-41)
Commits made on another machine used a different author, one with a personal
e-mail. **Fix:** set the noreply identity per repository; check
`git log -1 --format='%an %ae'` after every commit.

### A false positive in the address audit
`activityType::field` in the upstream dashboard matched the IPv6 pattern.
**Fix:** match addresses as whole words; the audit has a self-test with planted
values.
