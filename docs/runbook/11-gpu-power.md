# 11 — The NVIDIA GPU: leave it off

**Status:** verified (2026-11-05: powered off 99.97 % of the time since boot;
2026-11-26: model and state re-read).

## Goal

A gaming laptop running as a server should not spend power on its dedicated
GPU. The surprise: with the open-source `nouveau` driver and runtime power
management, it is **already** fully powered off when unused
([decision 0015](../decisions/0015-power-saving-no-proprietary-driver.md)).

## The GPU

NVIDIA GeForce RTX 3060 Mobile / Max-Q (GA106M), PCI ID `10de:2520`, subsystem
`1462:1333`, 6 GiB of VRAM, driver `nouveau`. (A "class RTX 3050" guess from an
earlier note was wrong; the PCI ID settles it.)

## What "off" means

The kernel's runtime power management suspends the GPU when nothing uses it,
and the laptop's firmware then **cuts its power**: the PCI state called
**D3cold** (D3hot would only put it to sleep, still powered).

```sh
d=/sys/bus/pci/devices/0000:01:00.0
cat $d/power/control          # auto
cat $d/power_state            # D3cold
cat $d/power/runtime_suspended_time $d/power/runtime_active_time    # milliseconds
```

## Things that wake it

Measured by watching `runtime_active_time` grow:

| Action | Effect |
|---|---|
| reading `power/*`, `power_state`, `vendor`, `device` in sysfs | none |
| `lspci`, `lspci -nnk` | about 0.7 s awake |
| reading `current_link_speed` or `current_link_width` | about 7 s awake |
| `ubuntu-drivers devices` | about 6 s awake |

## Options considered (none applied)

| Option | Verdict |
|---|---|
| Leave nouveau + runtime PM `auto` | **chosen**: it already reaches D3cold |
| Blacklist nouveau | not recommended: without a driver the GPU may stay powered |
| Proprietary NVIDIA driver | not needed for power; it is the owner's decision for later (see [ROADMAP_LOCAL_LLM.md](../ROADMAP_LOCAL_LLM.md)) |

## Verify

The monitoring panel's "Power and GPU" row shows the state ("Off (D3cold)") and
"GPU time off" over the selected range.

## Undo

Nothing was changed.
