# 03 — Network: cable plus Wi-Fi with netplan

**Status:** verified (2026-11-02).

## Goal

The cable is the server's main connection; Wi-Fi is a convenience and a
fallback ([decision 0004](../decisions/0004-wifi-own-netplan-file.md)).

## Requirements

The cable connected and working (installer default, DHCP).

## Steps

1. **With the cable**, install the Wi-Fi authentication program. Ubuntu Server
   may not include it, and without it Wi-Fi cannot connect — nor can you
   download it over Wi-Fi:

   ```sh
   sudo apt install -y wpasupplicant
   ```

2. Leave the installer's `/etc/netplan/50-cloud-init.yaml` (the cable) as it
   is. Netplan merges every file in `/etc/netplan/`, so Wi-Fi goes in its own
   file: copy [host/netplan/60-wifi.yaml](../../host/netplan/60-wifi.yaml) to
   `/etc/netplan/60-wifi.yaml` and replace the placeholders.

3. Only root may read it — it contains the Wi-Fi password:

   ```sh
   sudo chmod 600 /etc/netplan/60-wifi.yaml
   ```

4. Apply it **with a safety net**: `netplan try` reverts by itself after 120
   seconds unless you press Enter, so a mistake cannot lock you out:

   ```sh
   sudo netplan try
   ```

## Verify

```sh
ip -br addr        # both interfaces UP with an address
ip route           # two default routes: the cable with the LOWER metric (100) wins over Wi-Fi (600)
systemctl status netplan-wpa-<wifi-interface>     # active (running)
```

With netplan the Wi-Fi service is `netplan-wpa-<interface>`, not
`wpa_supplicant@<interface>`.

## If Wi-Fi does not connect

- `NO-CARRIER` and the service failing with `status=203/EXEC`: the program does
  not exist — `wpasupplicant` is missing (step 1), then `sudo netplan apply`
  ([lessons](../lessons.md#wi-fi-never-connected-wpasupplicant-was-missing)).
- 5 GHz networks not seen: add `regulatory-domain: <CC>` (your country code)
  under the interface.

## Addresses can change

Both addresses come from the router's DHCP. Either reserve one per interface in
the router (by MAC address — MAC addresses are never written in a repository,
[decision 0007](../decisions/0007-no-mac-addresses-in-repos.md)) or reach the
server by name through Tailscale ([page 12](12-tailscale.md)).

## Undo

```sh
sudo rm /etc/netplan/60-wifi.yaml && sudo netplan apply
```
