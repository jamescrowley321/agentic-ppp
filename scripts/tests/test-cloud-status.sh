#!/usr/bin/env bash
# Tests for cloud-status.sh. Sourced by run.sh after lib.sh.

STATUS_SH="$SCRIPTS_DIR/cloud-status.sh"
ALL_REPOS=(codecite identity-stack terraform-provider-descope identity-stack-planning agentic-ppp)

# empty_fixtures: every repo in repos.tsv has an empty open-PR list.
empty_fixtures() {
  local r
  for r in "${ALL_REPOS[@]}"; do
    mkdir -p "$STUB_FIXTURES/$r"
    echo '[]' > "$STUB_FIXTURES/$r/pr-list.json"
  done
}

# add_pr <repo> <n> <title> <body> [<reviews-json>]: one open PR on a green gate.
add_pr() {
  local n="$2" title="$3" body="$4" reviews="${5:-[]}" dir="$STUB_FIXTURES/$1"
  mkdir -p "$dir"
  jq -c --argjson n "$n" '. + [{number: $n}]' "$dir/pr-list.json" > "$dir/pr-list.new" 2> /dev/null \
    || jq -cn --argjson n "$n" '[{number: $n}]' > "$dir/pr-list.new"
  mv "$dir/pr-list.new" "$dir/pr-list.json"
  jq -n --argjson n "$n" --arg t "$title" --arg b "$body" --argjson r "$reviews" '{
    number: $n, title: $t, body: $b, mergeStateStatus: "BEHIND", headRefOid: "abc123",
    reviews: $r, comments: [], labels: [],
    statusCheckRollup: [{name: "Merge Gate", status: "COMPLETED", conclusion: "SUCCESS", startedAt: "2026-10-26T00:00:00Z"}]
  }' > "$dir/pr-$n.json"
}

test_single_repo_omits_eval() {
  empty_fixtures
  add_pr identity-stack 500 "Add thing" "Closes #480"
  run_cmd "$STATUS_SH" identity-stack
  assert_status 0 "$STATUS"
  header="$(printf '%s\n' "$OUT" | sed -n 1p | tr -s ' ')"
  assert_eq "REPO PR STATE GATE ISSUE TITLE" "$header" header
  row="$(printf '%s\n' "$OUT" | sed -n 2p | tr -s ' ')"
  assert_contains "$row" "identity-stack #500 BEHIND SUCCESS #480"
}

test_all_shows_na() {
  empty_fixtures
  add_pr identity-stack-planning 7 "Plan" "Closes #3"
  run_cmd "$STATUS_SH" --all
  assert_status 0 "$STATUS"
  header="$(printf '%s\n' "$OUT" | sed -n 1p | tr -s ' ')"
  assert_eq "REPO PR STATE GATE ISSUE EVAL TITLE" "$header" header
  row="$(printf '%s\n' "$OUT" | grep '^identity-stack-planning' | tr -s ' ')"
  assert_contains "$row" "identity-stack-planning #7 BEHIND n/a #3 n/a"
}

test_passes_slug() {
  empty_fixtures
  run_cmd "$STATUS_SH" identity-stack
  assert_contains "$(cat "$STUB_CALLS")" "-R jamescrowley321/identity-stack"
}

test_specific_prs_only() {
  empty_fixtures
  add_pr identity-stack 500 "Add thing" "Closes #480"
  run_cmd "$STATUS_SH" identity-stack 500
  assert_status 0 "$STATUS"
  calls="$(cat "$STUB_CALLS")"
  assert_contains "$calls" "pr view 500"
  assert_not_contains "$calls" "pr list"
}

test_changes_requested_lens() {
  empty_fixtures
  add_pr identity-stack 500 "Add thing" "Closes #480" \
    '[{"state":"CHANGES_REQUESTED","commit":{"oid":"abc123"},"body":"## Security Review\nbad"}]'
  run_cmd "$STATUS_SH" identity-stack
  assert_contains "$OUT" "[Security Review] Add thing"
}

test_no_open_prs() {
  empty_fixtures
  run_cmd "$STATUS_SH" identity-stack
  assert_status 0 "$STATUS"
  assert_eq 1 "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "line count"
  assert_contains "$OUT" "REPO"
}

test_gh_failure_one_repo() {
  empty_fixtures
  add_pr identity-stack 500 "Add thing" "Closes #480"
  : > "$STUB_FIXTURES/terraform-provider-descope/fail"
  run_cmd "$STATUS_SH" --all
  assert_status 1 "$STATUS"
  assert_contains "$ERR" "terraform-provider-descope: gh failed"
  assert_contains "$OUT" "identity-stack"
  assert_contains "$OUT" "#500"
}

test_usage() {
  empty_fixtures
  run_cmd "$STATUS_SH"
  assert_status 2 "$STATUS" "no args"
  assert_contains "$ERR" "usage: cloud-status.sh"
  run_cmd "$STATUS_SH" nope
  assert_status 2 "$STATUS" "unknown repo"
}
