#!/usr/bin/env bash
# Tests for cloud-launch.sh. Sourced by run.sh after lib.sh.

LAUNCH="$SCRIPTS_DIR/cloud-launch.sh"

# make_clone <name> [branch]: a git repo in $T on main (or the given branch).
make_clone() {
  mkdir -p "$T/$1"
  git -C "$T/$1" init -q -b main
  git -C "$T/$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  [[ -z "${2:-}" ]] || git -C "$T/$1" checkout -q -b "$2"
}

# write_repos <name>: repos.tsv with one row whose clone is $T/<name>.
write_repos() {
  printf '%s\tjamescrowley321/%s\t%s\tgate\n' "$1" "$1" "$T/$1" > "$T/repos.tsv"
  export AGENTIC_PPP_REPOS="$T/repos.tsv"
}

test_usage_no_args() {
  write_repos identity-stack
  run_cmd "$LAUNCH"
  assert_status 2 "$STATUS"
  assert_contains "$ERR" "usage: cloud-launch.sh <repo> <issue>"
}

test_unknown_repo_refused() {
  write_repos identity-stack
  run_cmd "$LAUNCH" nope 1
  assert_status 2 "$STATUS"
  assert_contains "$ERR" "nope: not in"
  assert_eq "" "$(cat "$STUB_CALLS")" calls
}

test_missing_clone_refused() {
  write_repos identity-stack
  run_cmd "$LAUNCH" identity-stack 1
  assert_status 2 "$STATUS"
  assert_contains "$ERR" "clone not found at"
}

test_clone_not_on_main() {
  make_clone identity-stack feat/x
  write_repos identity-stack
  run_cmd "$LAUNCH" identity-stack 1
  assert_status 2 "$STATUS"
  assert_contains "$ERR" "is on feat/x, not main"
  assert_eq "" "$(cat "$STUB_CALLS")" calls
}

test_more_than_four_refused() {
  make_clone identity-stack
  write_repos identity-stack
  run_cmd "$LAUNCH" identity-stack 1 2 3 4 5
  assert_status 2 "$STATUS"
  assert_contains "$ERR" "at most 4 sessions per launch"
  assert_eq "" "$(cat "$STUB_CALLS")" calls
}

test_runs_in_clone_with_repo_prompt() {
  make_clone identity-stack
  write_repos identity-stack
  run_cmd "$LAUNCH" identity-stack 480
  assert_status 0 "$STATUS"
  assert_eq "$T/identity-stack|--cloud Work jamescrowley321/identity-stack#480 per AGENTS.md 'Working an issue end to end'" "$(cat "$STUB_CALLS")" calls
  assert_eq "identity-stack#480: https://claude.ai/code/session_abc123" "$OUT" stdout
}

test_log_records_repo() {
  make_clone identity-stack
  write_repos identity-stack
  run_cmd "$LAUNCH" identity-stack 480
  grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z identity-stack#480 https://claude.ai/code/session_abc123$' "$T/log" \
    || fail_test "log line mismatch: $(cat "$T/log" 2> /dev/null)"
}

test_non_numeric_skipped() {
  make_clone identity-stack
  write_repos identity-stack
  run_cmd "$LAUNCH" identity-stack 480 x1
  assert_status 1 "$STATUS"
  assert_contains "$ERR" "identity-stack#x1: not an issue number"
  assert_contains "$(cat "$STUB_CALLS")" "identity-stack#480" launched
}

test_duplicate_launched_once() {
  make_clone identity-stack
  write_repos identity-stack
  run_cmd "$LAUNCH" identity-stack 480 480
  assert_eq 1 "$(wc -l < "$STUB_CALLS")" "claude calls"
  assert_contains "$ERR" "listed twice"
}

test_no_url_reports_output() {
  make_clone identity-stack
  write_repos identity-stack
  export STUB_CLAUDE_OUTPUT="error: not logged in"
  run_cmd "$LAUNCH" identity-stack 480
  assert_status 1 "$STATUS"
  assert_contains "$ERR" "no session created"
  assert_contains "$ERR" "not logged in"
  assert_eq "" "$(cat "$T/log" 2> /dev/null)" log
}
