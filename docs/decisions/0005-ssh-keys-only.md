# 0005 — SSH with keys only, no root login

**Status:** in force. **Source:** D-25.

**Context.** SSH is the only way in. Password logins can be guessed.

**Decision.** `PasswordAuthentication no`, `PermitRootLogin no` in a drop-in
file, enabled only after a key login was tested from another machine.

**Alternatives.** Passwords plus fail2ban (still guessable, more software);
SSH only through Tailscale SSH (ties the only way in to one service).

**Consequences.** Losing the laptop's key means walking to the server's
keyboard; keep a protected copy of the key or a second authorised key.
