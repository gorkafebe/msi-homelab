# garmin-fetch: the garmin-grafana fetcher, built from a PINNED upstream commit.
#
# Upstream: https://github.com/arpanghosh8453/garmin-grafana (BSD-3-Clause)
# Commit:   2e9ecadbb59cd1ee6706d7010710ed3a5ceb27f6 (2026-11-25)
#
# Same two-stage layout as the upstream Dockerfile at that commit, with:
#   - base images pinned by digest (upstream uses tags only);
#   - the source fetched by git at the exact commit (BuildKit checks it);
#   - Python dependencies installed with `uv sync --locked` from upstream's
#     uv.lock, which records a sha256 for every package, so a tampered or
#     changed package fails the build;
#   - our wrapper as the entry point (no credentials, no login loops).
# The base image tags/digests and the commit are listed in
# THIRD_PARTY_NOTICES.md.

ARG UPSTREAM_COMMIT=2e9ecadbb59cd1ee6706d7010710ed3a5ceb27f6

FROM ghcr.io/astral-sh/uv:0.6.17-python3.13-bookworm-slim@sha256:9aa0722a3433b037ba515599abb92f981878f21ee046bd852f3d2d4508269dba AS build
ARG UPSTREAM_COMMIT
ENV PYTHONDONTWRITEBYTECODE=1 \
    UV_LINK_MODE=copy
WORKDIR /app
ADD https://github.com/arpanghosh8453/garmin-grafana.git#${UPSTREAM_COMMIT} /upstream
RUN cp /upstream/pyproject.toml /upstream/uv.lock ./ \
 && uv sync --locked --no-dev --no-install-project

FROM python:3.13.18-slim-bookworm@sha256:f0fa218d5b06f9b9235024fa061cde2cb141f726de52134471053d2d9b5324a3 AS runtime
ARG UPSTREAM_COMMIT
LABEL org.opencontainers.image.source="https://github.com/arpanghosh8453/garmin-grafana" \
      org.opencontainers.image.revision="${UPSTREAM_COMMIT}" \
      org.opencontainers.image.licenses="BSD-3-Clause"
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH"
WORKDIR /app
RUN groupadd --gid 1000 appuser \
 && useradd --uid 1000 --gid appuser --shell /usr/sbin/nologin --create-home appuser \
 && install -d -m 700 -o appuser -g appuser /home/appuser/.garminconnect
COPY --chown=appuser:appuser --from=build /app/.venv /app/.venv
COPY --chown=appuser:appuser --from=build /upstream/src /app/
COPY --chmod=755 wrapper.sh /usr/local/bin/garmin-fetch-wrapper
USER appuser
ENTRYPOINT ["/bin/sh", "/usr/local/bin/garmin-fetch-wrapper"]
