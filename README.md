# Agentic Principles, Patterns, and Practices

A nod to Robert C. Martin's "Agile Principles, Patterns, and Practices in C#".
`agentic-ppp` is the short form.

This repo is for trying ways of running coding agents. It has two tracks.

- **Track 1: a fair comparison.** Run each agent setup on the same sandbox, in
  this repo, with the same tasks. The setup is the only thing that changes.
  See `docs/superpowers/specs/2026-10-26-objective-evaluation-design.md`.
- **Track 2: practical use.** Use each technique on real issues in James's
  own public repos, and write up how it went as a how-to. Getting the work
  finished matters more than a fair comparison. See
  `docs/superpowers/specs/2026-10-26-practical-use-design.md`.

Finished blog posts go to James's personal-blog repo, not here.

## Layout

| Path | What it holds |
| --- | --- |
| `README.md` | Full name, short form, the two tracks, layout |
| `AGENTS.md`, `CLAUDE.md` | Repo rules. `CLAUDE.md` is `@AGENTS.md`, so cloud sessions load them |
| `docs/superpowers/specs/` | The two designs, frozen once merged |
| `docs/superpowers/plans/` | The plans, frozen once merged |
| `notes/README.md` | The notes format. Track 1 writes under `notes/track-1/`, Track 2 under `notes/track-2/` |
| `pocs/README.md` | The POC rule. One folder each, under `pocs/track-1/` or `pocs/track-2/`, with removal steps in its README |
| `scripts/repos.tsv` | The repo list: name, slug, clone path, features |
| `scripts/lib/repos.sh` | Reads `repos.tsv` |
| `scripts/cloud-launch.sh`, `scripts/cloud-status.sh` | Shared cloud scripts |
| `scripts/ppp-run.sh` | Runs pi with only agentic-ppp's OpenRouter key: as the `ppp` user, or `--docker` |
| `scripts/setup-ppp-user.sh` | One-time `sudo` setup of the `ppp` user and its keys |
| `scripts/pi-docker/Dockerfile` | The image `ppp-run.sh --docker` runs |
| `scripts/tests/` | Plain-bash tests for the scripts |
| `.github/workflows/ci.yml` | Jobs `shellcheck`, `script-tests`, `zizmor` |
| `pocs/track-2/cloud-loop/` | A timer script that launches the next queued cloud session |
| `pocs/track-2/dependabot-routine/` | The prompt and setup for the weekly Dependabot routine |
| `notes/track-2/` | Track 2 technique notes: cloud sessions, cloud loop, Dependabot routine |
| `sandbox/` | Track 1, see its plan |
| `pocs/track-1/` | Track 1, see its plan |
| `notes/track-1/` | Track 1, see its plan |
