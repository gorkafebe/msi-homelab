# 0021 — The power total is a model, not a measurement

**Status:** in force. **Source:** D-79.

**Context.** The charger reports only "plugged / unplugged". RAPL measures the
CPU package; `psys` turned out not to be the whole laptop here.

**Decision.** The panel's total is **CPU package (RAPL) + 4.6 W**, the rest of
the laptop measured once by running on battery (2026-11-05: 7.91 W total vs
3.31 W package, at idle). It is labelled "(model)" everywhere. A real total
needs a plug meter.

**Consequences.** Honest numbers; recalibrate the constant (a dashboard
variable) after any hardware or setting change.
