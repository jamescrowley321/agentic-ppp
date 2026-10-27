# agentic-ppp Track 1: honest, objective evaluation

## Intent and why

James runs autonomous Ralph loops over GitHub issues. The loops work.
Watching them doesn't: finding the stuck one means flipping tmux windows.

agentic-ppp is a new public repo about ways of running coding agents. It has
two tracks. This is Track 1: run each setup on the same sandbox, the same
tasks and the same model, so the tools are the only thing that changes. The
output is honest comparison blog posts.

Track 2 is a separate design. It covers subjective, how-to-use write-ups on
real work in James's other repos, where a fair comparison matters less.
Nothing in Track 1 runs outside the sandbox, and nothing in Track 2 is built
here.

This carries over the 2026-10-20 loop lab design. What changed: the repo is
agentic-ppp, the sandbox is a subfolder of it, and two cloud setups join.

## Goals

- Run the same loop on the same tasks under seven setups (listed below).
- Run two loops at once in every setup, because the pain is seeing *which*
  loop is stuck.
- Start every setup from the same tagged commit with the same open issues.
- Use GLM through OpenRouter for every setup that can run it.
- Capture the same notes for each setup, so they go straight into a post.
- Publish the results as blog posts that say plainly what was and wasn't
  controlled.

## Non-goals

- Picking a replacement for Ralph. James's real loops stay as they are.
- Production quality. POCs are thin and readable, with no tests beyond what
  the sandbox tasks need.
- Patching any of the tools. If a tool falls short, write it down.
- Anything Track 2 covers: real repos, real issues, personal workflow advice.

## Anti-goals

- Anything that touches the real loops, their worktrees or their state files.
- Anything outside the sandbox: no real repo, no real issue, no real PR.
- A new system James has to maintain. Each POC is removed by deleting its
  directory and stopping its processes.
- Machinery so opaque that a failure can't be explained. If that happens, the
  post says so.

## Constraints

- **Model:** the newest GLM listed on OpenRouter, for setups 1 to 5,
  including the Ralph baseline (`backend: pi` on each role). Setups 6 and 7
  run Claude; see "The model rule and the cloud setups" below.
- **Spend:** a dedicated OpenRouter key with a small limit, minted in
  oss-admin Terraform like the codecite evals key (an `openrouter_api_key`
  resource; James merges the PR and confirms the TFC run). Stored at
  `~/.config/agentic-ppp/env` (mode 0600), never printed, never committed.
  pi reaches it by extending `~/.config/codecite/pi-openrouter-key.sh` to
  return this key when pi starts under the agentic-ppp paths, so James's
  everyday pi use is unaffected. Use each tool's own budget too where it has
  one (`usageBudget.costUsd` in durable-subagents). Limits: see "Runs and
  budget" below. Track 1 gets its own key, separate from Track 2's, so its
  cost figures stay clean (my call).
- **Cloud spend:** cloud sessions bill to James's Claude plan, not the key,
  and have no dollar cap. My call: cap them by count instead. One session
  per issue, at most one queue's worth (6) per loop, and a wall-clock limit
  per run (4 hours). The notes record the usage the plan shows.
- **Git:** feature branches in worktrees under
  `~/repos/auth/agentic-ppp-worktrees/`, conventional commits, squash-merged
  PRs, James merges. Repo settings in oss-admin (`terraform/agentic-ppp`),
  never the GitHub UI. Never force-push.
- **Names:** name no client or outside project, except the public tools
  being evaluated.
- **Versions:** record each tool's version per run. pi-ralph was tested
  against Ralph 2.4.4 (the machine has 2.10.1); expect breakage, record it.
- **Durable-subagents gotchas:** `maxCalls` defaults to 300; set
  `"onQuit": "continue"`; mark shipping `once: true`; use `revise` and `prune`.

## The setups

1. **Ralph web dashboard** (`ralph web`), used as it comes. The baseline.
2. **pi supervisor over Ralph.** Ralph runs the loops. A pi check on a timer
   looks at every loop, restarts crashed ones, applies safe fixes and reports
   the rest.
3. **mikeyobrien/pi-ralph:** Ralph's TUI inside pi, with a `/ralph` overlay
   across loops.
4. **purboo/pi-durable-subagents:** the loop ported to a workflow script plus
   agent files.
5. **fabric-runtime/pi-fabric:** the loop on fabric's durable runner and
   supervisor skill.
6. **Claude Code cloud session, by hand.** James starts one cloud session per
   issue (`claude --cloud`), one queue each, and watches them at
   claude.ai/code. He is the orchestrator. Based on codecite's
   `docs/cloud-sessions.md` and `scripts/cloud-launch.sh`.
7. **Loop in the cloud, watched locally.** A small local script dispatches
   cloud sessions, one issue at a time per queue, and watches their PRs, as
   codecite's `scripts/cloud-status.sh` does. James watches the script's
   table, not the sessions.

### The model rule and the cloud setups

Cloud sessions run Claude, not GLM. So setups 6 and 7 break the rule that
makes the comparison fair. My call:

