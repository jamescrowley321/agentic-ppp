#!/usr/bin/env bash
# Show where each open PR stands: merge state, the Merge Gate on its head, the
# lenses still requesting changes there, and the issue it closes.
#
#   scripts/cloud-status.sh <repo>              # every open PR against main
#   scripts/cloud-status.sh <repo> 131 137      # just these PRs
#   scripts/cloud-status.sh --all               # every repo in scripts/repos.tsv
#
# <repo> is a name from scripts/repos.tsv. Columns: REPO PR STATE GATE ISSUE
# EVAL TITLE. GATE and EVAL appear only if a listed repo has that feature in
# repos.tsv; a repo without it shows n/a. A title prefixed [Lens] is a lens
# still requesting changes on the PR's head.
#
# Merge states: CLEAN is ready to merge, BEHIND needs `gh pr update-branch <n>`,
# DIRTY has conflicts, BLOCKED is waiting on a required check.
#
# Exit codes: 2 for usage errors, 1 if gh failed for any repo (the others are
# still printed), 0 otherwise.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$here/lib/repos.sh"

usage() {
  echo "usage: cloud-status.sh <repo> [<pr> ...] | --all" >&2
  exit 2
}

[[ $# -ge 1 ]] || usage
prs=()
if [[ "$1" == "--all" ]]; then
  [[ $# -eq 1 ]] || usage
  mapfile -t repos < <(repo_names)
else
  repo_slug "$1" > /dev/null || { echo "unknown repo: $1" >&2; usage; }
  repos=("$1")
  shift
  prs=("$@")
fi

show_gate=0 show_eval=0
for r in "${repos[@]}"; do
  ! repo_has "$r" gate || show_gate=1
  ! repo_has "$r" eval || show_eval=1
done

# Fields are tab separated: repo pr state gate issue eval title.
# shellcheck disable=SC2016  # a jq program, not a shell expression
JQ='
  # capture() emits nothing on a miss, so each match is collected in an
  # array and defaulted; any list gh returns can be null.
  .headRefOid as $h
  | ([(.statusCheckRollup // [])[] | select(.name == "Merge Gate")] | sort_by(.startedAt // "") | .[-1]
      | if . == null then "pending" else (.conclusion // .status) end) as $gate
  | ([(.reviews // [])[] | select(.commit.oid == $h and .state == "CHANGES_REQUESTED")
      | ([(.body // "") | capture("## (?<l>[^\r\n]+)").l] | .[0] // "?")] | unique | join(", ")) as $cr
  | ([(.body // "") | capture("(?i)(closes|part of) #(?<i>[0-9]+)").i] | .[0]
      | if . == null then "-" else "#" + . end) as $issue
  | (if any((.comments // [])[]; (.body // "") | contains("codecite-eval-scorecard")) then "posted"
     elif any((.labels // [])[]; .name == "eval") then "label" else "-" end) as $eval
  | "#\(.number)\t\(.mergeStateStatus)\t\($gate)\t\($issue)\t\($eval)\t\(if $cr == "" then .title else "[" + $cr + "] " + .title end)"'

rows=()
status=0
for r in "${repos[@]}"; do
  slug="$(repo_slug "$r")"
  list=("${prs[@]}")
  if [[ ${#list[@]} -eq 0 ]]; then
    if ! nums="$(gh pr list -R "$slug" --base main --state open --json number --jq '.[].number')"; then
      echo "$r: gh failed" >&2
      status=1
      continue
    fi
    mapfile -t list < <(printf '%s\n' "$nums" | grep . | sort -n || true)
  fi
  for n in "${list[@]}"; do
    if ! json="$(gh pr view "$n" -R "$slug" --json number,title,body,mergeStateStatus,headRefOid,reviews,statusCheckRollup,comments,labels)" \
      || ! line="$(printf '%s' "$json" | jq -r "$JQ")"; then
      echo "$r: gh failed" >&2
      status=1
      continue
    fi
    IFS=$'\t' read -r pr state gate issue eval title <<< "$line"
    repo_has "$r" gate || gate="n/a"
    repo_has "$r" eval || eval="n/a"
    rows+=("$r"$'\t'"$pr"$'\t'"$state"$'\t'"$gate"$'\t'"$issue"$'\t'"$eval"$'\t'"$title")
  done
done

{
  printf 'REPO\tPR\tSTATE\tGATE\tISSUE\tEVAL\tTITLE\n'
  [[ ${#rows[@]} -eq 0 ]] || printf '%s\n' "${rows[@]}"
} | awk -F'\t' -v g="$show_gate" -v e="$show_eval" '{
  out = sprintf("%-27s %-6s %-8s", $1, $2, $3)
  if (g) out = out sprintf(" %-10s", $4)
  out = out sprintf(" %-6s", $5)
  if (e) out = out sprintf(" %-6s", $6)
  print out " " $7
}'
exit "$status"
