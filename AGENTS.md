# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this is

agentic-ppp: a public repo for trying ways of running coding agents, in two
tracks.

- **Track 1** compares agent setups fairly, on a sandbox in this repo. Design:
  `docs/superpowers/specs/2026-10-26-objective-evaluation-design.md`.
- **Track 2** uses agents on real issues in James's own public repos and
  writes up how it went. Design:
  `docs/superpowers/specs/2026-10-26-practical-use-design.md`.

Read the design for your track before any non-trivial change.

## Where things live

| What | Where |
| --- | --- |
| Why and what, per track | `docs/superpowers/specs/` |
| Steps for one piece of work | `docs/superpowers/plans/` |
| Work and status | GitHub issues and milestones. The only place status lives |
| Technique notes | `notes/track-1/`, `notes/track-2/` (format in `notes/README.md`) |
| Experiments and their config | `pocs/track-1/<name>/`, `pocs/track-2/<name>/` |
| Shared cloud scripts and their tests | `scripts/` |
| Track 1 sandbox | `sandbox/` |
| CI | `.github/workflows/ci.yml` |

## Git

- Work on a `<type>/<short-description>` branch in its own worktree under
  `~/repos/auth/agentic-ppp-worktrees/`. The primary checkout stays on a
  clean `main`. A Claude Code cloud session works on its own branch in its
  own checkout instead.
- Conventional commits. Every change lands through a squash-merged PR to
  `main`. The PR title becomes the commit.
- Never force-push. James and other sessions push to the same branches; fetch
  before you push.
- James merges. Never merge your own PR.
- Repo settings live in oss-admin, in `terraform/agentic-ppp`. Change them
  there, not in the GitHub UI.

## Rules for every artifact

- Name no client or outside project in commits, PRs, issues or docs. The
  public repos and tools named in the specs are fine. Anything else is
  "another project".
- No secrets or keys in the repo. Keys live in `~/.config/agentic-ppp/`.
- Every PR body has an AI provenance section naming the harness and the
  model, and the box `- [x] A human has reviewed this change and is
  accountable for it`, ticked.
- No status words (for example "waiting" or "finished") in any doc. Status lives in GitHub
  issues.
- Specs and plans are frozen once their PR merges. Don't edit them.

## Notes

A note follows the format in `notes/README.md`. Agents fill in the facts.
Leave each part marked *(James)* as a `*(James)*` placeholder line. James
writes those in the first person.

## POCs

Each POC is one folder, `pocs/track-1/<name>/` or `pocs/track-2/<name>/`. Its
README says how to run it and how to remove it, under a "Remove it" heading.

## Before every push

Run what CI runs:

```bash
shellcheck scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh pocs/*/*/*.sh
scripts/tests/run.sh
pocs/*/*/tests/run.sh        # each one that exists
uvx zizmor@1.31.1 .github/workflows/
```

## Working an issue end to end

This is how an agent, local or in a Claude Code cloud session, takes one
issue to a reviewed PR.

1. **Pick.** Take the issue you were given, or the next open one the pinned
   queue issue names. Read it and the design for its track.
2. **Plan.** Write the plan by hand in the PR body. For larger work, add a
   file in `docs/superpowers/plans/`.
3. **Build test-first.** Write the failing test, then the code. Before every
   push, run the list in "Before every push".
4. **Open the PR against `main`.** Use a conventional title. Put
   `Closes #<n>`, the issue's acceptance criteria and the provenance section
   in the body.
5. **Answer the review.** Read the CI and review feedback on the PR. Fix every
   MUST FIX at its cause, test-first. Fix a SHOULD FIX when it's cheap. For a
   false positive, reply on the PR saying why. After three review rounds,
   stop and post a PR comment summarising what's left.
6. **Stop there.** James merges. Don't merge your own PR.

If `gh` isn't logged in, use the GitHub connector tools instead.