- **The controlled comparison is setups 1 to 5.** All GLM. The first post
  covers only these.
- **Setups 6 and 7 are a second comparison.** Same sandbox, same tasks, same
  traps, same notes, but every table and chart marks them "Claude, not GLM".
  The second post compares 6 and 7 with each other, and with the baseline
  only on things the model doesn't drive: setup steps, how a stuck loop is
  spotted, what survives a crash, how a failure is explained. Pass rate,
  cost and wall time are not compared across models.
- Use the cloud's default Claude model and record its name (my call).

Whether to add a bridge run is a call for James (see the open questions).

## The sandbox

- **Where:** a subfolder of agentic-ppp, `sandbox/` (my call on the name).
  Clone at `~/repos/auth/agentic-ppp`. POC code under `pocs/<name>/`, raw
  notes under `notes/`.
- **What:** a small project a GLM-class model can finish quickly, with a fast
  test suite. The builder picks the language; Python or Go fits James's
  other repos.
- **Two task queues,** one per loop. Each is 4 to 6 made-up issues under its
  own label (`lab-queue-a`, `lab-queue-b`). The issue texts live as files in
  `sandbox/issues/`, so they are the same every time. Each queue has the same
  traps:
  - a **flaky test** that fails some of the time in CI;
  - a **merge conflict:** two issues that touch the same lines, so the second
    needs a rebase;
  - a **vague issue** that can't be finished without a question, so it should
    park or block;
  - a **hard stop,** such as a task that needs a secret that doesn't exist,
    which can only end blocked. The codecite loop halts on `blocked`, so this
    is the last issue in each queue.
- **Lab base branches, not main (my call).** The loops' PRs, and the merge
  that fires the conflict trap, must not change `main`, which holds the real
  POC work and needs James to merge. So each run gets its own base branch,
  `lab/<setup>-base`, cut from the tag `sandbox-v1`. Loop branches are
  `lab/<setup>/<queue>/...`, and every loop PR targets its run's base. `main`
  never gets a lab commit. oss-admin leaves `lab/**` unprotected, and CI and
  the review workflow run on PRs to `lab/**`.
- **The tag holds only the sandbox.** `sandbox-v1` is cut before any POC
  lands, so a loop's worktree sees the project, its CI and its issues, and
  never another setup's code or notes.
- **Firing the conflict:** the loop never merges, so the conflict needs a
  merge mid-run. After the second PR in a queue opens, a script squash-merges
  the first one into the run's base with an edit to the same lines, so the
  next rebase conflicts. Same rule in every setup. This is the one merge not
  made by James, and it only ever lands on a `lab/` base.
- **Two loops, one repo:** both queues share the repo and its CI. Each loop
  has its own runner worktree and state directory, keyed by queue. The
  shared CI queue is accepted and noted.
- **Review is the blind-peer-review lens workflow** (`claude.yml`, copied
  from codecite into the sandbox before the tag), on agentic-ppp's own capped
  OpenRouter lens key, which oss-admin#33 mints. The reviewer is the same for
  every setup, so it doesn't skew the comparison. Its cost isn't counted per
  run. If CI doesn't review, the loop waits, then carries on without a
  review, and the notes say so (my call).

### Scoring (my call, fixed before any run)

Each issue ends in exactly one outcome, recorded in the notes:

- **Shipped:** PR open against the run's base, CI green, lens verdict with no
  MUST FIX left.
- **Parked right:** the vague issue gets a question on the issue, is parked,
  and the loop moves on to the next issue. Blocking on it is scored
  **stopped early**, because it ends the queue.
- **Blocked right:** the hard stop ends blocked, naming the missing secret.
  It's last in each queue, so blocking there costs nothing.
- **Recovered:** the flaky test is retried or explained, not "fixed" by
  deleting it; the conflict is resolved by restack and the PR goes green.
- **Failed:** anything else, including hitting the run's spend cap.

### Runs and budget (my call)

- One measured run per setup. A run broken by the tool itself (install
  failure, version mismatch) is re-run once after the fix is noted; a run
  that fails on the work is reported as it happened.
- A run that reaches its $10 cap stops and the open issues score **failed**.
- Crash tests (`kill -9`, simulated reboot) run in a separate short run on
  one queue, so they don't skew the measured run's cost or wall time.
- Total Track 1 limit $100: five measured runs, up to five re-runs and the
  crash runs.
- **Reset between runs:** a script that closes the last run's PRs, deletes
  its `lab/<setup>` branches, closes its issues as not planned, and creates
  fresh issues from `sandbox/issues/` for the next run. Fresh issues, not
  reopened ones, so no setup reads another's comments (my call). Issues refer
  to each other by title, since numbers change. The script touches only
  `lab-` labels and `lab/` branches.
- **Cloud environment:** once, James installs the Claude GitHub App on
  agentic-ppp and makes a Trusted-network environment with no secrets.

## The loop being ported

