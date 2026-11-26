# 05 — Headless: lid, sleep, console, temperatures

**Status:** lid, sleep and console verified (2026-11-02); temperatures with the
lid closed measured over one day (2026-11-03); BIOS options: to confirm.

## Goal

The laptop runs 24/7 with the lid closed and never suspends
([decision 0006](../decisions/0006-headless-laptop.md)).

## Steps

### Ignore the lid

By default closing the lid suspends the laptop and the server disappears.
Copy [host/logind/50-server-lid.conf](../../host/logind/50-server-lid.conf) to
`/etc/systemd/logind.conf.d/` and apply:

```sh
sudo systemctl restart systemd-logind
```

(The original setup uncommented the same three lines in
`/etc/systemd/logind.conf` itself; the drop-in has the same effect and is
easier to undo — not verified on this machine in that form.)

### Never sleep

Mask the four sleep targets: systemd then refuses to suspend or hibernate,
whatever asks for it (lid, key, idle timer, a command):

```sh
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

This was added after the machine once stopped responding with the lid closed;
the cause is unknown and no sleep attempt appears in the logs, so masking is a
precaution, not a proven fix
([lessons](../lessons.md#the-server-stopped-responding-with-the-lid-closed)).

### Turn the console off when idle

Only matters with the lid open. Add `consoleblank=60` to the kernel command line
([host/grub/consoleblank.txt](../../host/grub/consoleblank.txt)), then
`sudo update-grub && sudo reboot`.

### Temperatures

```sh
sudo apt install -y lm-sensors && sudo sensors-detect     # accept the defaults
sensors
```

Watch `coretemp` → **Package id 0** (the CPU) and `nvme` → **Composite** (the
SSD). Ignore the absurd limits printed for the SSD's `Sensor 1`.

One day with the lid closed (measured from Prometheus, 2026-11-02/03): CPU
package average 33.7 °C, median 33 °C, maximum 95 °C during container builds;
1.25 minutes above 90 °C in the whole day. SSD average 24.5 °C, maximum
30.9 °C. Idle with the lid closed is no problem; long heavy jobs reach the
CPU's limit region within minutes, so measure before running them unattended.

Cooling: hard surface, vents free, slightly raised if possible.

### BIOS options (to confirm)

- *Restore after AC power loss* (power on by itself after a cut): exists on MSI
  desktop boards; **not confirmed** on this laptop.
- The battery charge limit is **not** a BIOS option on MSI laptops; see
  [page 09](09-battery-limit.md).

## Verify

```sh
systemd-analyze cat-config systemd/logind.conf | grep -E '^HandleLidSwitch'   # three lines = ignore
systemctl is-enabled sleep.target suspend.target hibernate.target hybrid-sleep.target   # masked x4
cat /sys/module/kernel/parameters/consoleblank                                # 60
```

Practical test: with an SSH session open, close the lid; the session must stay alive.

## Undo

```sh
sudo rm /etc/systemd/logind.conf.d/50-server-lid.conf && sudo systemctl restart systemd-logind
sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

and remove `consoleblank=60` from `/etc/default/grub`, `update-grub`, reboot.
