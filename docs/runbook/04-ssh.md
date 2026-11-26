# 04 — SSH with keys only

**Status:** verified (2026-11-02, all five steps).

## Goal

Nobody can log in by guessing a password: only holders of an authorised key
get in, and never as root ([decision 0005](../decisions/0005-ssh-keys-only.md)).

## Requirements

A second computer (called "the laptop" here) on the same network or tailnet.

## Steps — in this order, so you cannot lock yourself out

1. **On the laptop**, use the existing ed25519 key or create one. Look first:
   `ssh-keygen` overwrites an existing key if you say yes
   ([lessons](../lessons.md#ssh-keygen-replaced-an-existing-key)).

   ```sh
   ls -la ~/.ssh
   ssh-keygen -t ed25519 -C "<laptop-name>"      # only if there is no key yet
   ssh-copy-id <user>@<server-ip>
   ```

2. **On the laptop**, check the login works **without** the account password:
   `ssh <user>@<server-ip>`.

3. **Only then, on the server**, create
   `/etc/ssh/sshd_config.d/99-hardening.conf` from
   [host/ssh/99-hardening.conf](../../host/ssh/99-hardening.conf).

4. Check the syntax and restart (if `sshd -t` prints anything, nothing restarts):

   ```sh
   sudo sshd -t && sudo systemctl restart ssh
   ```

5. **Keep the current session open.** From a **new terminal on the laptop**:

   ```sh
   ssh <user>@<server-ip>                               # must work
   ssh -o PubkeyAuthentication=no <user>@<server-ip>    # must fail: Permission denied (publickey).
   ```

Run these tests from the laptop, never on the server itself: there the server's
own name points to the server, so the "test" connects to itself and proves
nothing ([lessons](../lessons.md#an-ssh-test-run-on-the-server-itself-proved-nothing)).

## Verify

```sh
sudo sshd -T | grep -E '^(passwordauthentication|permitrootlogin)'   # no / no
```

## If the laptop's key is lost

The restriction applies to SSH only: log in at the server's own keyboard with
the account password and add a new public key to `~/.ssh/authorized_keys`.
Keep a backup of the private key (passphrase-protected) outside the laptop, or
authorise a second key kept elsewhere.

## Undo

```sh
sudo rm /etc/ssh/sshd_config.d/99-hardening.conf && sudo systemctl restart ssh
```
