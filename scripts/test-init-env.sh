#!/bin/sh
# Test of scripts/init-env.sh (run by `make test` and CI).
#
# Works only in a temporary folder with a copy of the script and of
# .env.example: it never reads or writes a real .env. SIGPIPE is ignored, as
# on GitHub's runners, and the umask is permissive, to prove the mode is set
# by the script itself. Values are never printed: failures name the key only.
#
# Checks: exit code 0 and nothing on stderr; mode 600; every template key
# present; generated passwords are 32 hex characters, distinct, and do not
# appear in the output; on a second run, existing lines stay byte-identical,
# missing keys are added, and the output still shows no value.
#
# ok() and ko() always succeed, so "test && ok || ko" is a safe if/else here;
# key names are single words by construction ([A-Za-z_][A-Za-z0-9_]*).
# shellcheck disable=SC2015,SC2013
set -eu
trap '' PIPE
umask 000

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
mkdir "$work/scripts"
cp "$root/scripts/init-env.sh" "$work/scripts/"
cp "$root/.env.example" "$work/.env.example"
env="$work/.env"
fails=0
ok() { printf 'PASS %s\n' "$*"; }
ko() { printf 'FAIL %s\n' "$*"; fails=$((fails + 1)); }

keys() { grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$1" | cut -d= -f1; }
value() { grep -E "^$2=" "$1" | head -n 1 | cut -d= -f2-; }

# No value of length >= 8 from the .env may appear in the captured output.
no_value_in() {
  leaked=""
  for k in $(keys "$env"); do
    v=$(value "$env" "$k")
    if [ "${#v}" -ge 8 ] && grep -q -F -e "$v" "$1"; then leaked="$leaked $k"; fi
  done
  [ -z "$leaked" ] && ok "$2: no value in the output" || ko "$2: value of$leaked shown in the output"
}

mode_600() {
  m=$(stat -c '%a' "$env")
  [ "$m" = 600 ] && ok "$1: mode 600" || ko "$1: mode $m"
}

# ---------------------------------------------------------------- 1st run
"$work/scripts/init-env.sh" >"$work/out1" 2>"$work/err1" && ok "create: exit 0" || ko "create: exit code"
[ ! -s "$work/err1" ] && ok "create: nothing on stderr" || ko "create: stderr: $(head -c 200 "$work/err1")"
mode_600 create
missing=""
for k in $(keys "$work/.env.example"); do grep -q -E "^$k=" "$env" || missing="$missing $k"; done
[ -z "$missing" ] && ok "create: every template key present" || ko "create: missing$missing"
bad=""; seen=""
for k in $(grep -E '^[A-Za-z_][A-Za-z0-9_]*=change-me$' "$work/.env.example" | cut -d= -f1); do
  v=$(value "$env" "$k")
  printf '%s' "$v" | grep -q -x -E '[0-9a-f]{32}' || bad="$bad $k"
  case " $seen " in *" $v "*) bad="$bad $k(duplicate)" ;; esac
  seen="$seen $v"
done
[ -z "$bad" ] && ok "create: passwords are 32 hex characters, distinct" || ko "create: bad passwords:$bad"
grep -q -x -E '[A-Za-z_][A-Za-z0-9_]*=change-me' "$env" && ko "create: a change-me value is left" || ok "create: no change-me left"
no_value_in "$work/out1" create

# ---------------------------------------------------------------- 2nd run
# Simulate an existing .env: change one value by hand, drop one key, and add a
# new key to the template.
sed -i 's/^GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=existingvalue0123456789/' "$env"
sed -i '/^INFLUXDB_READ_PASSWORD=/d' "$env"
printf '%s\n' 'NEW_TEST_PASSWORD=change-me' >>"$work/.env.example"
cp "$env" "$work/before"
chmod 644 "$env"
"$work/scripts/init-env.sh" >"$work/out2" 2>"$work/err2" && ok "update: exit 0" || ko "update: exit code"
[ ! -s "$work/err2" ] && ok "update: nothing on stderr" || ko "update: stderr: $(head -c 200 "$work/err2")"
mode_600 update
changed=0
while IFS= read -r l; do grep -q -x -F -e "$l" "$env" || changed=$((changed + 1)); done <"$work/before"
[ "$changed" -eq 0 ] && ok "update: existing lines intact" || ko "update: $changed existing line(s) changed"
[ "$(value "$env" GRAFANA_ADMIN_PASSWORD)" = existingvalue0123456789 ] && ok "update: hand-set value kept" || ko "update: hand-set value replaced"
for k in INFLUXDB_READ_PASSWORD NEW_TEST_PASSWORD; do
  value "$env" "$k" | grep -q -x -E '[0-9a-f]{32}' && ok "update: $k added with a new password" || ko "update: $k missing or malformed"
done
[ "$(grep -c -E '^GRAFANA_ADMIN_PASSWORD=' "$env")" -eq 1 ] && ok "update: no duplicated keys" || ko "update: duplicated key"
no_value_in "$work/out2" update

if [ "$fails" -ne 0 ]; then echo "INIT-ENV TESTS FAILED ($fails)"; exit 1; fi
echo "INIT-ENV TESTS OK"
