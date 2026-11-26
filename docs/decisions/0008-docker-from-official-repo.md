# 0008 — Docker from Docker's apt repository

**Status:** in force. **Source:** D-08.

**Context.** Ubuntu offers `docker.io` and a snap; Docker publishes its own
packages.

**Decision.** Docker Engine and the Compose plugin from
`download.docker.com`, following Docker's instructions, with global log rotation.

**Alternatives.** `docker.io` (older Compose), snap (confinement surprises with
bind mounts), Podman (different behaviour from the development machine).

**Consequences.** Current Compose features (profiles, `--wait`); updates arrive
with the system's apt updates. The `docker` group is root-equivalent.
