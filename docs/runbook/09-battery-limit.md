# 09 — Battery charge limit with msi-ec

**Status:** verified (limit set 2026-11-02, re-checked 2026-11-03; the boot unit
ran at a real boot and left 50/60 on 2026-11-26). **Not verified:** after a
cold boot with all power removed, a fully drained battery or a BIOS update.

## Goal

A laptop that is always plugged in keeps its lithium battery at 100 % and warm,
which wears it out fast. Holding it at **60 %** slows that down
([decision 0013](../decisions/0013-battery-limit-msi-ec.md)). The laptop's
**embedded controller** (EC, a small chip with its own firmware for keyboard,
fans and charging) applies the limit; it does not drain the battery and does
not limit performance.

## Requirements

- Kernel 6.5 or newer, `build-essential`, `linux-headers-generic`, `dkms`.
- Secure Boot handled ([page 10](10-secure-boot-mok.md)).

## Steps

1. Ubuntu's own `msi_ec` refused this laptop: `Firmware version is not
   supported: '1583EMS1.109'`. The external, newer driver
   [BeardOverflow/msi-ec](https://github.com/BeardOverflow/msi-ec) lists that EC
   firmware (under a sister model; the driver recognises laptops by EC
   firmware, not model name). Check yours first:
   `cat /sys/class/dmi/id/product_name`, and the project's supported list.

2. Build and install it with **DKMS**, which rebuilds the module for every new
   kernel (this repository does not copy the driver's code):

   ```sh
   sudo apt install -y build-essential linux-headers-generic dkms
   git clone https://github.com/BeardOverflow/msi-ec ~/msi-ec
   cd ~/msi-ec && sudo make dkms-install
   ```

   The module goes to `/lib/modules/<kernel>/updates/dkms/` (it takes priority
   over the kernel's own) and `/etc/modules-load.d/msi-ec.conf` loads it at boot.

3. Set the limit. Start and end are one setting in the EC (start = end − 10);
   MSI's own modes are 60/50, 80/70 and 100/90:

   ```sh
   echo 60 | sudo tee /sys/class/power_supply/BAT1/charge_control_end_threshold
   ```

4. Re-apply it at every boot with the unit
   [host/systemd/battery-charge-limit.service](../../host/systemd/battery-charge-limit.service):

   ```sh
   sudo systemctl daemon-reload && sudo systemctl enable --now battery-charge-limit.service
   ```

   The EC usually keeps the value by itself while on mains (two reboots on
   2026-11-02 did not reset it); the unit covers the cases where it might not.

## Verify

```sh
cat /sys/class/power_supply/BAT1/charge_control_{start,end}_threshold   # 50, 60
cat /sys/class/power_supply/BAT1/{status,capacity}                      # Not charging, ...
dkms status                                                              # msi_ec/..., <kernel>: installed
systemctl status battery-charge-limit.service                            # active (exited) since this boot
```

A battery at 95 % with a 60 % limit stays at 95 %: the EC stops charging but
never discharges; it charges again only below 50 %. The monitoring panel shows
the limits ("Battery charge limits") and the slow drift.

## After a kernel update

If the two `charge_control_*` files are missing after rebooting into a new
kernel, DKMS did not build the module for it:

```sh
sudo apt install linux-headers-$(uname -r)
sudo dkms install msi_ec/<version> -k "$(uname -r)"
sudo modprobe msi_ec && sudo systemctl restart battery-charge-limit.service
```

`Key was rejected by service` means the Secure Boot key enrolment was lost
([page 10](10-secure-boot-mok.md)); booting the previous kernel brings the
limit back meanwhile.

## Undo

```sh
echo 100 | sudo tee /sys/class/power_supply/BAT1/charge_control_end_threshold
sudo systemctl disable --now battery-charge-limit.service
cd ~/msi-ec && sudo make dkms-uninstall
```
