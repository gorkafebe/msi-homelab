# 00 — Hardware and choice of OS

**Status:** verified (2026-11-02 for the system, 2026-11-26 for the GPU).

## Goal

Know exactly what the machine is before choosing how to run it, and record it
with the command that proves each fact.

## The machine

| Part | Value | How it was checked |
|---|---|---|
| Model | MSI Katana GF66 12UE (gaming laptop), x86_64 | vendor label, `hostnamectl` |
| CPU | Intel Core i7-12700H, 14 cores / 20 threads, 400–4700 MHz | `lscpu` |
| RAM | 16 GB (`free -h` shows 15 GiB), swap 4 GiB | `free -h` |
| Disk | one NVMe SSD, Micron 2450, sold as 512 GB (`lsblk` shows 476.9G because it counts in GiB) | `lsblk` |
| Integrated GPU | Intel Iris Xe (Alder Lake-P), drives the screen | `lspci -nnk` |
| Dedicated GPU | NVIDIA **GeForce RTX 3060 Mobile / Max-Q** (GA106M), PCI ID `10de:2520`, 6 GiB VRAM, driver `nouveau` | sysfs, kernel log, `pci.ids` (page [11](11-gpu-power.md)) |
| Network | one wired port, one Wi-Fi card | `ip -br link` |
| Battery | Li-ion, about 66 % of its design capacity at setup | `/sys/class/power_supply/BAT1/charge_full{,_design}` |

Reading the GPU's IDs without waking it up (it is normally powered off):

```sh
d=/sys/bus/pci/devices/0000:01:00.0
cat $d/vendor $d/device $d/subsystem_vendor $d/subsystem_device $d/power_state
grep -P '^\t2520 ' /usr/share/misc/pci.ids        # GA106M [GeForce RTX 3060 Mobile / Max-Q]
journalctl -k -b | grep -i 'nouveau.*VRAM'         # VRAM: 6144 MiB
```

`lspci` gives the same answer but powers the GPU on for a moment
([lessons](../lessons.md#reading-the-gpu-wakes-it-up)).

## Why Ubuntu Server 24.04 LTS, headless

- **Server, not desktop:** no graphical session using RAM and waking the GPU.
- **LTS:** five years of security updates; the same base as the development
  laptop, so containers behave the same on both.
- **Stay on 24.04 for now:** the installer offered 26.04; upgrading is a
  deliberate step for later, on both machines together
  ([decision 0001](../decisions/0001-ubuntu-server-lts.md)).
- **No disk encryption:** the server must boot by itself after a power cut,
  with nobody at the keyboard to type a passphrase
  ([decision 0002](../decisions/0002-no-disk-encryption.md)). The cost: anyone
  who takes the laptop can read the disk. That is why health data is the only
  personal data on it and backups go elsewhere.

## Verify

```sh
lscpu | grep 'Model name'; free -h; lsblk -d -o NAME,SIZE,MODEL
cat /etc/os-release | grep PRETTY_NAME
```

## Undo

Nothing to undo: this page only reads.
