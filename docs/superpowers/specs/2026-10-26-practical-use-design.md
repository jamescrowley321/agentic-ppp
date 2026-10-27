# agentic-ppp, Track 2: using agents on real work

## Intent and why

James wants agents to take as much low-risk, repetitive work as they can, so
he can spend his time on design. Track 2 runs the local agent tools on real
open issues in identity-stack and writes down how it went. The work getting
done matters more than a fair comparison. Track 1 is the controlled,
like-for-like comparison and has its own design.

Each post is a how-to: "here's how you'd use X for Y, where it helped, where
it got in the way."

## Goals

- Real PRs land in identity-stack through its normal gates.
- Each tool is tried two ways: alone on work it suits (Variation B), and
  combined with another where the pair isn't redundant (Variation A). Each
  run leaves a note a post can come from.
- identity-stack's remaining features get built, from specs James writes.
  Writing those specs is the design work Track 2 frees him for.

## Non-goals

- Ranking the tools. Track 1 does that.
- Live infrastructure, local secrets, credentialed end-to-end tests. These
  stay with James.
- Other repos. identity-stack has the most features left to build, so it is
  the one repo Track 2 works against. identity-model is out: its queue is
  James's review, not implementation.
- Claude Code cloud sessions. They were dropped on 2026-10-27 after merge
  conflict churn. The readiness work already done (identity-stack#510, the
  shared cloud scripts) stays, since local agents use `AGENTS.md` too.

## Anti-goals

- A new system James has to maintain. Every POC is removed by deleting its
  `pocs/track-2/<name>/` folder and stopping its processes.
- Agents that merge. Machinery so opaque a failure can't be explained (if
  that happens, the note says so).
- A tool install that changes James's own pi setup.

## Constraints

- **Model.** GLM through OpenRouter, the same as Track 1, so a tool that
  works here is known to work there. The note records it if a tool can't run
  on GLM.
- **Key.** Every run uses the Track 2 key (`~/.config/agentic-ppp/track-2.key`,
  $30 limit) through the isolated pi wrapper
  (`LAB_TRACK=track-2 pi-lab`), never James's own pi key. About $10 per run;
  a tool's own budget setting is used where it has one.
- **Installs stay inside agentic-ppp.** `pi install` writes to
  `~/.pi/agent/settings.json`, so every package is installed under
  `PI_CODING_AGENT_DIR=~/.config/agentic-ppp/pi-agent-track-2` or
  project-locally under `pocs/track-2/<name>/`. Nothing touches `~/.pi/agent`.
- **One identity-stack worktree per run,** beside its existing worktrees.
  Ralph keeps the primary checkout on a clean `main`.
- **PRs to `main`, one per issue,** with `Closes #<n>`, the issue's "Done
  when" list and the provenance section. Agents stop at the PR; James merges.
- **Naming.** No client or outside project in any artifact.
- **Git.** Worktree branches, conventional commits, squash-merged PRs,
  never force-push. Repo settings change only in oss-admin.

## What overlaps (from the tool research, 2026-10-26)

- **pi-ralph adds nothing over Ralph 2.10.1** on its own: `ralph loops`,
  `ralph web` and `ralph tui` already show and control loops. It's tried
  only as an overlay on Ralph, in Variation A.
- **pi-durable-subagents and pi-fabric replace each other.** Both add what
  Ralph lacks (a journal, resume after a crash, budgets, failover), so they
  are never stacked together.
- **rho is a weak watcher.** A cron job reading `ralph loops --json` does the
  same, so the watcher is that script.
- **Ralph's loop is the only piece that knows GitHub** (queue, parking, CI
  and review waits).
- James prefers a dumb orchestrator. durable-subagents and pi-fabric are
  experiments to write up, not tools to adopt.

## Variation B: each tool alone

