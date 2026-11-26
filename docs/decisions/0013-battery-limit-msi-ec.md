# 0013 — Battery limit 60 % with msi-ec, Secure Boot kept

**Status:** in force; supersedes D-34 ("do not touch the charge thresholds").
**Source:** D-37.

**Context.** Always on mains, the battery sat at 95–100 % and warm. MSI's
charge limit is set from Windows tools, which were gone; Ubuntu's own `msi_ec`
refused this laptop's EC firmware.

**Decision.** Install the newer external driver
([BeardOverflow/msi-ec](https://github.com/BeardOverflow/msi-ec)) with DKMS,
keep Secure Boot by enrolling a Machine Owner Key, set end 60 % / start 50 %,
and re-apply it at boot with a oneshot unit.

**Alternatives.** Do nothing (faster wear); disable Secure Boot (loses boot
integrity); remove the battery (loses the bridge over short power cuts).

**Consequences.** An out-of-tree module that must rebuild on every kernel
update ([runbook 09](../runbook/09-battery-limit.md)). Not verified after a
cold boot.
