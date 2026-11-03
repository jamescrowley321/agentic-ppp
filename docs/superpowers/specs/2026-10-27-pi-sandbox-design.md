# agentic-ppp: a pi sandbox that can only use agentic-ppp's keys

Issue: #2.

## Intent and why

James has two personal pi/OpenRouter setups on this machine. agentic-ppp
runs must never spend on them. A run may use only the keys oss-admin mints
for this repo (`agentic-ppp-track-1`, `agentic-ppp-track-2`). "Remember to
use the wrapper" is not enough: Ralph, a cron watcher and a systemd unit all
start pi on their own, and an agent's bash tool can read any file its user
can.

## Decided by James (2026-10-27)

A separate Linux user, Docker, or both, with the keys passed in through
environment variables. Credentials never sit in a pi config directory.

## What pi does (tested 2026-10-27, pi 1.2.0)

- pi keeps its config in `PI_CODING_AGENT_DIR`, default `~/.pi/agent`.
- With `PI_CODING_AGENT_DIR` pointing at an empty directory and no
  `OPENROUTER_API_KEY`, pi refuses to run. It does not fall back to
  `~/.pi/agent`.
- With `OPENROUTER_API_KEY` set, pi uses it, and writes an empty `auth.json`.
  The key is not stored.

## Design

Two modes, one launcher: `scripts/ppp-run.sh <track-1|track-2> [--docker] --
<command>...`.

**Host mode** runs as the `ppp` user. It's for Ralph loops, the cron watcher
and any systemd unit, which are awkward in a container.

- `ppp` is a normal user with no sudo and no extra groups. Above all it is
  not in `docker`, which would make it root-equivalent. James's home is
  `750`, so `ppp` can't read `~james/.pi`.
- `scripts/setup-ppp-user.sh`, run once by James with sudo, creates the user,
  enables lingering for its systemd user units, and installs the track keys
  into `~ppp/.config/agentic-ppp/` (mode `600`, owned by `ppp`).
- The launcher refuses host mode unless the current user is `ppp`.

**Docker mode** runs as James. It's for one-shot pi runs: plain pi, pi-fabric.

- The container gets the worktree at `/workspace` and nothing else from the
  host. It has a throwaway `PI_CODING_AGENT_DIR` and the keys as environment
  variables. Nothing from `~/.pi` is mounted.
- The image is `scripts/pi-docker/Dockerfile`: Node and a pinned pi version.

**In both modes** the launcher:

1. Reads `<key dir>/<track>.key`. The key dir is `~/.config/agentic-ppp`.
   The file must exist with mode `600`.
2. Reads `<key dir>/github.token` if it exists: a fine-grained token
   scoped to identity-stack, passed as `GH_TOKEN`.
3. Points `PI_CODING_AGENT_DIR` at `~/.config/agentic-ppp/pi-agent-<track>`
   (host) or `/pi` (Docker). Before the run it refuses if that directory's
   `auth.json` holds a credential, or if its `models.json` names an
   `apiKey`.
4. Builds the child's environment from nothing (`env -i`). It passes on only
   `HOME`, `USER`, `PATH`, `LANG`, `TERM`, the key, the token and pi's own
   settings. No other provider key, and no `SSH_AUTH_SOCK`, reaches the run.
   In Docker mode, values go in by name (`-e OPENROUTER_API_KEY`), never on
   the command line, where `ps` would show them.
5. Asks OpenRouter (`/api/v1/key`) whether the key is valid and has budget
   left, and refuses if not.

**Not possible: refusing by key name.** `/api/v1/key` doesn't return a key's
name, so the launcher can't check for `agentic-ppp-track-*`. The guarantee
comes from the pieces above instead: the key comes only from the track file,
the environment is built from nothing, and the pi directory holds no
credentials.

This replaces the key routing in the Track 1 plan (Task 9's `auth.json`
`!command` and `pi-openrouter-key.sh --require`). When Track 1 runs, its
runner calls `ppp-run.sh track-1` instead.

## Left to James

- Run `sudo scripts/setup-ppp-user.sh` once.
- Create the fine-grained GitHub token. Repository access: identity-stack
  only. Permissions: contents, pull requests and issues read and write;
  metadata read. Save it as `~ppp/.config/agentic-ppp/github.token`, mode
  `600`.
- OpenRouter: the account the agentic-ppp keys belong to allows only a short
  list of providers, and none of them serves GLM. Allow a GLM provider there
  (ZDR ones only, to match the ZDR routing James's own pi uses), or pick a
  model the allowed providers serve.

## My calls (marked)

- *(My call)* Both modes, chosen by the tool: host mode as `ppp` for
  anything long-running, Docker for one-shot runs.
- *(My call)* The launcher's checks run on every start, not once at setup.
- *(My call)* The keys stay in James's `~/.config/agentic-ppp/` as well, for
  Docker mode. `ppp` gets its own copies.
