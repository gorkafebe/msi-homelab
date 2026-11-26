# 02 — Disk: the 98 GB LVM root and how to give it the whole disk

**Status:** verified (2026-11-02).

## Goal

The root filesystem must use the whole SSD. Ubuntu's guided storage layout
with LVM (ticked by default) creates a root logical volume of about 100 GB and
leaves the rest of the disk **unallocated**; Docker images and data then fill
it long before the disk is full.

## Requirements

Only needed if the LVM box stayed ticked in the installer
([page 01](01-install.md)). It works with the system running.

## Steps

1. Look at the layout. `VFree` is unallocated space in the volume group:

   ```sh
   df -h /            # symptom: about 98G
   lsblk
   sudo vgs
   sudo lvs
   ```

2. Extend the logical volume into all the free space and grow the ext4
   filesystem in the same command (`-r`, resize):

   ```sh
   sudo lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
   ```

*Why it is safe online:* growing ext4 is supported while mounted; shrinking is
not (and is never needed here).

**Next time:** either untick LVM in the installer, or keep LVM (it allows
snapshots and adding a second disk later) and run step 2 right after the first
boot ([decision 0003](../decisions/0003-keep-lvm-and-extend.md)).

## Verify

```text
$ df -h /
/dev/mapper/ubuntu--vg-ubuntu--lv  466G  ...  /
$ sudo lvs
ubuntu-lv ubuntu-vg -wi-ao---- <473.89g
```

The volume is 473.9 GiB but `df` shows 466G: ext4 keeps the difference for its
own bookkeeping. On a 512 GB disk about 430 GB remain usable after the system.

## Undo

Not needed and not recommended (shrinking ext4 requires unmounting it).
