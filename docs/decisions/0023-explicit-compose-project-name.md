# 0023 — The Compose project name is never implicit

**Status:** in force. **Source:** D-94.

**Context.** Compose takes the project name from the folder or `.env` when none
is given; two stacks with the same name silently share and recreate each
other's containers and volumes.

**Decision.** `make` refuses to run without `COMPOSE_PROJECT_NAME` on the
command line, refuses the production monitoring name and names listed in an
ignored local file, and refuses any existing project whose files live outside
this repository. Production commands always pass `-p` explicitly.

**Consequences.** Tests use `homelab-dev`; a typo cannot touch a real deployment.
