# 0016 — Panel only inside Tailscale (`serve`, never `funnel`), HTTP on 3000

**Status:** in force. **Source:** D-70 (its HTTPS part superseded), D-81.

**Context.** The panel must be readable from a phone or laptop anywhere, not
from the LAN or the internet.

**Decision.** `tailscale serve` publishes `127.0.0.1:3000` on the tailnet
only, over plain HTTP inside WireGuard. `tailscale funnel` is never used.

**Alternatives.** HTTPS with Tailscale certificates (publishes the full
`*.ts.net` name in Certificate Transparency logs); a reverse proxy on the LAN
(more exposure); SSH tunnels only (fine, but awkward on a phone).

**Consequences.** Browsers show "Not secure" and Grafana's cookie is not
`Secure`; the encryption is WireGuard's. Grafana keeps its login
([0017](0017-grafana-login-alerts-design-only.md)).
