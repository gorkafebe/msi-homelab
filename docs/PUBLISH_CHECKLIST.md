# Publish checklist

Before making the repository public (or after any change that adds files,
screenshots or history). Every item must pass.

## 1. The local denylist

`scripts/audit-public.sh` fails on the exact values that identify your machine
and network. They live in `scripts/audit-denylist.local`, which is ignored by
git and must never be committed. On a new machine, create it by hand:

```sh
umask 077
nano scripts/audit-denylist.local
```

One value per line (matched as a whole word, case-insensitive; `#` starts a
comment). Include at least:

- the server's host name and your user name;
- the LAN addresses of the server (both interfaces);
- the server's Tailscale IPv4 and IPv6 addresses (`tailscale ip`) and your
  tailnet's name (the part before `.ts.net`);
- the MAC addresses of the network interfaces (`cat /sys/class/net/*/address`);
- your Wi-Fi network name (SSID);
- your personal e-mail addresses;
- any other identifier you used in notes (laptop names, key comments, the
  laptop's exact model/SKU code if you consider it identifying).

Check it is ignored: `git check-ignore -v scripts/audit-denylist.local`.

## 2. The audit

```sh
scripts/audit-public.sh --all        # tree + every commit, author and message
```

It prints `file:line` and the kind of finding, never the value. `AUDIT OK` is
required. It also runs automatically before each commit made with the
project's helper and in CI (without the private denylist).

## 3. Identity and history

```sh
git log --format='%h %an %ae' | awk '{print $NF}' | sort -u    # only *@users.noreply.github.com and noreply@anthropic.com
git remote -v                                                   # nothing until you add it on purpose
```

## 4. Screenshots — look at every image

For each file in `docs/images/`: no host names, addresses, Wi-Fi or tailnet
names, user names, browser tabs or URLs of the machine; no real health data
(Garmin screenshots must come from `make demo`); no empty panels or absurd
scales presented as normal. The audit cannot read pixels.

## 5. Runbook and docs, line by line

Read every page under `docs/` looking for: real addresses or names instead of
`<placeholders>`; statements about the **current** security state of your
machine (what is open, what is not verified) — those belong in private notes,
not here; anything about the hosted web app beyond the short mention in the
README.

## 6. Mechanical checks

```sh
make lint config test garmin-test
python3 scripts/vendor-dashboard.py --check
```

## 7. Publish privately first

Create the GitHub repository as **private**, push, read it on GitHub
(including the commit list), and only then switch it to public.
