#!/bin/sh
# Pre-publication audit: fails if the repository contains anything that must
# not be public.
#
#   scripts/audit-public.sh            # working tree (tracked + untracked, not ignored)
#   scripts/audit-public.sh --staged   # what the next commit would contain
#   scripts/audit-public.sh --history  # every commit, message and author of all refs
#   scripts/audit-public.sh --all      # tree + history
#
# Checks:
#   1. local denylist (scripts/audit-denylist.local, ignored by git): the real
#      host name, user name, addresses... of YOUR machine. See
#      docs/PUBLISH_CHECKLIST.md for how to create it.
#   2. IPv4 outside loopback/documentation ranges, IPv6, *.ts.net names,
#      MAC addresses, e-mail addresses other than noreply/example ones;
#   3. files that must never be tracked (.env, tokens, the denylist itself);
#   4. unresolved Grafana datasource inputs (${DS_...}) in dashboards;
#   5. gitleaks (pinned image) for credentials.
#
# Findings are printed as file:line and the kind of finding, NEVER the matched
# value, so the output itself is safe to paste or to show in CI logs.
# Without the denylist the script fails, unless AUDIT_ALLOW_NO_DENYLIST=1
# (used in CI, where the private list does not exist).
set -eu

GITLEAKS_IMAGE="zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f"

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
mode=${1:---tree}
denylist="$root/scripts/audit-denylist.local"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
fail=0

note() { printf '  %s\n' "$*"; }
bad() { printf 'FAIL %s\n' "$*"; fail=1; }

# ---------------------------------------------------------------- inputs
# Build a folder ($work/scan) with the text to scan.
mkdir -p "$work/scan"
case "$mode" in
  --tree|--all)
    # Copy every tracked or untracked-but-not-ignored file (NUL-separated list).
    # shellcheck disable=SC2016  # the inner script expands $1/$2 itself
    git ls-files -z -co --exclude-standard \
      | xargs -0 -I{} sh -c '[ -f "$1" ] && mkdir -p "$2/$(dirname "$1")" && cp "$1" "$2/$1"' _ {} "$work/scan/tree"
    ;;
  --staged)
    git checkout-index -a --prefix="$work/scan/staged/" ;;
  --history) : ;;
  *) echo "usage: $0 [--tree|--staged|--history|--all]" >&2; exit 2 ;;
esac
case "$mode" in
  --history|--all)
    if git rev-parse -q --verify HEAD >/dev/null; then
      # Patches, messages, author and committer of every commit of every ref.
      git log --all -p --format='commit %H%nauthor %an <%ae>%ncommitter %cn <%ce>%n%B' \
        >"$work/scan/history.txt"
    fi ;;
esac

# ---------------------------------------------------------- 1. denylist
echo "== 1. local denylist"
if [ -f "$denylist" ]; then
  n=0
  grep -v -e '^#' -e '^[[:space:]]*$' "$denylist" >"$work/deny" || true
  while IFS= read -r entry; do
    n=$((n + 1))
    hits=$(grep -r -I -n -i -w -F -e "$entry" "$work/scan" 2>/dev/null | cut -d: -f1,2 | sed "s#^$work/scan/##" || true)
    if [ -n "$hits" ]; then
      bad "denylist entry #$n found at:"
      printf '%s\n' "$hits" | sed 's/^/    /'
    fi
  done <"$work/deny"
  note "$n entries checked"
elif [ "${AUDIT_ALLOW_NO_DENYLIST:-0}" = 1 ]; then
  note "WARNING: no local denylist (allowed by AUDIT_ALLOW_NO_DENYLIST=1)"
else
  bad "missing $denylist (see docs/PUBLISH_CHECKLIST.md)"
fi

