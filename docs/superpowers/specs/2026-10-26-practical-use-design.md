# agentic-ppp, Track 2: using agents on real work

## Intent and why

James wants agents to take as much low-risk, repetitive work as they can, so
he can spend his time on design. Track 2 tries each way of running agents on
real open issues in his own repos and writes down how it went. The work
getting done matters more than a fair comparison. Track 1 is the controlled,
like-for-like comparison and has its own design.

Each post is a how-to: "here's how you'd use X for Y, where it helped, where
it got in the way."

## Goals

- Real PRs land in identity-stack, terraform-provider-descope (TFD) and
  identity-stack-planning (ISP), through each repo's normal gates.
- Each technique gets the work it suits, and leaves a note a post can come
  from.
- A weekly cloud routine takes red Dependabot PRs off James's plate.
- One shared copy of the cloud launch and status scripts, for any repo.

## Non-goals

- Ranking the techniques, or giving each one real work. Where none fits,
  it stays in Track 1.
- Design work, live infrastructure, local secrets, credentialed end-to-end
  tests. These stay with James.
- identity-model. It's excluded on purpose: its work rests on James's own
  judgement.

## Anti-goals

- A new system James has to maintain. Every POC is removed by deleting its
  `pocs/<name>/` folder and stopping its processes or routine.
- Agents that merge. Machinery so opaque a failure can't be explained (if
  that happens, the note says so).
- Secrets in a cloud session, or an agent run holding repo secrets next to
  freshly bumped dependencies.

## Constraints

- **Cloud sessions hold no secrets.** Tests that need credentials run only in
  CI. A cloud session gets feedback from PR CI, the lens reviews and the Merge
  Gate. A PR comment wakes the session that owns the PR.
- **Cloud sessions don't load `~/.claude`,** so their rules live in the
  target repo's `AGENTS.md`. One file area per session.
- **Spend cap per run.** Cloud: at most four sessions at once across all
  repos, and the weekly routine opens at most three PRs per repo per run.
  Local pi runs: a dedicated OpenRouter key with its own limit, plus each
  tool's own budget where it has one.
- **Model: the best model for the job.** This is my guess; James hasn't
  contradicted it. Track 2 isn't a fair comparison, so there's no rule to use
  one model everywhere. Cloud sessions and the routine use the strongest
  Claude model offered. Local pi techniques use whatever model the tool runs
  well on, and the note records which.
- **Naming.** No client or outside project in any artifact. The public repos
  and tools named here are fine.
- **Git.** Worktree branches, conventional commits, squash-merged PRs to
  `main`, never force-push. Repo settings change only in oss-admin.

## Techniques and the work each gets

Cloud suits secret-free code and doc fixes that CI can check. Local suits
work that needs this machine, James's `gh` access or credentials.

| Technique | Work it gets | Why it fits |
| --- | --- | --- |
| Claude Code cloud sessions, one per issue (`cloud-launch.sh`) | identity-stack#480 (Node 22 floor), identity-stack#478 (stale Vault and Infisical doc refs), identity-stack#481 (pip-audit suppressions documented, forced re-check); ISP#126 (PR-time docs build) then ISP#127 (dependabot.yml for npm) | Small, well-specified, no secrets. CI says whether it worked. Different repos and file areas, so they run in parallel. |
| Cloud sessions on auth paths | identity-stack#474 with #406 (backend fail-open env reads), then identity-stack#475 with #407 (frontend fail-closed authority) | Well-specified, and fail-closed behaviour can be tested without secrets. One at a time, since they touch auth code. Red Team and Security lenses run on them. James reviews these closer than the rest. |
| Cloud session on James's open PR | TFD#229 (red on gosec), then TFD#109 (snake_case rename) after #229 merges | gosec findings are mechanical. The rename touches every file, so nothing else runs on TFD while it does. |
| Loop runs in the cloud, you monitor | The identity-stack batch above, run together | A dumb shell script on a timer (my call): it reads the pinned queue, launches the next issue with `cloud-launch.sh` when a slot frees, and prints `cloud-status.sh --all`. No agent, no judgement. Nothing runs locally between ticks. |
| pi supervisor over the cloud batch | The same kind of batch, later | The script above plus an agent's judgement: each tick, pi reads the status, classifies each PR (waiting, stuck, needs James), runs `gh pr update-branch` on `BEHIND` PRs, and reports the rest. The note answers whether the judgement earned its keep over the plain script. |
| Weekly Dependabot cloud routine | identity-stack#491 (py-identity-model `<5` breaks lint, unit tests, npm audit); TFD#230 (go-sdk 1.33 to 1.37 breaks build, lint, tests); alerts with no patch become issues | Recurring, repetitive, secret-free. Detail below. |
| purboo/pi-durable-subagents, local | ISP#66: triage about 189 Security-tab findings | Repetitive fan-out over many items, with a budget and a journal to resume from. Needs James's local `gh` access to the alerts, which a cloud session likely lacks. The run proposes. It doesn't dismiss alerts unless James says it may. |
| Cloud session doing tool research | An evaluation note on mikeyobrien/rho (pi wrapper with heartbeat daemon, memory, vault) as a watcher, and the same for any tool evaluation that comes up | Reading public repos and docs needs no secrets. The output is a note, landed as a PR to agentic-ppp. |
| Ralph web dashboard | None in Track 2 | identity-stack has `ralph.yml`, but every commodity issue here is better served by a cloud session. Ralph's local loops keep running as they are. Track 1 covers it. |
| mikeyobrien/pi-ralph | None in Track 2 | It only matters if Ralph runs locally on Track 2 work, and none does. Track 1. |
| fabric-runtime/pi-fabric | None in Track 2 | No real work here needs a durable runner more than durable-subagents covers ISP#66. Track 1. |

