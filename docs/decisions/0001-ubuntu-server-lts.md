# 0001 — Ubuntu Server 24.04 LTS on the laptop; stay on 24.04 for now

**Status:** executed 2026-11-02; "stay on 24.04" under review. **Source:** D-06, D-21.

**Context.** A spare gaming laptop had to become an always-on server for the
hosted web app, whose audio files needed a large local disk. It came with Windows.

**Decision.** Erase Windows and install Ubuntu Server 24.04.5 LTS, headless.
Do not upgrade to 26.04 when the installer offers it; revisit deliberately,
together with the development laptop.

**Alternatives.** Keep Windows with WSL or Docker Desktop (heavier, worse for a
headless server); a desktop Ubuntu (graphical session for nothing); 26.04 at once
(new base on one machine only).

**Consequences.** Five years of updates; the same base as the development
machine; no Windows tools (the battery limit had to come from a Linux driver,
[0013](0013-battery-limit-msi-ec.md)).
