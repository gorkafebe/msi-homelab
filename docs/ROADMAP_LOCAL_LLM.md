# Roadmap: a local language model over the Garmin data

**Status: planned — design only.** Nothing here is installed. Figures marked
*estimate* were not measured on this machine.

## Goal

Ask questions about your own health and training data ("how did my sleep
change in the weeks I ran more?", "draft a two-week easy plan") with a model
that runs **on the server**, never sends the data anywhere, and cannot change it.

## The hardware (verified)

- GPU: NVIDIA GeForce RTX 3060 Mobile / Max-Q (GA106M, `10de:2520`), **6 GiB**
  VRAM, currently driven by `nouveau` and powered off 99.97 % of the time
  ([runbook 11](runbook/11-gpu-power.md)).
- CPU: Intel Core i7-12700H (14 cores / 20 threads); RAM: 16 GB (15 GiB usable).

## What fits (estimate)

Published download sizes of common 4-bit quantised models (ollama.com library
pages, read 2026-11-26): `llama3.2:3b` 2.0 GB, `qwen2.5:7b` 4.7 GB,
`llama3.1:8b` 4.9 GB. In 6 GiB of VRAM a 7–8 B model fits with a short context
(a few thousand tokens); a 3 B model leaves room for longer context. Speed:
**not measured**.

Disk is not the constraint: a few GB per model, against the ~430 GB of the
SSD; the disk was sized for the hosted web app's audio files, which are far
larger.

## The decision that is still open: the NVIDIA driver

`nouveau` provides no CUDA, and the common local runtimes (llama.cpp, Ollama)
use CUDA on NVIDIA GPUs. Today's decision is **not** to install the proprietary
driver ([decision 0015](decisions/0015-power-saving-no-proprietary-driver.md)).
Reopening it is the owner's call:

| | Proprietary driver + CUDA | Stay on nouveau |
|---|---|---|
| Speed | GPU inference, many times faster than CPU (not measured here) | CPU only: a 3–7 B model works, slowly (not measured) |
| Power | the GPU must keep reaching D3cold when idle; the driver's runtime power management is meant to, but it must be **measured** with the panel's "Power and GPU" row, before and after | already D3cold 99.97 % of the time |
| Secure Boot | the driver's DKMS modules must be signed; the existing Machine Owner Key should sign them without a new enrolment (to confirm) | nothing to do |
| Maintenance | another out-of-tree module to rebuild on every kernel update; a failed build leaves no GPU | none |
| Alternative | Vulkan through Mesa (NVK) avoids the proprietary driver; its maturity on Ubuntu 24.04 for this GPU is **to confirm** | — |

Suggested order: CPU-only first with a 3 B model to learn whether the use case
is worth it; only then decide on the driver, measuring power before and after.

## Isolation

- The model server in a container on a Docker network with `internal: true`
  (no route out), its API bound to `127.0.0.1`; host firewall unchanged.
- Model files downloaded once, checked against published hashes, mounted
  read-only; no automatic updates.
- Not served through Tailscale until there is a login in front of it.

## Access to the data: tools, not dumps

- The model gets **read-only tools**: bounded InfluxQL queries through the
  existing read-only account (`garmin_reader`) and, if useful, PromQL. Each
  query has a time limit and a row cap; every query is logged.
- No bulk export of the health data into the prompt: the model asks for the
  aggregates it needs.

## Where garmin-givemydata would fit

[garmin-givemydata](https://github.com/nrvim/garmin-givemydata) (AGPL-3.0)
drives a browser to collect more of the account's data into SQLite (about 48
tables) and offers an MCP server for AI tools. More fields than InfluxDB here,
but: the AGPL obliges you to publish your changes if you offer a modified
version over a network; browser automation is an even less official access
than the API used today (terms of service); it is an extra moving part. Option
for later, outside this repository; InfluxDB stays the source for the panel.

## Training plans: safeguards

- Not medical advice; the interface says so on every plan.
- A person reviews every plan before following it.
- Conservative rules the model cannot override, e.g. weekly volume increases
  kept small (a common rule of thumb is about 10 %), rest days kept, and a
  stop-and-ask when resting heart rate, HRV or sleep move sharply.
- Plans are suggestions written to a file, never pushed to the watch or the
  Garmin account.

## How it would be evaluated

- A fixed set of questions with known answers over the **demo** data (invented,
  so results can be published).
- Checks: correct numbers (compared with direct queries), refusal to invent
  data that is not there, latency, and power measured on the panel.
