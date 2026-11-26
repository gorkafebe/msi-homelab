# 16 — Reboot, cold-boot and on-battery tests

**Status:** planned as a written test plan. Partial evidence: after a boot on
2026-11-26 the battery unit ran and every container came back healthy by
itself; whether that boot followed a full power-off is not known.

## Goal

Prove that the server comes back on its own, with its settings, after the
events a home server will meet.

## Rules for every test

- Do one test at a time and write the result (date, time, what was seen, pass
  or fail) in your log.
- Before each one, note the state the checks below print; compare after.
- Keep physical access to the machine during the test.

## Checks to run after each test

```sh
uptime; systemctl --failed
docker ps --format 'table {{.Names}}\t{{.Status}}'          # all Up (healthy)
cat /sys/class/power_supply/BAT1/charge_control_{start,end}_threshold
systemctl status battery-charge-limit.service | head -3
ss -tlnp | grep -v -E '127\.0\.0\.|\[::1\]'                  # nothing new facing the network
tailscale status | head -3; tailscale serve status
```

## Tests

| # | Test | Expected |
|---|---|---|
| 1 | Normal reboot (`sudo reboot`) | SSH back within a few minutes; all checks as before |
| 2 | Cold boot: shut down, unplug, wait 1 minute, plug in, power on | as test 1; charge limit still 50/60 |
| 3 | Unplug the charger for 10 minutes | battery status `Discharging`, panel shows battery power; plugged again: `Not charging` |
| 4 | From another network (phone on mobile data, Wi-Fi off), IPv4 and IPv6 if available | private ports do not answer; only what you meant to publish does |
| 5 | From a device in the tailnet | `http://<hostname>:3000` opens Grafana's login |

If the server does not come back: go to it, open the lid, and read the end of
the previous boot's log with `journalctl -b -1 | tail -n 50`.

## Undo

Nothing to undo.
