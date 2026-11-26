# 0015 — Power saving by measured steps; no proprietary NVIDIA driver; GPU left as is

**Status:** in force; the power-saving steps are planned. **Source:** D-41, D-76.

**Context.** A gaming laptop running 24/7 wastes power on parts a server does
not need. Measuring showed the NVIDIA GPU already powered off (D3cold) 99.97 %
of the time with `nouveau`.

**Decision.** Change nothing on the GPU; watch it on the panel; avoid commands
that wake it. Save power only in measured steps (measure, change one thing,
measure again). Do not install the proprietary NVIDIA driver.

**Alternatives.** Blacklist nouveau (may leave the GPU powered); the
proprietary driver with dynamic power management (aims at D3cold, which is
already reached).

**Consequences.** No CUDA on this machine. Reopening this is the owner's
decision, weighed in [ROADMAP_LOCAL_LLM.md](../ROADMAP_LOCAL_LLM.md).
