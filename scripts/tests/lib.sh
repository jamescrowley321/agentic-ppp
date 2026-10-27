#!/usr/bin/env bash
# shellcheck disable=SC2034  # SCRIPTS_DIR, OUT, ERR, STATUS are read by the test files
# Test helpers, sourced by run.sh before each test file. Each test runs in its
# own bash with `set -e`, so a failed assertion ends that test.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$TESTS_DIR")"

# setup_test: per-test temp dir $T, stubs first on PATH, call log in STUB_CALLS.
setup_test() {
  T="$(mktemp -d)"
  trap 'rm -rf "$T"' EXIT
  export PATH="$TESTS_DIR/stubs:$PATH"
  export STUB_CALLS="$T/calls"
  export STUB_FIXTURES="$T/fixtures"
  export AGENTIC_PPP_CLOUD_LOG="$T/log"
  : > "$STUB_CALLS"
  mkdir -p "$STUB_FIXTURES"
}

fail_test() {
  echo "$*" >&2
  exit 1
}

assert_eq() { # <expected> <actual> [label]
  [[ "$1" == "$2" ]] || fail_test "${3:-values differ}: expected [$1], got [$2]"
}

assert_contains() { # <haystack> <needle> [label]
  [[ "$1" == *"$2"* ]] || fail_test "${3:-missing text}: expected [$2] in [$1]"
}

assert_not_contains() { # <haystack> <needle> [label]
  [[ "$1" != *"$2"* ]] || fail_test "${3:-unexpected text}: did not expect [$2] in [$1]"
}

assert_status() { # <expected> <actual> [label]
  [[ "$1" == "$2" ]] || fail_test "${3:-status differs}: expected exit $1, got $2"
}

# run_cmd <cmd> [args]: sets OUT, ERR and STATUS without tripping `set -e`.
run_cmd() {
  STATUS=0
  OUT="$("$@" 2> "$T/stderr")" || STATUS=$?
  ERR="$(cat "$T/stderr")"
}
