# Third-party notices

The original code and documentation in this repository are under the MIT
license ([LICENSE](LICENSE)). This file lists the third-party material that is
**copied into** the repository, the third-party software that is **downloaded
when you build or run** it, and exactly which version is used.

Everything is pinned: container images by tag **and** digest, source code by
commit. Nothing uses `latest`.

## Copied into this repository

_None yet._

## Container images used (downloaded by Docker, not redistributed)

| Image | Pinned to | Used by | License (upstream) |
|---|---|---|---|
| `zricethezav/gitleaks` | `v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f` | `scripts/audit-public.sh`, CI | MIT |
| `koalaman/shellcheck` | `v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d` | `make lint`, CI | GPL-3.0 (tool only, not linked) |
| `pipelinecomponents/yamllint` | `0.35.27@sha256:f7f7b4f8824839e33690a880dbe20944128b0dc9c55522a0b92a29b3a905cecf` | `make lint`, CI | GPL-3.0 (yamllint; tool only) |

## GitHub Actions

| Action | Pinned to | Tag at the time |
|---|---|---|
| `actions/checkout` | `3d3c42e5aac5ba805825da76410c181273ba90b1` | v7.0.1 |
