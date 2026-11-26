# 10 — Secure Boot and the Machine Owner Key

**Status:** verified (2026-11-02 and 2026-11-03: `SecureBoot enabled`, the
DKMS module signed and loaded).

## Goal

Keep Secure Boot **on** and still load the out-of-tree `msi-ec` module.

## Why

With Secure Boot the firmware starts only a signed boot loader and kernel, and
the kernel loads only signed modules. A module built on the machine by DKMS is
not signed by Ubuntu, so DKMS signs it with a key of its own — the **MOK**
(Machine Owner Key) — and the firmware must be told once to trust that key.
Turning Secure Boot off would also work, but removes a protection against
tampered boot code for the rest of the machine's life.

## Steps

1. The first `sudo make dkms-install` ([page 09](09-battery-limit.md)) creates
   the key and asks for a **one-time password**. Use letters and digits only:
   the enrolment screen may use a US keyboard layout.
2. Reboot. Before Ubuntu starts, a blue **MOK management** screen appears
   **once**: *Enroll MOK* → *Continue* → *Yes* → the one-time password →
   *Reboot*.
3. The password is used once and is **never written down anywhere**.

To repeat the enrolment (after a reinstall, a firmware key reset, or if the
blue screen was missed):

```sh
sudo mokutil --import /var/lib/shim-signed/mok/MOK.der     # asks for a new one-time password
sudo reboot                                                # enrol on the blue screen
```

Kernel updates reuse the same key: nothing to do.

## Verify

```sh
mokutil --sb-state                 # SecureBoot enabled
modinfo -F signer msi_ec           # "<hostname> Secure Boot Module Signature key"
lsmod | grep msi_ec
```

## Undo

```sh
sudo mokutil --delete /var/lib/shim-signed/mok/MOK.der     # then confirm on the blue screen
```

After that the module no longer loads while Secure Boot is on.
