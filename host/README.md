# host/ — configuration templates for the server itself

Sanitized templates of the files changed on the host during the setup in
[docs/runbook/](../docs/runbook/). They contain **placeholders, never real
values**: replace every `<...>` on the machine, never in this repository.

| Template | Goes to (on the server) | Mode | Runbook page |
|---|---|---|---|
| [netplan/60-wifi.yaml](netplan/60-wifi.yaml) | `/etc/netplan/60-wifi.yaml` | `600` (holds the Wi-Fi password) | [03](../docs/runbook/03-network-wifi.md) |
| [ssh/99-hardening.conf](ssh/99-hardening.conf) | `/etc/ssh/sshd_config.d/99-hardening.conf` | `644` | [04](../docs/runbook/04-ssh.md) |
| [logind/50-server-lid.conf](logind/50-server-lid.conf) | `/etc/systemd/logind.conf.d/50-server-lid.conf` | `644` | [05](../docs/runbook/05-headless.md) |
| [grub/consoleblank.txt](grub/consoleblank.txt) | one value added to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub` | — | [05](../docs/runbook/05-headless.md) |
| [docker/docker.sources](docker/docker.sources) | `/etc/apt/sources.list.d/docker.sources` | `644` | [07](../docs/runbook/07-docker.md) |
| [docker/daemon.json](docker/daemon.json) | `/etc/docker/daemon.json` | `644` | [07](../docs/runbook/07-docker.md) |
| [systemd/battery-charge-limit.service](systemd/battery-charge-limit.service) | `/etc/systemd/system/battery-charge-limit.service` | `644` | [09](../docs/runbook/09-battery-limit.md) |

Copy them with an editor (`sudo nano <destination>`), not by pasting long
shell here-documents: a here-document that is not closed correctly runs the
rest of the text as commands ([lessons](../docs/lessons.md#a-here-document-ran-documentation-as-commands)).