# ------------------------------------------------- 2. generic patterns
echo "== 2. addresses, names and e-mails"
scan_pattern() {
  # $1 = label, $2 = extended regex, $3 = allow regex (matches to ignore)
  grep -r -I -n -o -E -e "$2" "$work/scan" 2>/dev/null \
    | { if [ -n "$3" ]; then grep -v -E -e "$3"; else cat; fi; } \
    | cut -d: -f1,2 | sed "s#^$work/scan/##" | sort -u >"$work/hits" || true
  if [ -s "$work/hits" ]; then
    bad "$1 at:"
    sed 's/^/    /' "$work/hits"
  fi
}
# IPv4: allowed are loopback, 0.0.0.0, link-local DNS stub and the
# documentation ranges (RFC 5737). Anything else (home LAN, Tailscale 100.x,
# public) fails.
scan_pattern "IPv4 address" \
  '(^|[^0-9.])((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])([^0-9.]|$)' \
  ':[^0-9]?(127\.[0-9.]+|0\.0\.0\.0|192\.0\.2\.[0-9]+|198\.51\.100\.[0-9]+|203\.0\.113\.[0-9]+)([^0-9.]|$)'
# IPv6 with at least four groups or a "::" between hex groups, as a whole word
# (so "activityType::field" or "std::map" do not count). ::1 is allowed, and so
# is the documentation prefix 2001:db8::/32.
scan_pattern "IPv6 address" \
  '(^|[^0-9A-Za-z_:])(([0-9a-fA-F]{1,4}:){4,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,6}(:[0-9a-fA-F]{1,4}){1,6})([^0-9A-Za-z_]|$)' \
  ':[^:]?(2001:)?[dD][bB]8:'
scan_pattern "Tailscale MagicDNS name (*.ts.net)" '[A-Za-z0-9-]+\.ts\.net' ''
scan_pattern "MAC address" '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' ''
scan_pattern "e-mail address" \
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
  ':[^@]*@(users\.noreply\.github\.com|anthropic\.com|example\.(com|org|net))$'

# ------------------------------------------- 3. files never to be tracked
echo "== 3. forbidden files"
if [ "$mode" != --history ]; then
  forbidden=$(git ls-files -co --exclude-standard | grep -E '(^|/)(\.env|garmin_tokens\.json|AUTH_FAILED|audit-denylist\.local|forbidden-projects\.local)$|\.swp$' || true)
  [ -n "$forbidden" ] && bad "forbidden files present (tracked or not ignored): $forbidden"
fi
if git rev-parse -q --verify HEAD >/dev/null; then
  ever=$(git log --all --format= --name-only | grep -E '(^|/)(\.env|garmin_tokens\.json|audit-denylist\.local)$' | sort -u || true)
  [ -n "$ever" ] && bad "forbidden file in history: $ever"
fi

# ------------------------------------------ 4. unresolved dashboard inputs
echo "== 4. dashboards"
if [ -d "$work/scan/tree" ] || [ -d "$work/scan/staged" ]; then
  # shellcheck disable=SC2016  # literal ${DS_ wanted
  unresolved=$(grep -r -l -F '${DS_' "$work/scan" --include='*.json' 2>/dev/null \
    | sed "s#^$work/scan/##" | grep -v '/vendor/' || true)
  [ -n "$unresolved" ] && bad "unresolved \${DS_...} inputs in: $unresolved"
fi

# -------------------------------------------------------- 5. gitleaks
echo "== 5. gitleaks"
if command -v docker >/dev/null 2>&1; then
  if [ "$mode" = --history ] || [ "$mode" = --all ]; then
    if git rev-parse -q --verify HEAD >/dev/null; then
      docker run --rm --network none -v "$root:/repo:ro" "$GITLEAKS_IMAGE" \
        git /repo --no-banner --redact --log-level warn || bad "gitleaks (history)"
    fi
  fi
  if [ "$mode" != --history ]; then
    docker run --rm --network none -v "$work/scan:/scan:ro" "$GITLEAKS_IMAGE" \
      dir /scan --no-banner --redact --log-level warn || bad "gitleaks (files)"
  fi
else
  bad "docker not available: gitleaks not run"
fi

if [ "$fail" -ne 0 ]; then
  echo "AUDIT FAILED ($mode)"
  exit 1
fi
echo "AUDIT OK ($mode)"
