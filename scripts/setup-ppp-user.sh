#!/usr/bin/env bash
# sudo setup-ppp-user.sh [--dry-run]
#
# One-time setup of the ppp user that agentic-ppp's host-mode runs use (see
# docs/superpowers/specs/2026-10-27-pi-sandbox-design.md). Idempotent.
#
# - Creates ppp with a private home, no sudo and no extra groups.
# - Enables lingering, so ppp's systemd user units run without a login.
# - Copies the track keys from the invoking user's ~/.config/agentic-ppp into
#   ~ppp/.config/agentic-ppp, mode 600, owned by ppp.
# - Checks that ppp can't enter the invoking user's home.
#
# --dry-run prints the commands instead of running them, and needs no root.
# Overrides, for tests: PPP_USER (default ppp), PPP_OWNER_HOME (default the
# invoking user's home), PPP_SOURCE_DIR (default <home>/.config/agentic-ppp).
set -euo pipefail

dry=0
case "${1:-}" in
  "") ;;
  --dry-run) dry=1 ;;
  *)
    echo "usage: sudo setup-ppp-user.sh [--dry-run]" >&2
    exit 2
    ;;
esac

ppp_user="${PPP_USER:-ppp}"
owner="${SUDO_USER:-$(id -un)}"
owner_home="${PPP_OWNER_HOME:-$(getent passwd "$owner" | cut -d: -f6)}"
source_dir="${PPP_SOURCE_DIR:-$owner_home/.config/agentic-ppp}"

run() {
  if [[ "$dry" -eq 1 ]]; then
    printf '%s\n' "$*"
  else
    "$@"
  fi
}

if [[ "$dry" -eq 0 && "$(id -u)" -ne 0 ]]; then
  echo "setup-ppp-user: run with sudo, or pass --dry-run" >&2
  exit 1
fi
[[ "$owner" != "$ppp_user" ]] || { echo "setup-ppp-user: run as your own user, not $ppp_user" >&2; exit 1; }

for track in track-1 track-2; do
  [[ -f "$source_dir/$track.key" ]] || { echo "setup-ppp-user: missing $source_dir/$track.key" >&2; exit 1; }
done

if ! getent passwd "$ppp_user" > /dev/null; then
  run useradd --create-home --shell /bin/bash --user-group "$ppp_user"
fi
run chmod 750 "/home/$ppp_user"
run loginctl enable-linger "$ppp_user"

dest="/home/$ppp_user/.config/agentic-ppp"
run install -d -m 700 -o "$ppp_user" -g "$ppp_user" "/home/$ppp_user/.config" "$dest"
for track in track-1 track-2; do
  run install -m 600 -o "$ppp_user" -g "$ppp_user" "$source_dir/$track.key" "$dest/$track.key"
done

# ppp must not reach the owner's pi credentials.
mode="$(stat -c %a "$owner_home")"
if [[ "${mode: -1}" != "0" ]]; then
  echo "setup-ppp-user: $owner_home is mode $mode; others can enter it. chmod 750 $owner_home" >&2
  exit 1
fi
if [[ "$dry" -eq 0 ]] && id -nG "$ppp_user" | tr ' ' '\n' | grep -qx -e "$owner" -e docker -e sudo; then
  echo "setup-ppp-user: $ppp_user is in a group that reaches $owner's files or root" >&2
  exit 1
fi

echo "ppp is ready. Add the GitHub token as $dest/github.token (mode 600, owned by $ppp_user)."
