# 08 — Firewall and the Docker/ufw problem

**Status:** procedure. This page describes the correct setup and how to check
it; it does not report the state of any particular machine.

## Goal

Only what must be reachable from the network is reachable, and private
services (databases, Prometheus, Grafana, InfluxDB) answer on `127.0.0.1` only.

## The problem: published Docker ports bypass ufw

When Compose publishes a port (`ports: "5432:5432"`), Docker writes its own
iptables rules, which are evaluated **before** ufw's. `sudo ufw deny 5432` then
does **not** block it: the port stays open to the network.

The real protection is **not publishing** what must stay private
([decision 0010](../decisions/0010-host-network-loopback.md)):

- publish on loopback only: `ports: ["127.0.0.1:3000:3000"]`; or
- use `network_mode: host` and make the program itself listen on `127.0.0.1`
  (what this repository does: every service has a listen-address flag or
  variable set to `127.0.0.1`, and there is no `ports:` at all);
- services that only talk to each other stay on Docker's internal networks.

## Steps (ufw for everything outside Docker)

Allow SSH **first**, or enabling the firewall cuts your session:

```sh
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw status verbose          # default incoming: deny; OpenSSH allowed
```

## Verify

```sh
# Every private listener must start with 127.0.0.1 (or ::1):
ss -tlnp | grep -E ':(3000|8086|8088|9090|9100|9101|9115)\b'
# What is reachable from outside at all:
ss -tlnp | grep -v -E '127\.0\.0\.|\[::1\]'
sudo ufw status verbose
```

Also test from **another network** (for example a phone on mobile data, Wi-Fi
off) that nothing you did not mean to publish answers — including over IPv6,
if your connection has it ([page 16](16-reboot-tests.md), test 4).

## Undo

```sh
sudo ufw disable
```
