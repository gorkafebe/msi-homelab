# 12 — Tailscale: private access to the panel

**Status:** procedure (Tailscale and `tailscale serve` have been in use since
2026-11-03/05; this page does not describe the tailnet itself).

## Goal

Open Grafana from your own laptop or phone, from any network, without
exposing it to the LAN or the internet
([decision 0016](../decisions/0016-panel-only-inside-tailscale.md)).

## How it works

```
your device (Tailscale on) --WireGuard, encrypted--> tailscaled on the server --HTTP--> Grafana on 127.0.0.1:3000
```

`tailscale serve` makes `tailscaled` listen on the server's **Tailscale
addresses only** and pass requests to `127.0.0.1:3000`. Grafana itself keeps
listening on loopback and keeps its login. Plain HTTP is acceptable here: the
traffic between devices already travels inside WireGuard. HTTPS would need
Tailscale certificates, which publish the machine's full `*.ts.net` name in
the public Certificate Transparency logs.

## Steps

1. Install Tailscale from its official instructions
   (<https://tailscale.com/download/linux>) and `sudo tailscale up`.
2. Publish Grafana inside the tailnet only:

   ```sh
   sudo tailscale serve --bg --http=3000 http://127.0.0.1:3000
   ```

3. **Never** use `tailscale funnel` for the panel: funnel publishes on the
   public internet.
4. In the Tailscale admin console, review the access rules (ACLs) and the
   device's key expiry; restrict port 3000 to your own devices if anyone else
   joins the tailnet.

## Verify

```sh
tailscale serve status            # ".../ (tailnet only)" -> proxy http://127.0.0.1:3000
tailscale funnel status           # nothing published
ss -tlnp | grep ':3000 '          # 127.0.0.1:3000 (Grafana) + the Tailscale addresses (tailscaled)
curl -s http://127.0.0.1:3000/api/health
```

From a device in the tailnet: `http://<hostname>:3000`. Prometheus (9090) and
the exporters have no login and are **not** published.

Without Tailscale, an SSH tunnel also works:
`ssh -L 3000:localhost:3000 <user>@<server-ip>`, then <http://localhost:3000>.

## Undo

```sh
sudo tailscale serve reset        # removes ALL serve configuration of this machine
```
