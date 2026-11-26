# 07 — Docker Engine and Compose from Docker's repository

**Status:** verified (2026-11-02: Engine 29.9.2, Compose v5.6.1, log rotation
in place; on 2026-11-26 the machine runs Engine 29.10.0 and Compose v5.8.0).

## Goal

Current Docker Engine and Compose plugin from Docker's own apt repository
([decision 0008](../decisions/0008-docker-from-official-repo.md)), with logs
that cannot fill the disk.

## Steps

Source: <https://docs.docker.com/engine/install/ubuntu/> (check it if a step fails).
Not the `docker.io` package or the snap: they lag behind and conflict.

1. Remove conflicting packages (apt saying none are installed is normal):

   ```sh
   sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)
   ```

2. Docker's signing key and repository:

   ```sh
   sudo apt update && sudo apt install -y ca-certificates curl
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc
   sudo nano /etc/apt/sources.list.d/docker.sources     # contents: host/docker/docker.sources
   sudo apt update
   ```

   The template is [host/docker/docker.sources](../../host/docker/docker.sources);
   write it with an editor rather than a here-document.

3. Install:

   ```sh
   sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin git make
   ```

4. Use Docker without `sudo`, then **log out and in again** (the group applies
   to new sessions only — [lessons](../lessons.md#permission-denied-on-the-docker-socket-after-joining-the-group)):

   ```sh
   sudo usermod -aG docker $USER
   ```

   **The `docker` group is equivalent to root.** Anyone who can talk to the
   Docker daemon can start a container that mounts `/` and edit any file as
   root. Add only your own administrator account to it, never a service or
   another person's account.

5. Rotate the logs of every container: copy
   [host/docker/daemon.json](../../host/docker/daemon.json) to
   `/etc/docker/daemon.json` (at most 5 files of 10 MB per container) and
   `sudo systemctl restart docker`. It applies to containers created after the
   change; running containers restart.

## Verify

```sh
docker version --format '{{.Server.Version}}'; docker compose version
cat /etc/docker/daemon.json
docker info --format '{{.LoggingDriver}}'        # json-file
id -nG | tr ' ' '\n' | grep -x docker            # your user is in the group
```

## Undo

```sh
sudo apt purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm /etc/apt/sources.list.d/docker.sources /etc/apt/keyrings/docker.asc /etc/docker/daemon.json
```

`/var/lib/docker` (images, volumes = data) stays until removed by hand.