Work no agent needs: identity-stack#497, #505, #507, #508 and #509 are green
Dependabot PRs. James merges them. The routine's summary lists green ones so
they aren't missed.

Stays with James: identity-stack#476, #477, #411 to #418, #458, #385, #386,
#377, #378 and #387 (secrets, live infra, design, blocked). ISP#128 is local
machine cleanup.

TFD#238 and #239 aren't code work. They fail only in the upstream integration
tests, probably because Dependabot PRs don't get Actions secrets. A cloud
session can confirm that from the logs. The fix is James's call (see the
questions).

## Repo readiness

Kept to what each technique needs. Each repo gets one readiness PR, made by a
local agent in a worktree. James merges it before any session runs there.

**For cloud sessions and the routine (all three repos):**

- `AGENTS.md` with "Working an issue end to end" adapted from codecite:
  plan by hand, test-first, run what CI runs before each push, PR to `main`
  with `Closes #<n>` and provenance, answer the lenses, stop after three
  rounds, never merge, use the GitHub connector if `gh` isn't logged in.
  identity-stack has neither `AGENTS.md` nor `CLAUDE.md` at its root.
- TFD's `CLAUDE.md` tells the agent to `source .env` and run acceptance
  tests. The cloud has no `.env`. `AGENTS.md` must say: build, lint, gosec
  and unit tests locally; acceptance tests run in CI only.
- A SessionStart hook in `.claude/` that acts only when
  `CLAUDE_CODE_REMOTE=true` and installs the toolchain: uv and Node for
  identity-stack, Go, golangci-lint and gosec for TFD, Node for ISP.
- A `cloud-ready` label, a pinned queue issue giving the order and what can
  run in parallel, and a "Done when" checklist on each labelled issue, with
  a stated default wherever a design call is needed.
- ISP has no PR CI, so ISP#126 goes first: without it, a session there gets
  no feedback. ISP also has no lens review workflow. Adding `claude.yml`
  there is an oss-admin and repo change, left to James.
- A claude.ai/code environment per repo, network Trusted, no variables or
  secrets.

identity-stack's backend tests start services with `docker compose` in CI.
If the cloud machine can't run Docker, sessions there run the unit tests they
can and leave the rest to CI. The first session tells.

**For the local techniques:** nothing in the target repo. Config lives in
`pocs/<name>/`, and runs use worktrees beside the repo's existing ones.

## The weekly Dependabot routine

