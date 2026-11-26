# 01 — Installer USB, boot menu and installer choices

**Status:** done but not verified (done on 2026-11-02; the only check is that
the system works). Erases the factory Windows.

## Goal

Install Ubuntu Server from a USB stick using the laptop's own screen and
keyboard. After this page everything happens over SSH.

## Requirements

- A USB stick of 8 GB or more (it will be erased) and another computer.
- The laptop on mains power, with the network cable connected.

## Steps

1. **On the other computer**, download the Ubuntu Server 24.04.x LTS ISO and
   the `SHA256SUMS` file from the same release page
   (<https://ubuntu.com/download/server>). Check the download — a corrupt ISO
   gives strange installer errors:

   ```sh
   sha256sum -c SHA256SUMS --ignore-missing      # the ISO's line must end in OK
   ```

2. Write the ISO to the stick with a startup-disk tool, or with `dd` after
   finding the stick's device name with `lsblk` (the whole device, e.g.
   `/dev/sdX`, never a partition; a wrong name overwrites another disk):

   ```sh
   sudo dd if=ubuntu-24.04.5-live-server-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```

3. Power the laptop **off completely**, plug in the stick, power on and tap
   **F11** for the one-time boot menu (Del opens the BIOS; these keys come from
   general MSI information, not from a page for this exact model). Choose the
   entry that starts with **UEFI**. If it does not boot, disable *Fast Boot*
   in the BIOS; Secure Boot can stay on.

4. Installer choices, in order:

   | Screen | Choice | Why |
   |---|---|---|
   | Language | English | error messages are easier to search |
   | Keyboard | your physical layout | |
   | Type of install | Ubuntu Server (not "minimized") | keeps the usual admin tools |
   | Network | the cable, DHCP; leave Wi-Fi for later | the cable needs no extra packages |
   | Storage | whole disk, **untick "Set up this disk as an LVM group"**, no encryption | see [page 02](02-disk-lvm.md) |
   | Profile | server name `<hostname>`, user `<user>`, a strong password | never write the password in a file |
   | SSH | **Install OpenSSH server** | the only way in afterwards |
   | Featured snaps | none | Docker comes from Docker's repository ([page 07](07-docker.md)) |

5. Remove the stick when asked, reboot, log in at the keyboard and update:

   ```sh
   sudo apt update && sudo apt full-upgrade -y && sudo reboot
   ```

## Verify

```sh
cat /etc/os-release | grep PRETTY_NAME      # Ubuntu 24.04.x LTS
systemctl is-active ssh                      # active
ip -br addr                                  # the cable has an address
```

From the other computer: `ssh <user>@<server-ip>` asks to accept the host key
(compare its fingerprint with `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`
on the server; fingerprints are not written in these docs).

## Undo

Reinstalling is the only undo. Windows can only come back from MSI's recovery
media.
