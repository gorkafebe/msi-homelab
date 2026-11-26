# msi-homelab — everyday commands.
#
# Every target that starts containers needs an EXPLICIT Compose project name:
#
#     make demo COMPOSE_PROJECT_NAME=homelab-dev
#
# Why: Compose derives the project name from the folder or from .env when none
# is given, and two stacks with the same name silently share (and recreate)
# each other's containers. The names of real deployments on the machine are
# refused here on purpose; production is started by hand, with the commands in
# docs/runbook/13-monitoring.md.

SHELL := /bin/sh
.DEFAULT_GOAL := help

# Real deployments that `make` must never touch:
#  - msi-monitor, the production name of the monitoring stack;
#  - any name listed in scripts/forbidden-projects.local (ignored by git, one
#    per line), for other services on your machine;
#  - any EXISTING Compose project whose files live outside this repository
#    (checked with `docker compose ls`), so an unknown real stack is safe too.
FORBIDDEN_PROJECTS := msi-monitor $(shell grep -v '^\#' scripts/forbidden-projects.local 2>/dev/null)

# Pinned tool images (see THIRD_PARTY_NOTICES.md).
SHELLCHECK_IMAGE := koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d
YAMLLINT_IMAGE := pipelinecomponents/yamllint:0.35.27@sha256:f7f7b4f8824839e33690a880dbe20944128b0dc9c55522a0b92a29b3a905cecf

.PHONY: help guard env lint audit config test garmin-build garmin-test demo demo-down

# Compose files. Paths inside them are relative to stacks/monitoring/.
MONITORING := -f stacks/monitoring/compose.yaml
GARMIN := -f stacks/garmin/compose.garmin.yaml
DEMO := -f stacks/garmin/demo/compose.demo.yaml
# Environment file for the demo (default: .env made by scripts/init-env.sh).
ENV_FILE ?= .env
PYTHON_IMAGE := python:3.14.2-alpine3.23@sha256:31da4cb527055e4e3d7e9e006dffe9329f84ebea79eaca0a1f1c27ce61e40ca5
# Validation only ever uses the template, never a real .env.
CHECK := docker compose -p homelab-check --env-file .env.example

help: ## Show this list
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

guard: ## Refuse to run without a safe, explicit COMPOSE_PROJECT_NAME
	@test -n "$(COMPOSE_PROJECT_NAME)" || { \
	  echo "COMPOSE_PROJECT_NAME is not set. Example: make demo COMPOSE_PROJECT_NAME=homelab-dev" >&2; exit 1; }
	@case "$(COMPOSE_PROJECT_NAME)" in \
	  *[!a-z0-9_-]*|[!a-z0-9]*) echo "invalid project name: $(COMPOSE_PROJECT_NAME)" >&2; exit 1 ;; esac
	@for p in $(FORBIDDEN_PROJECTS); do \
	  if [ "$(COMPOSE_PROJECT_NAME)" = "$$p" ]; then \
	    echo "refusing project '$$p': it is a real deployment, not a development stack" >&2; exit 1; fi; done
	@if command -v docker >/dev/null 2>&1; then \
	  files=$$(docker compose ls -a --format json 2>/dev/null \
	    | jq -r --arg n "$(COMPOSE_PROJECT_NAME)" '.[] | select(.Name == $$n) | .ConfigFiles'); \
	  case "$$files" in \
	    '') ;; \
	    *"$(CURDIR)/"*) ;; \
	    *) echo "refusing project '$(COMPOSE_PROJECT_NAME)': it already exists with files outside this repository" >&2; exit 1 ;; \
	  esac; fi

env: ## Create or complete .env with random passwords (prints no values)
	@scripts/init-env.sh

lint: ## ShellCheck, yamllint and JSON syntax (pinned images, no network)
	@docker run --rm --network none -v "$(CURDIR):/src:ro" -w /src $(SHELLCHECK_IMAGE) \
	  $$(git ls-files '*.sh' 'stacks/*/bin/*')
	@docker run --rm --network none -v "$(CURDIR):/src:ro" -w /src $(YAMLLINT_IMAGE) \
	  yamllint -c .yamllint.yml .
	@git ls-files '*.json' | while read -r f; do jq empty "$$f" || exit 1; done
	@python3 -I scripts/check-links.py
	@echo "lint ok"

config: ## Validate the Compose files with .env.example (starts nothing)
	@for profiles in "" pvpc apphealth pvpc,apphealth; do \
	  COMPOSE_PROFILES=$$profiles $(CHECK) $(MONITORING) config -q || exit 1; \
	  echo "monitoring ok (profiles: $${profiles:-none})"; done
	@$(CHECK) $(MONITORING) $(GARMIN) config -q && echo "monitoring + garmin ok"
	@$(CHECK) $(DEMO) config -q && echo "demo ok"
	@python3 -I scripts/vendor-dashboard.py --check

test: ## Offline unit tests (price fetcher), no network
	@docker run --rm --network none --read-only --tmpfs /tmp -e PYTHONDONTWRITEBYTECODE=1 \
	  -v "$(CURDIR)/stacks/monitoring/price-fetch:/app:ro" -w /app $(PYTHON_IMAGE) \
	  python3 -m unittest -q test_fetch_price

garmin-build: ## Build the fetcher and one-shot login images (pinned sources)
	@docker build -q -t msi-homelab/garmin-fetch:2e9ecadb stacks/garmin/fetcher
	@docker build -q -t msi-homelab/garmin-login:0.3.20 stacks/garmin/login

garmin-test: garmin-build ## Offline tests of the login script and the fetcher wrapper (no network)
	@docker run --rm --network none --read-only --tmpfs /tmp \
	  -v "$(CURDIR)/stacks/garmin/tests:/app/tests:ro" --entrypoint python \
	  msi-homelab/garmin-login:0.3.20 -I /app/tests/test_login.py
	@stacks/garmin/tests/test-fetcher-wrapper.sh

demo: guard ## Demo with invented data: Grafana on http://127.0.0.1:13300 (needs .env)
	@test -f "$(ENV_FILE)" || { echo "run scripts/init-env.sh first" >&2; exit 1; }
	@docker compose -p $(COMPOSE_PROJECT_NAME) --env-file "$(ENV_FILE)" $(DEMO) up -d --wait influxdb-demo grafana-demo
	@docker compose -p $(COMPOSE_PROJECT_NAME) --env-file "$(ENV_FILE)" $(DEMO) --profile seed run --rm seed-demo
	@echo "Demo ready: http://127.0.0.1:13300  (folders 'Garmin' and 'Server (MSI)')"

demo-down: guard ## Stop the demo (its data lives in RAM and is gone)
	@docker compose -p $(COMPOSE_PROJECT_NAME) --env-file "$(ENV_FILE)" $(DEMO) --profile seed down

audit: ## Pre-publication audit of the tree and the whole history
	@scripts/audit-public.sh --all
