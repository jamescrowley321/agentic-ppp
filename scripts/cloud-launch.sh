#!/usr/bin/env bash
# Start one Claude Code cloud session per issue in one repo and print each
# session's link.
#
#   scripts/cloud-launch.sh <repo> <issue> [<issue> ...]
#   scripts/cloud-launch.sh identity-stack 480 481
#
# <repo> is a name from scripts/repos.tsv. At most 4 issues per launch. The
# repo's local clone must be on main: the session is started from it, and the
# cloud session works the repo's issue per its AGENTS.md "Working an issue end
# to end". The sessions run in the cloud: once this script returns, nothing
# stays running locally, and the machine can go offline.
#
# `claude --cloud` refuses to run without a terminal, so each launch runs
# under `script`, which gives it one. Every launch is also appended to
# $AGENTIC_PPP_CLOUD_LOG (default ~/.local/state/agentic-ppp/cloud-sessions.log)
# as "<UTC time> <repo>#<issue> <link>", so the links survive the terminal.
#
# Exit codes: 2 for usage errors, 1 if any single launch failed, 0 otherwise.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$here/lib/repos.sh"

if [[ $# -lt 2 ]]; then
  echo "usage: cloud-launch.sh <repo> <issue> [<issue> ...]" >&2
  exit 2
fi

repo="$1"
shift
if ! slug="$(repo_slug "$repo")"; then
  echo "$repo: not in $(repos_file)" >&2
  exit 2
fi
clone="$(repo_clone "$repo")"
if [[ ! -d "$clone" ]]; then
  echo "$repo: clone not found at $clone" >&2
  exit 2
fi
branch="$(git -C "$clone" rev-parse --abbrev-ref HEAD 2> /dev/null || true)"
if [[ "$branch" != "main" ]]; then
  echo "$repo: $clone is on ${branch:-an unknown branch}, not main" >&2
  exit 2
fi
if [[ $# -gt 4 ]]; then
  echo "$repo: at most 4 sessions per launch" >&2
  exit 2
fi

LOG="${AGENTIC_PPP_CLOUD_LOG:-$HOME/.local/state/agentic-ppp/cloud-sessions.log}"
mkdir -p "$(dirname "$LOG")"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

status=0
declare -A seen=()
for n in "$@"; do
  if [[ ! "$n" =~ ^[0-9]+$ ]]; then
    echo "$repo#$n: not an issue number" >&2
    status=1
    continue
  fi
  # One session per issue: a repeated argument would start a second one.
  if [[ -n "${seen[$n]:-}" ]]; then
    echo "$repo#$n: listed twice; launched once" >&2
    continue
  fi
  seen[$n]=1
  prompt="Work $slug#$n per AGENTS.md 'Working an issue end to end'"
  # `script` records the session's output, terminal escapes and all.
  (cd "$clone" && timeout 120 script -qfc "claude --cloud \"$prompt\"" "$TMP/$n.log" < /dev/null > /dev/null 2>&1) || true
  url="$(sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$TMP/$n.log" 2> /dev/null | tr -d '\r' \
    | grep -o 'https://claude.ai/code/session_[A-Za-z0-9]*' | head -1 || true)"
  if [[ -z "$url" ]]; then
    echo "$repo#$n: no session created; output follows" >&2
    # An empty log matches nothing; that must not stop the remaining launches.
    sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$TMP/$n.log" 2> /dev/null | tr -d '\r' | grep -v '^\s*$' | tail -5 >&2 || true
    status=1
    continue
  fi
  echo "$repo#$n: $url"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $repo#$n $url" >> "$LOG"
done
exit "$status"
