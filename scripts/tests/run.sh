#!/usr/bin/env bash
# Run every scripts/tests/test-*.sh. Each defines test_* functions; each
# function runs in its own bash with a fresh temp dir. Exits non-zero on any
# failure.
set -uo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pass=0
fail=0
for file in "$dir"/test-*.sh; do
  [[ -e "$file" ]] || continue
  mapfile -t names < <(bash -c 'source "$1"; source "$2"; declare -F | awk "{print \$3}" | grep "^test_" || true' _ "$dir/lib.sh" "$file")
  for name in "${names[@]}"; do
    if out="$(bash -c 'set -eu; source "$1"; source "$2"; setup_test; "$3"' _ "$dir/lib.sh" "$file" "$name" 2>&1)"; then
      echo "PASS $name"
      pass=$((pass + 1))
    else
      echo "FAIL $name: $(printf '%s' "$out" | tail -n 1)"
      fail=$((fail + 1))
    fi
  done
done
echo "$pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
