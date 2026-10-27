#!/usr/bin/env bash
# Repo list helpers, sourced by the cloud scripts.
#
# The list is scripts/repos.tsv (or $AGENTIC_PPP_REPOS): tab-separated
# "name slug clone features", "#" comments, "~" allowed in clone, features a
# comma list of gate and eval, or "-" for none.

repos_file() {
  if [[ -n "${AGENTIC_PPP_REPOS:-}" ]]; then
    printf '%s\n' "$AGENTIC_PPP_REPOS"
  else
    printf '%s\n' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/repos.tsv"
  fi
}

# _repo_rows: non-comment, non-blank rows with \r and trailing space removed.
_repo_rows() {
  sed -e 's/\r$//' -e 's/[[:space:]]*$//' "$(repos_file)" | grep -v -e '^#' -e '^$' || true
}

repo_names() {
  _repo_rows | cut -f1
}

# _repo_field <name> <column>: prints nothing and returns 1 for an unknown name.
_repo_field() {
  local value
  value="$(_repo_rows | awk -F'\t' -v n="$1" -v c="$2" '$1 == n { print $c; found = 1; exit } END { exit !found }')" || return 1
  printf '%s\n' "$value"
}

repo_slug() {
  _repo_field "$1" 2
}

repo_clone() {
  local clone
  clone="$(_repo_field "$1" 3)" || return 1
  printf '%s\n' "${clone/#\~/$HOME}"
}

# repo_has <name> <gate|eval>: exit 0 if the repo lists the feature.
repo_has() {
  local features
  features="$(_repo_field "$1" 4)" || return 1
  [[ ",$features," == *",$2,"* ]]
}