Base it on the codecite loop (`~/repos/codecite/ralph/`): a router
`PROMPT.md` plus phase files (`restack → setup → plan → implement → pr → ci
→ review → review-fix → complete`), state files for the current issue and
phase, the PR stack and parked issues, and stacked PRs it never merges. Copy
it into `pocs/` and trim it: drop the codecite parts, keep the phases.

- **Setups 1 to 5** run on GLM in pi with no Claude Code skills. Replace the
  superpowers and `blind-peer-review` steps with plain instructions. Drop
  the local review fallback.
- **Setups 6 and 7** port the loop into one prompt for a cloud session:
  "work this issue end to end" from codecite's `AGENTS.md`, trimmed the same
  way. A session works one issue and doesn't stack, so the restack phase
  becomes "rebase your PR when its base moves". The prompt lives in
  `pocs/cloud-*/`, not in a repo-level `AGENTS.md`, because pi would load
  that file too and change setups 1 to 5 (my call).

- **Stacking:** setups 1 to 5 keep the codecite loop's stacked PRs: the
  first PR in a queue targets the run's base, each later one targets the PR
  before it. The conflict trap then fires through the restack phase. Setups
  6 and 7 don't stack; every PR targets the run's base, and the same trap
  fires through an ordinary rebase. The second post says so (my call).
- **Faithful, not idiomatic:** each port keeps the phases, state files and
  stacking as directly as the tool allows (carried over from the 2026-10-20
  design). Where the tool forces a change, the note records it.

How much each port had to change is one of the things the posts report.

## Per-setup notes

For each setup, keep `notes/<setup>.md` with:

- **Setup:** steps, time, what broke, versions, model.
- **Port:** what changed from the Ralph loop; lines of code or config.
- **Spotting the stuck loop:** with two loops running and one trap firing,
  how you find out which loop needs you, and how long it takes.
- **When it breaks:** what happens on each trap; on a `kill -9` of the
  orchestrator mid-build; and on a simulated reboot (kill every lab process
  and its tmux server, then relaunch as a login would). For setup 6 there is
  nothing local to kill, so the test is: close the terminal and go offline
  for an hour. For setup 7, kill the local script. A real reboot happens
  only if James chooses, while his real loops are idle.
- **Understanding a failure:** where you look and how long it takes to
  explain what went wrong.
- **Cost and wall time** for the queue (plan usage for 6 and 7).
- **Would I use it again, and for what?**

Agents fill in the facts: setup steps, versions, cost, wall time, what broke.
James writes the first-person parts: spotting, reading failures, "would I use
it again". Each POC's build ends with a run checklist James can follow.

## Order

1. oss-admin: #33 adopts the repo and mints its lens key. A follow-up PR
   mints the Track 1 OpenRouter key, and adds branch protection on `main`
   once CI exists, leaving `lab/**` unprotected. Steps after this wait on
   James's merge and TFC confirm.
2. Sandbox, issue files, traps, reset script, tag `sandbox-v1`.
3. Setup 1, Ralph web (baseline).
4. Setup 2, pi supervisor over Ralph.
5. Setup 3, pi-ralph.
6. Setup 4, pi-durable-subagents.
7. Setup 5, pi-fabric.
8. First post: the GLM comparison, setups 1 to 5.
9. Cloud environment (James, once), then setup 6.
10. Setup 7.
11. Second post: the cloud setups, marked as a different model.

Each POC is its own PR in agentic-ppp, with its code under `pocs/<name>/`
and its notes under `notes/`. Each post is an ordinary PR to James's
personal-blog repo (Docusaurus, publishes on merge), not in agentic-ppp.

## Decided by James

- The public repo agentic-ppp, named for Robert C. Martin's "Agile
  Principles, Patterns, and Practices in C#" (the README defines the
  short-hand), cloned in `~/repos/auth/agentic-ppp`, settings in
  `terraform/agentic-ppp`. The sandbox is a subfolder of it.
- Two tracks; Track 1 is this design and stays in the sandbox.
- Two queues with the four traps, a reset script, one tagged commit.
- GLM through OpenRouter for every setup that can run it, on a dedicated
  key with a limit, minted in oss-admin.
- Cloud sessions join as setups 6 and 7.
- Posts go to the personal-blog repo as PRs. James merges every PR.

## Left to the builder

- The sandbox project's language and contents.
- The wording of the tasks and how each trap is built.
- The supervisor in setup 2. Suggested shape: a one-shot pi call from cron
  that gathers state, classifies each loop, fixes only safe things, never
  edits prompts, and reports the rest.
- The dispatcher in setup 7. Suggested shape: a short script on a timer that,
  per queue, launches the next issue's session once the last PR has a review
  verdict, and prints one table row per PR. Dumb on purpose.
- How each tool is installed. Prefer the sandbox or user scope. If a global
  change to pi is unavoidable, note it and how to undo it.

## Bridge run (my call: yes)

One extra run of the Ralph baseline on Claude (`backend: claude`), so the
second post can compare the cloud setups with a local loop on the same
model. Without it, setups 6 and 7 can only be compared on model-free
points.
