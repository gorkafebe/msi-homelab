#!/bin/sh
# Create or complete .env from .env.example without ever printing a secret.
#
#   scripts/init-env.sh            # .env next to .env.example (repository root)
#   scripts/init-env.sh path/.env  # another location
#
# What it does:
#   - new .env: copy of .env.example where every value "change-me" becomes a
#     random 32-character password (128 random bits as lowercase hex);
#   - existing .env: appends only the keys it does not have yet (new keys get a
#     random password if their template value is "change-me"); existing lines
#     are never changed, so a working Grafana password is never replaced;
#   - mode 600 (only your user can read it), written through a temporary file
#     in the same folder and renamed, so a half-written .env never exists.
# It prints key NAMES, never values.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
template="$root/.env.example"
target=${1:-"$root/.env"}

[ -f "$template" ] || { echo "missing $template" >&2; exit 1; }
umask 077

random_password() {
  # 16 random bytes as 32 lowercase hex characters ([0-9a-f]): safe in .env,
  # YAML, URLs and InfluxQL strings, no quoting needed. od reads exactly 16
  # bytes, so there is no "tr | head" pipe whose writer could hit SIGPIPE
  # (ignored on some CI runners, where it printed "Broken pipe").
  od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
}

tmp=$(mktemp "$(dirname -- "$target")/.env.tmp.XXXXXX")
trap 'rm -f "$tmp"' EXIT INT TERM

if [ -f "$target" ]; then
  cp -p "$target" "$tmp"
  mode=update
else
  : >"$tmp"
  mode=create
fi

added=0
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    ''|'#'*)
      [ "$mode" = create ] && printf '%s\n' "$line" >>"$tmp"
      continue ;;
  esac
  key=${line%%=*}
  value=${line#*=}
  if [ "$mode" = update ] && grep -q "^${key}=" "$tmp"; then
    continue
  fi
  if [ "$value" = "change-me" ]; then
    value=$(random_password)
  fi
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  echo "set ${key}"
  added=$((added + 1))
done <"$template"

chmod 600 "$tmp"
mv -f "$tmp" "$target"
trap - EXIT INT TERM
echo "${mode}d $(basename -- "$target") (mode 600), ${added} key(s) written; values not shown."
