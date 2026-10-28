#!/usr/bin/env bash
# ppp-run.sh <track-1|track-2> [--docker] [--image <image>] -- <command>...
#
# Runs <command> so that pi can reach only agentic-ppp's OpenRouter key for
# the track. See docs/superpowers/specs/2026-10-27-pi-sandbox-design.md.
#
# Host mode runs only as the ppp user. --docker runs <command> in a container
# that sees the current directory at /workspace and nothing else from the host.
# Either way the child's environment is rebuilt from a short allowlist, the
# key goes in as OPENROUTER_API_KEY, and the pi config directory must hold no
# credentials.
#
# Overrides, for tests: PPP_KEY_DIR (default ~/.config/agentic-ppp), PPP_USER
# (default ppp), PPP_OPENROUTER_URL (default https://openrouter.ai/api/v1/key),
# PPP_KEEP_ENV (extra variable names to keep, space-separated).
set -euo pipefail

usage() {
  echo "usage: ppp-run.sh <track-1|track-2> [--docker] [--image <image>] -- <command>..." >&2
  exit 2
}
die() {
  echo "ppp-run: $*" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
track="$1"
shift
case "$track" in
  track-1 | track-2) ;;
  *) usage ;;
esac

docker=0
image="agentic-ppp/pi:latest"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker) docker=1 ;;
    --image)
      [[ $# -ge 2 ]] || usage
      image="$2"
      shift
      ;;
    --) shift; break ;;
    *) usage ;;
  esac
  shift
done
[[ $# -ge 1 ]] || usage

key_dir="${PPP_KEY_DIR:-$HOME/.config/agentic-ppp}"
ppp_user="${PPP_USER:-ppp}"
key_url="${PPP_OPENROUTER_URL:-https://openrouter.ai/api/v1/key}"

if [[ "$docker" -eq 0 && "$(id -un)" != "$ppp_user" ]]; then
  die "host mode runs only as $ppp_user (sudo -iu $ppp_user), or pass --docker"
fi

# private_file <path>: exists and is mode 600.
private_file() {
  [[ -f "$1" ]] || return 1
  [[ "$(stat -c %a "$1")" == "600" ]]
}

key_file="$key_dir/$track.key"
private_file "$key_file" || die "$key_file must exist with mode 600"
key="$(tr -d '[:space:]' < "$key_file")"
[[ -n "$key" ]] || die "$key_file is empty"

token=""
token_file="$key_dir/github.token"
if [[ -e "$token_file" ]]; then
  private_file "$token_file" || die "$token_file must have mode 600"
  token="$(tr -d '[:space:]' < "$token_file")"
fi

# The host pi directory must hold no credential pi could use instead of the
# key passed in. (Docker mode's /pi is a fresh tmpfs.)
pi_dir="$key_dir/pi-agent-$track"
if [[ "$docker" -eq 0 ]]; then
  mkdir -p "$pi_dir"
  chmod 700 "$pi_dir"
  if [[ -s "$pi_dir/auth.json" ]] && ! jq -e 'length == 0' "$pi_dir/auth.json" > /dev/null 2>&1; then
    die "$pi_dir/auth.json holds a credential; remove it"
  fi
  if [[ -f "$pi_dir/models.json" ]] && grep -q '"apiKey"' "$pi_dir/models.json"; then
    die "$pi_dir/models.json names an apiKey; remove it"
  fi
fi

# The key goes to curl on stdin, never in argv where ps would show it.
if ! info="$(printf 'Authorization: Bearer %s\n' "$key" | curl -sf -H @- "$key_url")"; then
  die "OpenRouter rejected the $track key"
fi
if ! jq -e '.data.limit_remaining == null or .data.limit_remaining > 0' <<< "$info" > /dev/null; then
  die "the $track key has no budget left"
fi

workdir="$PWD"

# Rebuild the environment from an allowlist, then export the key and pi's
# settings. Values are exported, never passed as arguments.
keep=" HOME USER LOGNAME PATH LANG LC_ALL TERM TZ XDG_RUNTIME_DIR DOCKER_HOST DOCKER_CONTEXT ${PPP_KEEP_ENV:-} "
while IFS= read -r name; do
  [[ "$keep" == *" $name "* ]] || unset "$name" 2> /dev/null || true
done < <(compgen -e)

export OPENROUTER_API_KEY="$key"
[[ -z "$token" ]] || export GH_TOKEN="$token"
export PI_SKIP_VERSION_CHECK=1 PI_TELEMETRY=0
unset key token info

if [[ "$docker" -eq 0 ]]; then
  export PI_CODING_AGENT_DIR="$pi_dir"
  exec "$@"
fi

args=(run --rm -i)
[[ ! -t 0 ]] || args+=(-t)
args+=(
  --user "$(id -u):$(id -g)"
  --tmpfs /pi:mode=1777
  -e HOME=/pi -e PI_CODING_AGENT_DIR=/pi
  -e OPENROUTER_API_KEY -e PI_SKIP_VERSION_CHECK -e PI_TELEMETRY
)
[[ -z "${GH_TOKEN:-}" ]] || args+=(-e GH_TOKEN)
args+=(-v "$workdir:/workspace" -w /workspace "$image")
exec docker "${args[@]}" "$@"
