# 06 — Time zone

**Status:** verified (2026-11-03); one loose end: to confirm.

## Goal

Logs, `date` and commit times on the server match local time. A fresh Ubuntu
Server runs on UTC, so everything made on it looked an hour off (two in
summer) next to the other machines.

## Steps

```sh
timedatectl                                  # before: Time zone: Etc/UTC
sudo timedatectl set-timezone <Area/City>    # e.g. Europe/Berlin
timedatectl                                  # after: your zone, "System clock synchronized: yes"
```

Containers keep their own zone (UTC) unless told otherwise. That is fine:
Grafana draws times in the browser's zone.

## Verify

```sh
timedatectl | grep -E 'Time zone|synchronized'
readlink /etc/localtime
cat /etc/timezone
```

## Loose end (to confirm)

After the change `/etc/localtime` pointed to the new zone but `/etc/timezone`
still said `Etc/UTC`; a few programs read that file instead. Running
`sudo timedatectl set-timezone <Area/City>` once more should leave both in
agreement (not tested) — [lessons](../lessons.md#the-time-zone-changed-but-etctimezone-did-not).

## Undo

```sh
sudo timedatectl set-timezone Etc/UTC
```
