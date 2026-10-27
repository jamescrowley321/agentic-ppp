#!/usr/bin/env bash
# Tests for lib/repos.sh. Sourced by run.sh after lib.sh.

use_repos() { # writes $T/repos.tsv from stdin and sources repos.sh
  cat > "$T/repos.tsv"
  export AGENTIC_PPP_REPOS="$T/repos.tsv"
  # shellcheck source=../lib/repos.sh disable=SC1091
  source "$SCRIPTS_DIR/lib/repos.sh"
}

test_lookup_slug_and_clone() {
  use_repos <<< $'identity-stack\tjamescrowley321/identity-stack\t~/repos/auth/identity-stack\tgate'
  assert_eq "jamescrowley321/identity-stack" "$(repo_slug identity-stack)" slug
  assert_eq "$HOME/repos/auth/identity-stack" "$(repo_clone identity-stack)" clone
}

test_comments_blank_crlf() {
  use_repos <<< $'# c\n\nalpha\ta/alpha\t~/a\tgate\r\nbeta\ta/beta\t~/b\t-   \n'
  assert_eq $'alpha\nbeta' "$(repo_names)" names
  assert_eq "a/beta" "$(repo_slug beta)" slug
  assert_eq "gate" "$(repo_has alpha gate && echo gate)" features
}

test_unknown_repo() {
  use_repos <<< $'alpha\ta/alpha\t~/a\tgate'
  local out status=0
  out="$(repo_slug nope)" || status=$?
  assert_status 1 "$status"
  assert_eq "" "$out" output
}

test_features() {
  use_repos <<< $'codecite\tj/codecite\t~/c\tgate,eval\nidentity-stack\tj/identity-stack\t~/i\tgate\nplain\tj/plain\t~/p\t-'
  local s=0
  repo_has codecite eval || s=$?
  assert_status 0 "$s" "codecite eval"
  s=0
  repo_has identity-stack eval || s=$?
  assert_status 1 "$s" "identity-stack eval"
  s=0
  repo_has plain gate || s=$?
  assert_status 1 "$s" "plain gate"
  s=0
  repo_has nope gate || s=$?
  assert_status 1 "$s" "unknown"
}