| Tool | Work | Why it fits |
| --- | --- | --- |
| Plain pi, no orchestrator (baseline) | #480 (Node 22 floor) | Small, has a "Done when". What one agent session does with no loop around it. |
| Ralph, identity-stack's `ralph.yml` | #478 (stale Vault and Infisical docs), then #481 (pip-audit suppressions) | Queue (#511) and "Done when" lists exist. Ralph's loop already parks, waits for CI and reads the review. |
| pi-fabric with `/skill:fabric-supervisor` | #406 (backend: startup-built typed config, no request-time env reads) | A multi-file refactor long enough for the journal and dashboard to matter. |
| pi-durable-subagents | Triage identity-stack's 31 open code-scanning alerts | Fan-out over many items under a budget. It proposes a disposition per alert as a report; it never dismisses one. |

## Variation A: tools together

| Combination | Work | Why it isn't redundant |
| --- | --- | --- |
| Two Ralph loops at once, pi-ralph as the view, a cron watcher on `ralph loops --json` | #474 (backend fail-open env reads) and #475 (frontend `.../undefined` authority), in parallel | Backend and frontend, so they don't collide. Answers "which loop is stuck?" from Ralph's own view against pi's overlay. The watcher restarts and reports, nothing else. |
| Ralph as the outer loop, a durable-subagents workflow as its implement step | #407 (frontend fail-closed provider config), after #475 merges | Tests whether a journaled inner step earns its keep inside a loop that already keeps state on disk. |

## Features

identity-stack's feature issues are a paragraph each: #385 (passkeys), #386
(hierarchical RBAC), #377 (provider-agnostic frontend and canonical claims),
#378 (provider-aware logout). No tool runs on one until James has written its
spec, with a "Done when" list, in identity-stack's
`docs/superpowers/specs/`. Each feature then goes to whichever tool did best
on the runs above, and the note says why that one.

Stays with James: #476, #477, #411 to #418, #458, #376, #387, #324 (secrets,
live infra, blocked upstream).

## Notes format

One file per tool in agentic-ppp, `notes/track-2/<tool>.md`, with one entry
per run. Agents fill in the facts. James writes the first-person parts.

- **The job:** issue and PR links, Variation A or B.
- **How to use it for this:** the steps in order, with the exact prompt or
  command. **Setup:** what it took, how long, what broke.
- **Where it helped. Where it got in the way.**
- **When something failed:** where you looked and how long it took to
  explain. *(James)*
- **Review load:** lens rounds, and what James changed before merging.
- **Cost and wall time** for the job.
- **Use it for / don't use it for.** *(James)*

POC config goes under `pocs/track-2/<name>/`. PRs land in identity-stack.
Finished posts go to the separate personal-blog repo, not agentic-ppp.

## Order

Track 2 runs before Track 1. The order goes from least to most likely to
break:

1. Install and smoke-test each tool on GLM under the Track 2 key: one trivial
   prompt each, in a scratch directory. A tool that can't start is a finding;
   its runs drop and the note says why.
2. Variation B, plain pi on #480.
3. Variation B, Ralph on #478 then #481.
4. Variation B, pi-fabric on #406.
5. Variation B, durable-subagents on the alert triage.
6. Variation A, the two parallel loops on #474 and #475.
7. Variation A, Ralph with a durable-subagents implement step on #407.
8. Features, as James's specs land.
9. Posts drafted from the notes, one per tool.

## Decided by James

- Track 2 is practical use on real work, and runs before Track 1.
- Local tools first, not cloud sessions. identity-stack is the one repo.
- Two variations: each tool alone, and tools combined where they aren't
  redundant.
- Public repo agentic-ppp. James merges every PR.
- Notes in `notes/`, POC config in `pocs/`, posts in personal-blog.

## My calls (marked)

- *(My call)* Which issue each run gets, as in the tables.
- *(My call)* GLM for every run, matching Track 1.
- *(My call)* The alert triage proposes only, as decided for the earlier
  Security-tab triage.
- *(My call)* Features wait for James's specs and go to the best tool from
  the earlier runs.
- *(My call)* The weekly Dependabot routine is held with the cloud work.

## Left to the builder

- Each tool's config under `pocs/track-2/<name>/`.
- The watcher script's interval and report format.
- How the durable-subagents triage batches alerts (by rule, by file).
- Whether pi-ralph and pi-fabric load on pi 1.2.0: they name the core package
  differently (`@mariozechner/pi-coding-agent` against
  `@earendil-works/pi-coding-agent`). The smoke test tells.
