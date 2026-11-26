# 0028 — Garmin: tokens only, one manual login with a newer library

**Status:** in force; token compatibility between the two library versions is
**read from the source code, not verified** against Garmin.

**Context.** garmin-grafana pins `garminconnect==0.3.7`, whose mobile login
answered 429 from April until 0.3.20 fixed it (0.3.20 changelog). Repeated
failed logins can lock a Garmin account for a long time. Upstream asks for the
e-mail and password in the environment or on the terminal.

**Decision.** No e-mail or password anywhere in configuration. The first login
is done **once, by hand**, in a one-shot container with garminconnect 0.3.20:
`getpass`, one strategy with one TLS fingerprint, no retries; it checks that the
saved `garmin_tokens.json` is usable. The fetcher keeps 0.3.7 and only uses the
tokens; a wrapper holds it (no network) when tokens are missing or after any
exit, so a restart never becomes a login attempt.

**Alternatives.** (A) Log in with 0.3.7 as is — the broken mobile login, web
fallbacks that may leave an unsaveable session. (C) Rebuild the fetcher with
0.3.20 — an untested combination after a full library reorganisation.

**Why B is believed compatible.** Both versions write and read the same file
(`<dir>/garmin_tokens.json`) with the same three keys (`di_token`,
`di_refresh_token`, `di_client_id`) and refresh at the same endpoint with the
same client IDs.

**Consequences.** If the 0.3.7 refresh ever fails, the fetcher stops and waits
for a person. Details: [GARMIN.md](../GARMIN.md).