A scheduled Claude Code cloud routine, once a week, with no repository
secrets. Its prompt and setup live in `pocs/dependabot-routine/`. For each of
identity-stack and TFD (and ISP once ISP#127 lands):

1. List open Dependabot PRs. Sort them into green, red, and red only on
   secret-gated jobs.
2. For each red PR, up to three per repo: branch from `main`, apply the bump,
   adapt the code until build, lint and unit tests pass, and open a PR
   through the normal gates. The body says which Dependabot PR it supersedes.
   Dependabot closes its own PR once the bump reaches `main`.
3. For each alert with no patched version, file an issue, unless one already
   exists.
4. Post one summary: green PRs ready for James, PRs opened, issues filed, and
   anything skipped and why.

Not the `@claude` workflow: it ignores bot comments, and would run an agent
holding repo secrets on freshly bumped dependencies, the risk zizmor flags.
The fix PR is a same-repo branch, so its CI gets Actions secrets, unlike
Dependabot's own PR. That's the same exposure as James pushing the bump
himself, and dependency-review and OSV-Scanner run on it as on any PR.

Unknown: whether the cloud GitHub connection can read Dependabot alerts. The
first run tells. If not, it works from red PRs only and step 3 drops out.

**Seeing its PRs through review (my call).** A routine run can't be woken by
a PR comment the way a session can. So within each run, after opening its
PRs, the routine waits for the first CI and lens round on each, fixes what
it can once, and then ends. Each run begins by working its own still-open
red PRs before looking at new Dependabot PRs. If James wants one sooner, he
hands it to a session with `cloud-launch.sh`.

**One routine or several (builder verifies).** The design assumes one
routine can reach identity-stack, TFD and agentic-ppp. The builder checks
this when setting it up. If a routine is tied to one repo, it becomes one
routine per repo, each posting its summary on a pinned issue in its own
repo.

## Notes format

One file per technique in agentic-ppp, `notes/<technique>.md`, with one
entry per piece of work. Agents fill in the facts. James writes the
first-person parts.

- **The job:** repo, issue, PR links.
- **How to use it for this:** the steps in order, with the exact prompt or
  command. **Setup:** what it took, how long, what broke.
- **Where it helped. Where it got in the way.**
- **When something failed:** where you looked and how long it took to
  explain. *(James)*
- **Review load:** lens rounds, and what James changed before merging.
- **Cost and wall time** for the job.
- **Use it for / don't use it for.** *(James)*

POC config goes under `pocs/<name>/`. PRs land in the real repos. Finished
posts go to the separate personal-blog repo, not agentic-ppp.

## Shared cloud scripts

Move `cloud-launch.sh` and `cloud-status.sh` from codecite into
agentic-ppp `scripts/`, taking the repo as the first argument:

```
scripts/cloud-launch.sh identity-stack 480 478
scripts/cloud-status.sh identity-stack            # open PRs on one repo
scripts/cloud-status.sh --all                     # every repo in the list
```

The prompt names the repo. The session log moves to
`~/.local/state/agentic-ppp/` and records the repo. The Merge Gate and eval
columns show only where a repo has them. A codecite PR drops its copies and
points `docs/cloud-sessions.md` here.

## Order and first slice

Track 2 runs before Track 1.

**First slice, shipping real work within days:**

1. agentic-ppp scaffold PR: `notes/`, `pocs/`, the shared scripts.
2. Readiness PRs for identity-stack and ISP. James merges them and sets up
   their claude.ai/code environments.
3. Launch cloud sessions on identity-stack#480, #478 and #481 and ISP#126 at
   once. Watch with `cloud-status.sh --all`. Meanwhile James merges the five
   green Dependabot PRs.
4. Notes for the first two techniques: cloud sessions, and loop-in-the-cloud
   watching.

**Then:**
5. TFD readiness PR, then the first weekly routine run on identity-stack#491
   and TFD#230.
6. identity-stack#474 with #406, then #475 with #407, one at a time.
7. TFD#229, then TFD#109.
8. pi supervisor over a cloud batch, ISP#127 and the rho research note.
9. ISP#66 on pi-durable-subagents, locally.
10. Posts drafted from the notes, one per technique.

## Decided by James

- Track 2 is practical use on real work, and runs before Track 1.
- Public repo agentic-ppp. James merges every PR. No secrets in the cloud.
  identity-model is out.
- The weekly Dependabot routine as described, not the `@claude` workflow.
- Notes in `notes/`, POC config in `pocs/<name>/`, posts in personal-blog.

## My calls (marked)

- *(My call)* Ralph web, pi-ralph and pi-fabric get no Track 2 work.
- *(My call)* The auth-path issues run one at a time, after the doc fixes.
- *(My call)* The pi supervisor's only allowed fix is `gh pr update-branch`.
- *(My call)* Spend caps: four cloud sessions at once; three routine PRs per
  repo per run; a separate Track 2 OpenRouter key from Track 1's, with a $30
  limit, about $10 per local run.
- *(My call)* The routine's summary is one comment on a pinned issue in
  agentic-ppp, since it spans repos.
- *(My call)* The ISP#66 run proposes dispositions and does not dismiss
  alerts, unless James says otherwise.

## Left to the builder

- Wording of each `AGENTS.md` section and each "Done when" checklist.
- The setup hooks' exact install steps and versions.
- The routine's prompt, and how it tells "red only on secret-gated jobs"
  apart from real failures.
- The pi supervisor's timer and report format.
- How the ISP#66 workflow batches findings (by rule, by file).
- Whether TFD's `renovate.json`, which extends the upstream's config, does
  anything. If Renovate isn't installed, note it and leave it.

## Answered by James (2026-10-26)

1. identity-stack#491: the weekly routine tries the py-identity-model 4
   adaptation; James reviews that PR closely.
2. TFD#229: a cloud session may push gosec fixes to James's branch.
3. TFD#238 and #239: skip the secret-gated integration jobs on Dependabot
   PRs (a TFD workflow change), rather than add Dependabot secrets.
4. ISP#66: the local run proposes dispositions only; it never dismisses
   alerts.
