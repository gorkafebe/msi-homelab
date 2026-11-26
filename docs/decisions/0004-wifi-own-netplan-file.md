# 0004 — Wi-Fi in its own netplan file; the cable is primary

**Status:** in force. **Source:** D-24.

**Context.** The installer configured the cable. Wi-Fi was wanted as a
fallback and for administration.

**Decision.** Put Wi-Fi in `/etc/netplan/60-wifi.yaml` (mode 600), leave the
installer's file untouched, let the route metrics prefer the cable, apply with
`netplan try`.

**Alternatives.** Edit the installer's file (mixes the password into a file
cloud-init may rewrite); NetworkManager (heavier, desktop-oriented).

**Consequences.** The password is in one root-only file; undo is deleting it.
The server can silently fall back to Wi-Fi if the cable drops — the panel shows
the active uplink ([lessons](../lessons.md#the-cable-was-down-and-nobody-noticed)).
