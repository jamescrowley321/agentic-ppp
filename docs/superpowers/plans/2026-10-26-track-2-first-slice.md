# Track 2 First Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up agentic-ppp with shared cloud scripts, make identity-stack, identity-stack-planning (ISP) and terraform-provider-descope (TFD) ready for Claude Code cloud sessions, ship the first four issues through cloud sessions under a dumb launch loop, and run the weekly Dependabot routine for the first time.

**Architecture:** agentic-ppp holds everything reusable: `scripts/` (repo-aware `cloud-launch.sh` and `cloud-status.sh`, driven by `scripts/repos.tsv`) and removable POCs under `pocs/track-2/<name>/` (the cloud loop's timer-driven tick, the routine's prompt). Each target repo gets one readiness PR (AGENTS.md, a SessionStart hook that acts only when `CLAUDE_CODE_REMOTE=true`) plus GitHub-side setup (`cloud-ready` label, pinned queue issue, "Done when" checklists). Cloud sessions and the routine get feedback only from PR CI, the lenses and the Merge Gate; James merges everything.

**Tech Stack:** Bash 5, `jq`, `gh`, `claude --cloud`, util-linux `script`, systemd user timers, GitHub Actions (shellcheck, zizmor), plain-bash tests (no bats: it isn't installed here and adds a CI install step for no gain).

**Spec:** `docs/superpowers/specs/2026-10-26-practical-use-design.md` (Track 2; its "Answered by James (2026-10-26)" section is binding). Boundary context: `docs/superpowers/specs/2026-10-26-objective-evaluation-design.md` (Track 1).

## Global Constraints

- **Cloud sessions hold no secrets.** Tests that need credentials run only in CI.
- **Cloud sessions don't load `~/.claude`,** so their rules live in the target repo's `AGENTS.md`. One file area per session.
- Cloud: at most four sessions at once across all repos; the weekly routine opens at most three PRs per repo per run.
- Cloud sessions and the routine use the strongest Claude model offered; the note records which.
- **Naming.** No client or outside project in any artifact. The public repos and tools named in the spec are fine.
- **Git.** Worktree branches, conventional commits, squash-merged PRs to `main`, never force-push (fetch before push). Repo settings change only in oss-admin.
- Agents never merge. James merges every PR.
- Every POC is removed by deleting its `pocs/track-2/<name>/` folder and stopping its processes or routine.
- Every PR body: `Closes #<n>` where an issue exists, the acceptance criteria, and an `## AI provenance` section naming harness `Claude Code` and the model, with `- [x] A human has reviewed this change and is accountable for it` ticked (James has delegated the tick for agent PRs).
- Before every push, run what that repo's CI runs (each task lists the commands).
- Not the `@claude` workflow for Dependabot fixes; no Dependabot secrets (TFD#238/#239 are fixed by skipping the secret-gated jobs on Dependabot PRs).
- identity-model is out of scope.
- Worktrees: agentic-ppp under `~/repos/auth/agentic-ppp-worktrees/`; codecite under `~/repos/codecite-worktrees/`; identity-stack under `~/repos/auth/identity-stack-worktrees/`; TFD under `~/repos/auth/terraform-provider-descope-worktrees/`; ISP under `/tmp/isp-<branch>` (ISP's own CLAUDE.md: never inside a git-ignored path). Primary checkouts stay on a clean `main`.

## Review Focus

1. **A clone not on `main`.** `claude --cloud` runs from the repo's primary checkout; if that checkout sits on another branch, a session could start from the wrong base. `cloud-launch.sh` refuses with `clone at <path> is on <branch>, not main` (test in Task 1b).
2. **A hand-edited `repos.tsv`** with comments, blank lines, trailing spaces or CRLF line endings. Lookups still work and unknown names still fail cleanly (test in Task 1b).
3. **`gh` failing mid-tick** (rate limit, expired auth under systemd). The loop can't count slots, so it launches nothing and exits 1, rather than overshooting the cap of four (test in Task 5).
4. **A session that never opens a PR** holds its slot forever. Removing the issue's `cloud-ready` label frees it (test in Task 5; documented in `pocs/track-2/cloud-loop/README.md`).
5. **A queue issue James edited by hand**: no `## Order` heading, prose refs like `oss-admin#32`, PR numbers, refs under `## Not cloud-ready`. Only same-repo open `cloud-ready` issues listed under `## Order` launch; a missing section warns and launches nothing for that repo (tests in Task 5).

---

## File Structure

agentic-ppp (all new):

| Path | Responsibility |
| --- | --- |
| `README.md` | Full name, short form, the two tracks, layout |
| `AGENTS.md`, `CLAUDE.md` | Repo rules; `CLAUDE.md` is `@AGENTS.md` so cloud sessions load them |
| `docs/superpowers/specs/2026-10-26-{practical-use,objective-evaluation}-design.md` | The two designs, frozen once merged |
| `docs/superpowers/plans/2026-10-26-{track-2-first-slice,track-1-sandbox-and-baseline}.md` | The two plans |
| `notes/README.md` | The notes format from the spec; says Track 1 writes under `notes/track-1/` and Track 2 under `notes/track-2/` |
| `pocs/README.md` | POC rule: one folder each, under `pocs/track-1/` or `pocs/track-2/`, removal steps in its README |
| `scripts/repos.tsv` | The repo list: name, slug, clone path, features |
| `scripts/lib/repos.sh` | Reads `repos.tsv` |
| `scripts/cloud-launch.sh`, `scripts/cloud-status.sh` | Shared cloud scripts |
| `scripts/tests/{run.sh,lib.sh,stubs/claude,stubs/gh,fixtures/,test-*.sh}` | Plain-bash tests |
| `.github/workflows/ci.yml` | Jobs `shellcheck`, `script-tests`, `zizmor` |
| `pocs/track-2/cloud-loop/` (Task 5) | `tick.sh`, `queues.txt`, systemd units, install/uninstall, tests, README |
| `pocs/track-2/dependabot-routine/` (Task 9) | `prompt.md`, `README.md` |
| `notes/track-2/cloud-sessions.md`, `notes/track-2/cloud-loop.md`, `notes/track-2/dependabot-routine.md` (Tasks 7, 10) | Technique notes |

Target repos: `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`, `.claude/hooks/cloud-setup.sh` in each; TFD also `.gitignore` and `.github/workflows/ci.yml`; ISP also `.github/PULL_REQUEST_TEMPLATE.md`. codecite: delete `scripts/cloud-*.sh`, edit `docs/cloud-sessions.md`.

---

## Task 1: agentic-ppp's first PR

One branch, `feat/scaffold`, in `~/repos/auth/agentic-ppp-worktrees/feat-scaffold`, one PR opened at the end of 1d. Parts 1a–1d are separate commits, each with its own check. Track 1's plan assumes this PR exists.

### Task 1a: Scaffold and docs

**Files:**
- Create: `README.md` (replace GitHub's starter), `AGENTS.md`, `CLAUDE.md`, `notes/README.md`, `pocs/README.md`, the two specs, the two plans

**Interfaces:**
- Produces: the paths above. `notes/track-2/<technique>.md` is the notes location; `pocs/track-2/<name>/README.md` must carry a "Remove it" section.

- [ ] **Step 1: Create the worktree**

```bash
cd ~/repos/auth/agentic-ppp && git fetch origin && git pull --ff-only
git worktree add -b feat/scaffold ~/repos/auth/agentic-ppp-worktrees/feat-scaffold origin/main
```

- [ ] **Step 2: Copy the designs and plans**

From `docs/superpowers/specs/`: both `*-design.md` into `docs/superpowers/specs/`; `plans/2026-10-26-track-2-first-slice.md` and `plans/2026-10-26-track-1-sandbox-and-baseline.md` into `docs/superpowers/plans/`. If the Track 1 plan is not there, stop and ask; don't write a placeholder. Copy them unchanged.

- [ ] **Step 3: Write `README.md`**

First line exactly `# Agentic Principles, Patterns, and Practices`. Must say: a nod to Robert C. Martin's "Agile Principles, Patterns, and Practices in C#"; `agentic-ppp` is the short form; Track 1 (controlled, like-for-like comparison of agent setups on a sandbox in this repo) and Track 2 (practical use on real issues in James's own public repos, written up as how-tos); the layout table above; finished posts go to James's personal-blog repo, not here. No other project names.

- [ ] **Step 4: Write `AGENTS.md` and `CLAUDE.md`**

`CLAUDE.md` is the single line `@AGENTS.md`. `AGENTS.md` wording is the builder's; required sections:

1. **What this is** — two tracks, pointing at the specs.
2. **Where things live** — the layout table.
3. **Git** — worktree under `~/repos/auth/agentic-ppp-worktrees/` (a cloud session uses its own checkout); `<type>/<short-description>` branches; conventional commits; squash-merged PRs to `main`; never force-push, fetch before push; James merges, never merge your own PR; settings live in oss-admin `terraform/agentic-ppp`.
4. **Rules for every artifact** — name no client or outside project (the public repos and tools in the specs are fine; anything else is "another project"); no secrets or keys in the repo (keys live in `~/.config/agentic-ppp/`); every PR body has an AI provenance section naming harness and model and the ticked `- [x] A human has reviewed this change and is accountable for it` box; no status words in docs, status lives in GitHub issues; specs and plans are frozen once merged.
5. **Notes** — format per `notes/README.md`; agents fill facts and leave the *(James)* parts as a `*(James)*` placeholder line.
6. **POCs** — one folder `pocs/track-2/<name>/`; its README says how to run it and how to remove it.
7. **Before every push** — `shellcheck scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh pocs/*/*.sh`, `scripts/tests/run.sh`, `pocs/track-2/cloud-loop/tests/run.sh` once it exists, `uvx zizmor@1.31.1 .github/workflows/`.
8. **Working an issue end to end** — adapted from codecite: pick, plan by hand in the PR body, test-first, run the pre-push list, PR to `main` with `Closes #<n>` and provenance, answer review, stop after three rounds with a summary comment, never merge; if `gh` isn't logged in, use the GitHub connector tools.

- [ ] **Step 5: Write `notes/README.md` and `pocs/README.md`**

`notes/README.md` lists the spec's notes fields in order: The job; How to use it for this (+ Setup); Where it helped / Where it got in the way; When something failed *(James)*; Review load; Cost and wall time; Use it for / don't use it for *(James)*. `pocs/README.md`: the POC rule and removal rule, one paragraph.

- [ ] **Step 6: Check naming and status words**

Run: `grep -rniE '\b(pending|done|blocked|in progress)\b' README.md AGENTS.md notes pocs`
Expected: no output. Also read every new file once for names of clients or outside projects; expected none.

- [ ] **Step 7: Commit**

```bash
git add README.md AGENTS.md CLAUDE.md notes pocs docs
git commit -m "docs: scaffold agentic-ppp with both designs, plans and repo rules"
```

### Task 1b: Repo list and `cloud-launch.sh`

**Files:**
- Create: `scripts/repos.tsv`, `scripts/lib/repos.sh`, `scripts/cloud-launch.sh`
- Test: `scripts/tests/run.sh`, `scripts/tests/lib.sh`, `scripts/tests/stubs/claude`, `scripts/tests/stubs/gh`, `scripts/tests/test-repos.sh`, `scripts/tests/test-cloud-launch.sh`

**Interfaces:**
- Consumes: codecite's `scripts/cloud-launch.sh` (port its `script`/`timeout 120`/URL-scrape logic and its "not an issue number" and "listed twice" behaviour).
- Produces:
  - `scripts/repos.tsv`: tab-separated `name  slug  clone  features`, `#` comments, `~` allowed in `clone`, `features` a comma list of `gate`, `eval`, or `-`. Rows, in this order:
    - `codecite  jamescrowley321/codecite  ~/repos/codecite  gate,eval`
    - `identity-stack  jamescrowley321/identity-stack  ~/repos/auth/identity-stack  gate`
    - `terraform-provider-descope  jamescrowley321/terraform-provider-descope  ~/repos/auth/terraform-provider-descope  gate`
    - `identity-stack-planning  jamescrowley321/identity-stack-planning  ~/repos/auth/identity-stack-planning  -`
    - `agentic-ppp  jamescrowley321/agentic-ppp  ~/repos/auth/agentic-ppp  -`
  - `scripts/lib/repos.sh` (sourced): `repos_file` (prints `$AGENTIC_PPP_REPOS` or `<scripts>/repos.tsv`), `repo_names` (names in file order), `repo_slug <name>`, `repo_clone <name>` (tilde-expanded), `repo_has <name> <gate|eval>` (exit 0/1). Unknown name: prints nothing, returns 1. Strips `\r` and trailing whitespace.
  - CLI: `scripts/cloud-launch.sh <repo> <issue> [<issue> ...]`. Exit 2 on usage errors (no args, unknown repo, missing clone, clone not on `main`, more than 4 issues); exit 1 if any single launch failed; 0 otherwise.
  - Prompt, exactly: `Work jamescrowley321/<repo>#<n> per AGENTS.md 'Working an issue end to end'` (slug from `repos.tsv`), run as `claude --cloud "<prompt>"` with the clone as working directory.
  - stdout per launch: `<repo>#<n>: <url>`. Log line appended to `${AGENTIC_PPP_CLOUD_LOG:-$HOME/.local/state/agentic-ppp/cloud-sessions.log}`: `<UTC ISO time> <repo>#<n> <url>`.
  - Test harness: `scripts/tests/run.sh` runs every `scripts/tests/test-*.sh`, each of which defines `test_*` functions; prints `PASS <name>` / `FAIL <name>: <why>` and finally `<p> passed, <f> failed`; exits non-zero on any failure. `lib.sh` gives `assert_eq`, `assert_contains`, `assert_not_contains`, `assert_status`, and a per-test temp dir `$T` with `PATH="$stubs:$PATH"`.
  - Stub `claude`: appends `$PWD|$*` to `$STUB_CALLS`; prints `$STUB_CLAUDE_OUTPUT` if set, else `Created session https://claude.ai/code/session_abc123`.
  - Stub `gh`: appends its args to `$STUB_CALLS`; serves `$STUB_FIXTURES/<repo-name>/<key>.json` where key is `pr-list`, `pr-<n>`, `pinned`, `cloud-ready`, `issue-<n>` (repo name taken from the `-R` slug); exits 1 if `$STUB_FIXTURES/<repo-name>/fail` exists; applies `-q`/`--jq` expressions with `jq -r`.

- [ ] **Step 1: Write the failing tests**

`test-repos.sh` (each test writes its own `repos.tsv` into `$T` and sets `AGENTIC_PPP_REPOS`):

```bash
test_lookup_slug_and_clone()   # repo_slug identity-stack == jamescrowley321/identity-stack; repo_clone expands ~ to $HOME
test_comments_blank_crlf()     # file with '# c', blank line, CRLF and trailing spaces: repo_names prints exactly the two names
test_unknown_repo()            # repo_slug nope -> status 1, empty output
test_features()                # repo_has codecite eval -> 0; repo_has identity-stack eval -> 1; '-' means none
```

`test-cloud-launch.sh` (clone dirs are `git init -b main` repos in `$T`; log at `$T/log`):

```bash
test_usage_no_args()           # status 2, stderr contains "usage: cloud-launch.sh <repo> <issue>"
test_unknown_repo_refused()    # cloud-launch.sh nope 1 -> status 2, stderr "nope: not in"; STUB_CALLS empty
test_missing_clone_refused()   # status 2, stderr "clone not found at"
test_clone_not_on_main()       # clone on branch feat/x -> status 2, stderr "is on feat/x, not main"; claude not called
test_more_than_four_refused()  # 5 issues -> status 2, stderr "at most 4 sessions per launch"; claude not called
test_runs_in_clone_with_repo_prompt()
  # STUB_CALLS == "<clone>|--cloud Work jamescrowley321/identity-stack#480 per AGENTS.md 'Working an issue end to end'"
  # stdout == "identity-stack#480: https://claude.ai/code/session_abc123"
test_log_records_repo()        # log matches ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z identity-stack#480 https://claude.ai/code/session_abc123$
test_non_numeric_skipped()     # args 480 x1 -> status 1, stderr "identity-stack#x1: not an issue number", 480 still launched
test_duplicate_launched_once() # args 480 480 -> claude called once, stderr "listed twice"
test_no_url_reports_output()   # STUB_CLAUDE_OUTPUT="error: not logged in" -> status 1, stderr contains "no session created" and "not logged in"; log empty
```

- [ ] **Step 2: Run them to verify they fail**

Run: `scripts/tests/run.sh`
Expected: every test FAILs (`repos.sh` / `cloud-launch.sh` missing); final line `0 passed, 14 failed`.

- [ ] **Step 3: Implement `scripts/repos.tsv`, `scripts/lib/repos.sh` and `scripts/cloud-launch.sh`**

Port codecite's launch loop; resolve the repo through `repos.sh`; check the clone (`git -C <clone> rev-parse --abbrev-ref HEAD` must be `main`) before any launch; `cd` into the clone for each `script -qfc` call. Header comment gives usage and the log path, as codecite's does.

- [ ] **Step 4: Run tests and shellcheck**

Run: `scripts/tests/run.sh && shellcheck scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh scripts/tests/stubs/*`
Expected: `14 passed, 0 failed`; shellcheck prints nothing.

- [ ] **Step 5: Commit**

```bash
git add scripts
git commit -m "feat(scripts): add a repo-aware cloud-launch.sh driven by scripts/repos.tsv"
```

### Task 1c: `cloud-status.sh`

**Files:**
- Create: `scripts/cloud-status.sh`
- Test: `scripts/tests/test-cloud-status.sh`, `scripts/tests/fixtures/` (PR JSON per repo)

**Interfaces:**
- Consumes: `scripts/lib/repos.sh` (Task 1b); codecite's `scripts/cloud-status.sh` jq program (gate, changes-requested lens, closing issue, eval marker `codecite-eval-scorecard`).
- Produces: CLI
  - `scripts/cloud-status.sh <repo> [<pr> ...]` — open PRs against `main` on one repo, or just the listed PRs.
  - `scripts/cloud-status.sh --all` — every repo in `repos.tsv`, in file order.
  - Columns: `REPO PR STATE GATE ISSUE EVAL TITLE`. `GATE` appears only if at least one listed repo has `gate`; `EVAL` only if at least one has `eval`; a repo without the feature shows `n/a` in that cell. All `gh` calls pass `-R <slug>`.
  - Exit 2 on usage errors; 1 if `gh` failed for any repo (stderr `<repo>: gh failed`, other repos still printed); 0 otherwise.

- [ ] **Step 1: Write the failing tests**

```bash
test_single_repo_omits_eval()     # identity-stack, one PR #500 BEHIND, gate SUCCESS, body "Closes #480":
                                  # header == "REPO PR STATE GATE ISSUE TITLE" (by words, no EVAL); row has "identity-stack #500 BEHIND SUCCESS #480"
test_all_shows_na()               # --all: header has GATE and EVAL; identity-stack-planning row has "n/a" for both
test_passes_slug()                # STUB_CALLS contains "-R jamescrowley321/identity-stack"
test_specific_prs_only()          # identity-stack 500 -> STUB_CALLS has "pr view 500" and no "pr list"
test_changes_requested_lens()     # review on head with body "## Security Review" -> title shown as "[Security Review] <title>"
test_no_open_prs()                # empty list -> header only, status 0
test_gh_failure_one_repo()        # --all with fixtures/terraform-provider-descope/fail -> stderr "terraform-provider-descope: gh failed", other rows printed, status 1
test_usage()                      # no args -> status 2; unknown repo -> status 2
```

- [ ] **Step 2: Run to verify they fail**

Run: `scripts/tests/run.sh`
Expected: the 8 new tests FAIL; the 14 from 1b PASS.

- [ ] **Step 3: Implement `scripts/cloud-status.sh`**

Keep codecite's jq program; emit the gate and eval cells as `n/a` when `repo_has` says the repo lacks them, and drop a column when no listed repo has it.

- [ ] **Step 4: Run tests and shellcheck**

Run: `scripts/tests/run.sh && shellcheck scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh`
Expected: `22 passed, 0 failed`; no shellcheck output. Then one live read: `scripts/cloud-status.sh --all` prints a header and one row per open PR in the five repos, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts
git commit -m "feat(scripts): add cloud-status.sh for one repo or --all"
```

### Task 1d: CI and the PR

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: required-check names for oss-admin's later `branch_protection.tf`: `shellcheck`, `script-tests`, `zizmor`.

- [ ] **Step 1: Write `.github/workflows/ci.yml`**

`on: pull_request` and `push` to `main`; `permissions: {}` at top, `contents: read` per job; every action pinned by SHA (`actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` with `persist-credentials: false`; `zizmorcore/zizmor-action@85b2b9fb8e3325e7a23d7d0a9d7ba5ae0f999e3e # v0.7.1`, `version: 1.31.1`, `advanced-security: false`, as codecite's `security.yml`). Job `shellcheck` runs the shellcheck line from AGENTS.md; `script-tests` runs `scripts/tests/run.sh` (and `pocs/*/tests/run.sh` if present, via a loop that tolerates none). A comment says the job names are required-check contexts in oss-admin.

- [ ] **Step 2: Verify locally**

Run: `uvx zizmor@1.31.1 .github/workflows/ && scripts/tests/run.sh`
Expected: zizmor reports no findings; `22 passed, 0 failed`.

- [ ] **Step 3: Commit, push, open the PR**

```bash
git add .github && git commit -m "ci: run shellcheck, the script tests and zizmor on every PR"
git fetch origin && git push -u origin feat/scaffold
gh pr create -R jamescrowley321/agentic-ppp --base main --title "feat: scaffold agentic-ppp with both designs, plans and the shared cloud scripts" --body-file <body>
```

Body: summary; acceptance criteria (the Task 1 list: README title, AGENTS.md sections, both specs and plans, `notes/`, `pocs/`, scripts with tests, CI); "After merge, for James: add `branch_protection.tf` in oss-admin `terraform/agentic-ppp` requiring `shellcheck`, `script-tests`, `zizmor`"; AI provenance (Claude Code; model ID) with the ticked box.
Expected: PR URL printed; the three CI jobs go green.

- [ ] **Step 4: James: review and merge the agentic-ppp PR; merge oss-admin#33 and confirm its TFC runs; add branch protection when ready.**

---

## Task 2: codecite drops its copies

**Files:**
- Delete: `scripts/cloud-launch.sh`, `scripts/cloud-status.sh` (codecite)
- Modify: `docs/cloud-sessions.md` ("Starting a session" section)

**Interfaces:**
- Consumes: agentic-ppp `scripts/cloud-launch.sh codecite <n>...`, `scripts/cloud-status.sh codecite` (Task 1, merged).

- [ ] **Step 1: File the issue** — `gh issue create -R jamescrowley321/codecite --title "chore: use agentic-ppp's shared cloud scripts" --body "<why, and the Done when below>"`. Done when: both scripts are gone from codecite; `docs/cloud-sessions.md` shows `~/repos/auth/agentic-ppp/scripts/cloud-launch.sh codecite 111 117 105` and `.../cloud-status.sh codecite`, the log path `~/.local/state/agentic-ppp/cloud-sessions.log`, and links the agentic-ppp scripts; `grep -rn 'scripts/cloud-' --exclude-dir=target .` in codecite finds only those doc lines.
- [ ] **Step 2: Worktree** `git -C ~/repos/codecite worktree add -b chore/shared-cloud-scripts ~/repos/codecite-worktrees/shared-cloud-scripts origin/main`
- [ ] **Step 3: Make the change** — `git rm` both scripts; edit the doc. Leave the old `~/.local/state/codecite/` log alone and say it is no longer written.
- [ ] **Step 4: Verify** — Run the Done-when grep (expected: only the doc lines), then `cargo fmt --check && cargo clippy --workspace --all-targets --locked -- -D warnings && cargo test --workspace --locked` (expected: all pass).
- [ ] **Step 5: Commit, push, PR** — `chore: use agentic-ppp's shared cloud scripts`, body with `Closes #<n>`, the Done when, provenance. Answer the lenses (codecite AGENTS.md step 5). No `eval` label.
- [ ] **Step 6: James: merge.**

---

## Task 3: identity-stack readiness

**Files (in `~/repos/auth/identity-stack-worktrees/chore-cloud-ready`, branch `chore/cloud-ready`):**
- Create: `AGENTS.md`, `CLAUDE.md` (`@AGENTS.md`), `.claude/settings.json`, `.claude/hooks/cloud-setup.sh`

**Interfaces:**
- Consumes: codecite `AGENTS.md` "Working an issue end to end", codecite `.claude/settings.json` and `.claude/hooks/cloud-setup.sh` as templates; identity-stack `CONTRIBUTING.md` (AI-assisted contributions) and `.github/pull_request_template.md` (provenance block).
- Produces: label `cloud-ready` (color `0E8A16`, description `Specified well enough for a Claude Code cloud session to execute`); a pinned issue titled `Cloud execution queue: the order to work cloud-ready issues` with a `## Order` section (Task 5 parses it); "## Done when" on #480, #478, #481.

- [ ] **Step 1: Write `AGENTS.md`** — required sections:
  1. **What this is** — two lines, pointing at `README.md`, `CONTRIBUTING.md`, `docs/`.
  2. **Git** — feature branch in a worktree (local) or the session's own checkout (cloud); conventional commits; squash PRs to `main`; never force-push, fetch first; James merges; never merge your own PR.
  3. **Rules for every artifact** — no client or outside project names; the PR template's AI provenance block filled in (both boxes ticked, harness `Claude Code`, the model ID); no secrets.
  4. **What CI runs, and what you can run** — lint: `cd backend && ruff check . && ruff format --check .`; frontend: `cd frontend && npm ci && npm test && npx tsc -b && npm run lint`; unit tests: `make test-unit` (needs Docker for `docker-compose.test.yml`). Integration, E2E and profile tests need credentials or the full stack: CI only. If Docker isn't available, run the unit tests that don't need it, and say in the PR which ones ran.
  5. **Working an issue end to end** — pick the next `cloud-ready` issue in the pinned queue's order; read it and its "Done when"; plan by hand in the PR body under `## Plan`; test-first; run section 4 before every push; PR to `main` with `Closes #<n>`, the Done-when list and provenance; read CI, the lens reviews and the Merge Gate; fix each MUST FIX at its cause (lenses see only hunks, so read the whole file first; reply on the PR to false positives); stop after three review rounds and summarise in a PR comment; never merge; one file area per session; if `gh` isn't logged in, use the GitHub connector tools.
- [ ] **Step 2: Write the hook** — `.claude/settings.json` as codecite's (SessionStart, matcher `startup|resume`, timeout 600). `cloud-setup.sh`: `[[ "${CLAUDE_CODE_REMOTE:-}" == true ]] || exit 0`; each step prints `cloud-setup: <result>` and never fails the session; installs uv, Python 3.12 (`uv python install 3.12`), `cd backend && uv sync --locked --python 3.12` and puts `backend/.venv/bin` on PATH for the session (via `$CLAUDE_ENV_FILE` if set); Node 22 (CI's version) then `cd frontend && npm ci`; reports `docker info` success or "no Docker: unit tests that need the test stack run in CI only"; reports `gh auth status` as codecite's does. Exact install commands are the builder's.
- [ ] **Step 3: Verify the hook** — Run: `shellcheck .claude/hooks/cloud-setup.sh` (no output); `env -u CLAUDE_CODE_REMOTE .claude/hooks/cloud-setup.sh; echo $?` (expected: no output, `0`); `CLAUDE_CODE_REMOTE=true CLAUDE_PROJECT_DIR=$PWD .claude/hooks/cloud-setup.sh; echo $?` (expected: `cloud-setup:` lines for uv, Python, backend deps, Node, frontend deps, Docker, gh; `0`).
- [ ] **Step 4: Run what CI runs** — section 4's lint and frontend commands, and `make test-unit` (Docker is available locally). Expected: all pass, nothing changed by them.
- [ ] **Step 5: Commit, push, PR** — `chore: ready the repo for Claude Code cloud sessions`. Body: acceptance criteria (the files above, the hook's no-op locally, the label/queue/checklists done), provenance. Stage only the four files.
- [ ] **Step 6: GitHub-side setup** (agent):
  - `gh label create cloud-ready -R jamescrowley321/identity-stack --color 0E8A16 --description "Specified well enough for a Claude Code cloud session to execute"`
  - Append a `## Done when` numbered checklist to #480, #478, #481 (`gh issue edit --body-file`, original body kept above it). Each item checkable from the diff or CI. Defaults where a design call is needed, marked as defaults James can change in review. Things the checklists must cover: #480 — where the Node floor is declared (default: `engines.node` `>=22` in `frontend/package.json` plus `.nvmrc` `22`) and that CI still pins 22; #478 — `infra/PROVIDERS.md` describes HCP Terraform variable sets, the two stale inventory rows fixed, every Infisical reference listed in the issue removed or reworded; #481 — both suppressions in `.github/workflows/security.yml:32` **and** the `Makefile` `security` target (`--ignore-vuln CVE-2026-4539`) either removed (if a fixed version now exists) or each documented beside the flag with package, version, date assessed and removal condition, plus a re-check the default for which is a scheduled run that fails once a fix exists. Label each `cloud-ready`.
  - Create and pin the queue issue (`gh issue create` then `gh issue pin`): same title and shape as codecite#125; `## Order` line 1: `#480, #478, #481` (independent, different file areas); `## Not cloud-ready` listing #474/#406 and #475/#407 (later, one at a time) and the issues that stay with James (#476, #477, #411–#418, #458, #385, #386, #377, #378, #387).
- [ ] **Step 7: James: merge the readiness PR; create the claude.ai/code environment for identity-stack (network Trusted, no variables or secrets; Claude GitHub App on the repo).**

---

## Task 4: ISP readiness

**Files (in `/tmp/isp-chore-cloud-ready`, branch `chore/cloud-ready`):**
- Modify: `AGENTS.md` (add sections; keep all existing ones), `.github/PULL_REQUEST_TEMPLATE.md` (provenance comment)
- Create: `.claude/settings.json`, `.claude/hooks/cloud-setup.sh`

**Interfaces:**
- Consumes: as Task 3. ISP `CLAUDE.md` already imports `AGENTS.md`.
- Produces: label `cloud-ready`; pinned queue issue (same title and `## Order` shape as Task 3); "## Done when" on ISP#126.

- [ ] **Step 1: Extend `AGENTS.md`** — add **What CI runs, and what you can run** (`npm ci && npm run build && npm run typecheck`; until ISP#126 lands nothing runs on a PR, so this is the only check) and **Working an issue end to end** (as Task 3 step 1.5, plus: ISP holds no application code, per its own rules). Extend the existing `## Git` with: never force-push; James merges. Don't touch the "Do not touch" paths.
- [ ] **Step 2: Update the PR template's provenance comment** — it currently says an agent must NOT tick the accountability box. Change the comment to say James has delegated the tick for agent PRs (as codecite's AGENTS.md says). Call this out in the PR body as a policy change for James to accept or revert.
- [ ] **Step 3: Write the hook** — as Task 3 step 2 but: Node 26 (the version `deploy.yml` uses), then `npm ci`; no Python, no Docker check. Don't stage `.claude/settings.local.json` (untracked, local).
- [ ] **Step 4: Verify** — the hook checks from Task 3 step 3 (expected lines: Node, npm deps, gh); `npm ci && npm run build && npm run typecheck` (expected: build succeeds, no broken links, typecheck clean).
- [ ] **Step 5: Commit, push, PR** — `chore: ready the repo for Claude Code cloud sessions`; body as Task 3, plus "This repo has no PR CI or lens workflow yet; ISP#126 adds the build check. Adding `claude.yml` here is an oss-admin and repo change left to James."
- [ ] **Step 6: GitHub-side setup** (agent) — create the `cloud-ready` label; append "## Done when" to ISP#126 (a `pull_request` workflow running `npm ci` and `npm run build` on PRs to `main`; actions pinned by SHA; `permissions: contents: read`; job name stated in the PR so James can make it a required check in oss-admin) and label it; create and pin the queue: `## Order` 1. `#126`; 2. `#127` (after #126 merges; not labelled yet, later plan); `## Not cloud-ready` lists #66 (local run, later plan) and #128 (local machine cleanup).
- [ ] **Step 7: James: merge; create the claude.ai/code environment for ISP (Trusted, no variables or secrets). Meanwhile, merge identity-stack's green Dependabot PRs #497, #505, #507, #508, #509.**

---

## Task 5: The cloud loop POC

**Files (agentic-ppp, branch `feat/cloud-loop`):**
- Create: `pocs/track-2/cloud-loop/tick.sh`, `pocs/track-2/cloud-loop/queues.txt`, `pocs/track-2/cloud-loop/agentic-ppp-cloud-loop.service`, `pocs/track-2/cloud-loop/agentic-ppp-cloud-loop.timer`, `pocs/track-2/cloud-loop/install.sh`, `pocs/track-2/cloud-loop/uninstall.sh`, `pocs/track-2/cloud-loop/README.md`
- Test: `pocs/track-2/cloud-loop/tests/run.sh` (reuses `scripts/tests/lib.sh` and stubs), `pocs/track-2/cloud-loop/tests/test-tick.sh`

**Interfaces:**
- Consumes: `scripts/lib/repos.sh`, `scripts/cloud-launch.sh <repo> <n>`, `scripts/cloud-status.sh --all`, the launch log format (Task 1b); the pinned queue issues (Tasks 3, 4).
- Produces: CLI `pocs/track-2/cloud-loop/tick.sh [--dry-run]`. Env: `CLOUD_LOOP_MAX` (default `4`), `CLOUD_LOOP_LAUNCH` (default `<repo root>/scripts/cloud-launch.sh`), `AGENTIC_PPP_CLOUD_LOG` (shared with launch). `queues.txt`: repo names, one per line, `#` comments; first slice holds `identity-stack` then `identity-stack-planning`.
- Algorithm (the part the tests don't fully pin):
  1. For each repo in `queues.txt`: `gh issue list -R <slug> --state open --label cloud-ready --json number` → the ready set; the pinned issue whose title starts `Cloud execution queue` → its body. Any `gh` failure: print `<repo>: gh failed; launching nothing this tick` and exit 1 after the status print, launching nothing anywhere.
  2. Queue order: refs in the body between `## Order` and the next `## ` heading, matched by `(^|[^A-Za-z0-9_./-])#([0-9]+)`, first appearance wins, kept only if in the ready set. No pinned issue or no `## Order`: warn `<repo>: no pinned queue issue` / `<repo>: queue has no ## Order section`, skip that repo.
  3. In use = log entries `<repo>#<n>` (repos in `queues.txt`) whose `n` is in that repo's ready set. Launched-once = every log entry.
  4. Walk repos in `queues.txt` order, each repo's queue in order; launch each not-yet-launched ref, one `cloud-launch.sh <repo> <n>` call each, while in use < `CLOUD_LOOP_MAX`. `--dry-run` prints `would launch <repo>#<n>` instead.
  5. Run `scripts/cloud-status.sh --all`.

- [ ] **Step 1: Write the failing tests** (launch stub records `<repo> <n>` per call; gh fixtures per repo)

```bash
test_launches_in_order_up_to_cap()  # identity-stack Order "1. #480, #478, #481"; ISP Order "1. #126"; empty log
                                    # -> launches exactly: identity-stack 480, identity-stack 478, identity-stack 481, identity-stack-planning 126
test_cap_counts_across_repos()      # log has identity-stack#480,#478,#481 still open+ready -> launches only identity-stack-planning 126
test_closed_issue_frees_slot()      # log has 4 entries, one no longer in the ready set -> one new launch
test_unlabelled_issue_frees_slot()  # same, the issue open but label removed -> one new launch
test_never_relaunches()             # log has identity-stack#480, slot free -> 480 not launched again
test_ignores_cross_repo_refs()      # Order "1. #480 (needs oss-admin#32)" with 32 in ready set -> 32 not launched
test_only_order_section()           # "#999" under "## Not cloud-ready", 999 in ready set -> not launched
test_no_order_section()             # body without "## Order" -> stderr "identity-stack: queue has no ## Order section"; ISP still launched
test_no_pinned_queue()              # ISP has no pinned queue -> stderr "identity-stack-planning: no pinned queue issue"; identity-stack still launched
test_gh_failure_launches_nothing()  # fixtures/identity-stack-planning/fail -> no launches at all, status 1, stderr "gh failed"
test_dry_run()                      # --dry-run -> stdout "would launch identity-stack#480", launch stub never called
test_prints_status()                # STUB_CALLS shows cloud-status ran (gh pr list for each repo in repos.tsv)
```

- [ ] **Step 2: Run to verify they fail** — Run: `pocs/track-2/cloud-loop/tests/run.sh`. Expected: `0 passed, 12 failed`.
- [ ] **Step 3: Implement `tick.sh`** per the algorithm above.
- [ ] **Step 4: Run tests** — Run: `pocs/track-2/cloud-loop/tests/run.sh && scripts/tests/run.sh && shellcheck pocs/track-2/cloud-loop/*.sh pocs/track-2/cloud-loop/tests/*.sh`. Expected: `12 passed, 0 failed`, `22 passed, 0 failed`, no shellcheck output.
- [ ] **Step 5: Write the units, installers and README**
  - Service: `Type=oneshot`, `ExecStart=%h/repos/auth/agentic-ppp/pocs/track-2/cloud-loop/tick.sh` (the primary checkout, on `main`), `Environment=PATH=%h/.local/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin` (where `claude` and `gh` live here).
  - Timer: `OnBootSec=5min`, `OnUnitActiveSec=15min` (my call; ticks only launch and print).
  - `install.sh`: symlinks both units into `~/.config/systemd/user/`, `systemctl --user daemon-reload`, `systemctl --user enable --now agentic-ppp-cloud-loop.timer`. `uninstall.sh`: `disable --now`, removes the symlinks, daemon-reload.
  - README: what it does; watch with `journalctl --user -u agentic-ppp-cloud-loop -f`; run one tick by hand with `pocs/track-2/cloud-loop/tick.sh --dry-run`; free a stuck slot by removing the issue's `cloud-ready` label; **Remove it**: `pocs/track-2/cloud-loop/uninstall.sh`, then delete the folder.
- [ ] **Step 6: Verify the units** — Run: `systemd-analyze --user verify pocs/track-2/cloud-loop/agentic-ppp-cloud-loop.service pocs/track-2/cloud-loop/agentic-ppp-cloud-loop.timer`. Expected: no errors. Don't install yet.
- [ ] **Step 7: Commit, push, PR** — `feat(pocs): add the cloud loop, a timer that launches queued issues up to four sessions`; body with acceptance criteria and provenance.
- [ ] **Step 8: James: merge.**

---

## Task 6: Launch the first batch

Outward action. Preconditions, each checked: Tasks 1, 3, 4, 5 merged; `git -C ~/repos/auth/agentic-ppp pull --ff-only`; identity-stack and ISP environments exist (James); #480, #478, #481, ISP#126 open and labelled.

- [ ] **Step 1: Dry run** — Run: `~/repos/auth/agentic-ppp/pocs/track-2/cloud-loop/tick.sh --dry-run`. Expected: exactly `would launch identity-stack#480`, `#478`, `#481`, `would launch identity-stack-planning#126`, then the status table.
- [ ] **Step 2: Start the loop** — Run: `~/repos/auth/agentic-ppp/pocs/track-2/cloud-loop/install.sh`, then `systemctl --user start agentic-ppp-cloud-loop.service`. Expected in `journalctl --user -u agentic-ppp-cloud-loop`: four `<repo>#<n>: https://claude.ai/code/session_…` lines; four new lines in `~/.local/state/agentic-ppp/cloud-sessions.log`.
- [ ] **Step 3: Check each session's start** — open each link. Record for the note: the setup hook's `cloud-setup:` lines (especially identity-stack's Docker line), which model the session runs, whether `gh` is logged in. If a session started on the wrong repo or had no AGENTS.md, stop the loop (`uninstall.sh`) and fix before going on.
- [ ] **Step 4: Watch** — `scripts/cloud-status.sh --all` and the journal, until each PR reaches James or its session stops after three rounds. Don't push to the sessions' branches; comment on the PR to wake a session. For `BEHIND` PRs, `gh pr update-branch <n> -R <slug>` is allowed.
- [ ] **Step 5: James: review and merge the four PRs.** When the queues are empty, `pocs/track-2/cloud-loop/uninstall.sh`.

---

## Task 7: Notes for cloud sessions and the cloud loop

**Files (agentic-ppp, branch `docs/notes-cloud-sessions`):**
- Create: `notes/track-2/cloud-sessions.md` (one entry each: identity-stack#480, #478, #481, ISP#126), `notes/track-2/cloud-loop.md` (one entry: the first batch)

- [ ] **Step 1: Gather the facts** — per PR: links (issue, PR, session); setup time and what broke (from Task 6 step 3); lens rounds and Merge Gate results (`gh pr view <n> -R <slug> --json reviews,comments,statusCheckRollup`); what James changed before merging (`gh pr view --json commits` plus his comments); wall time from launch-log time to merge; cost if claude.ai/code shows it per session, otherwise write "not shown per session" and say where you looked. For the loop: ticks run, launches per tick, anything it got wrong.
- [ ] **Step 2: Write the entries** in the `notes/README.md` format; the *(James)* fields are a `*(James)*` placeholder. No status words; no outside names.
- [ ] **Step 3: Commit, push, PR** — `docs(notes): record the first cloud-session batch and the loop that launched it`; provenance. **James** writes the first-person parts in review, then merges.

---

## Task 8: TFD readiness

**Files (in `~/repos/auth/terraform-provider-descope-worktrees/chore-cloud-ready`, branch `chore/cloud-ready`):**
- Create: `AGENTS.md`, `.claude/settings.json`, `.claude/hooks/cloud-setup.sh`
- Modify: `CLAUDE.md`, `.gitignore:45` (`.claude/` ignores the whole folder), `.github/workflows/ci.yml` (jobs `integration_test`, `fork_test`)

**Interfaces:**
- Consumes: identity-stack's `ci.yml` Dependabot exclusion (`if:` on `integration-tests`) as the pattern.
- Produces: `integration_test` and `fork_test` skip on Dependabot PRs (closes TFD#238 and #239's failure cause); label `cloud-ready`; pinned queue issue.

- [ ] **Step 1: Fix `.gitignore`** — replace `.claude/` with `.claude/*`, `!.claude/settings.json`, `!.claude/hooks/`. Verify: `git check-ignore -v .claude/settings.json .claude/hooks/cloud-setup.sh` prints nothing; `git check-ignore -q .claude/worktrees/x && echo ignored` prints `ignored`.
- [ ] **Step 2: Write `AGENTS.md`; rewrite `CLAUDE.md`** — `AGENTS.md` sections as Task 3 step 1, with **What CI runs, and what you can run**: `gofmt -l .` (empty), `go build ./...`, `golangci-lint run --config=.github/actions/ci/lint/golangci.yml` (v2.11.4, CI's), `gosec -exclude-dir=internal/docs ./...` (v2.24.7, CI's), `go test -count=1 ./...`. Acceptance and integration tests (`make testacc`, `make testintegration`, `source .env`) need Descope credentials: **CI only; there is no `.env` in a cloud session.** Keep the fork rule: PRs against `jamescrowley321/terraform-provider-descope`, never upstream. `CLAUDE.md` becomes `@AGENTS.md` plus a short "Local machine only" section keeping today's `source .env` acceptance-test step.
- [ ] **Step 3: Skip secret-gated jobs on Dependabot PRs** — add to `integration_test` and `fork_test`:

```yaml
if: >-
  github.event_name == 'push' ||
  (github.event_name == 'pull_request' && github.event.pull_request.user.login != 'dependabot[bot]')
```

with a short comment: Dependabot PRs get no Actions secrets, so these jobs fail for a reason unrelated to the bump (TFD#238, #239); a skipped job satisfies the required check; the routine's fix PRs are same-repo branches and do run them. Builder checks whether TFD#238/#239 come from a fork or the same repo (both are same-repo Dependabot branches today) and whether any other job needs a secret on Dependabot PRs (`Check Leaks` passes today).
- [ ] **Step 4: Verify the workflow** — Run: `uvx zizmor@1.31.1 .github/workflows/ci.yml` (no new findings versus `main`) and `go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7 .github/workflows/ci.yml` (no errors).
- [ ] **Step 5: Write the hook** — as Task 3 step 2 but: Go from `go.mod` (`GOTOOLCHAIN=auto` fetches 1.26.10), `go install` golangci-lint v2.11.4 and gosec v2.24.7, `go mod download`; reports gh. No `.env` and no Descope variables.
- [ ] **Step 6: Run what CI runs** — the hook checks from Task 3 step 3; then step 2's five commands. Expected: all pass (gosec as on `main`; its findings on #229's branch are #229's).
- [ ] **Step 7: Renovate** — Run: `gh pr list -R jamescrowley321/terraform-provider-descope --author app/renovate --state all --limit 1`. No output means Renovate has never opened a PR here, so `renovate.json` does nothing. Say what you found in the PR body; leave `renovate.json` as is.
- [ ] **Step 8: Commit, push, PR** — `ci: skip secret-gated integration jobs on Dependabot PRs, and ready the repo for cloud sessions`. Body: acceptance criteria; "Fixes the cause of #238 and #239: after merge, `@dependabot rebase` on each turns them green" (don't use `Closes`: those PRs close when merged); provenance.
- [ ] **Step 9: GitHub-side setup** (agent) — `cloud-ready` label; pinned queue issue with `## Order` 1. `#229` (James's PR: a session may push gosec fixes to his branch); 2. `#109` after #229 merges, nothing else on TFD while it runs. Both run under a later plan; don't label them yet.
- [ ] **Step 10: James: merge; create the claude.ai/code environment for TFD (Trusted, no variables or secrets); comment `@dependabot rebase` on #238 and #239 and merge them when green.**

---

## Task 9: The Dependabot routine's prompt and summary issue

**Files (agentic-ppp, branch `feat/dependabot-routine`):**
- Create: `pocs/track-2/dependabot-routine/prompt.md`, `pocs/track-2/dependabot-routine/README.md`

**Interfaces:**
- Consumes: Task 8 merged (TFD's Dependabot PRs no longer red on secret-gated jobs); `scripts/repos.tsv` slugs.
- Produces: a pinned agentic-ppp issue titled `Dependabot routine: weekly summaries` (its number goes into `prompt.md`); the routine's PR conventions — branch `build/dependabot-<n>`, title `build(deps): <the bump> (supersedes #<n>)`, body line `Supersedes #<n>` and marker `<!-- agentic-ppp-dependabot-routine -->`.

- [ ] **Step 1: Create and pin the summary issue** — `gh issue create -R jamescrowley321/agentic-ppp --title "Dependabot routine: weekly summaries" --body "<what posts here, and how to stop the routine>"`, then `gh issue pin`.
- [ ] **Step 2: Write `prompt.md`** — wording the builder's; it must state, in order:
  1. Repos: identity-stack and terraform-provider-descope (identity-stack-planning once ISP#127 lands). No secrets exist here; never ask for any.
  2. First, your own open PRs (marker above): rebase on `main` if `BEHIND`, fix what CI or the lenses flag, once.
  3. List open Dependabot PRs; classify each: **green** (all required checks pass or are skipped), **pending** (checks still running: leave for next week), **red on secret-gated jobs only** (identity-stack: `Integration Tests`, `E2E Tests`; TFD: `Integration Tests (upstream)`, `Integration Tests (fork)`; should be skipped after Task 8, so report any as a finding), **red**.
  4. For each red PR, at most three per repo per run: branch `build/dependabot-<n>` from `main`, apply the same bump, adapt the code until build, lint and unit tests pass (each repo's AGENTS.md "What CI runs"), open a PR to `main` with the conventions above, the acceptance criteria and the provenance section with the ticked box. For identity-stack#491: attempt the py-identity-model 4 adaptation, and put "James: review closely (py-identity-model 4 adaptation)" at the top of the body.
  5. Wait for the first CI and lens round on each PR opened, fix what you can once, then stop working it.
  6. Alerts: `gh api repos/<slug>/dependabot/alerts?state=open`; for each alert with no patched version, file an issue `security(deps): <package> <GHSA id> has no patched version` unless an open issue already names that GHSA id. If the alerts API is refused, skip this step and say so in the summary.
  7. Post one comment on the summary issue: Green (ready for James, with links); Opened; Updated (own PRs); Issues filed; Skipped, and why (including the cap). Never merge, never close Dependabot's PRs, never push to Dependabot's branches.
- [ ] **Step 3: Write `README.md`** — what it is; schedule `0 6 * * 2` (Tuesdays 06:00 UTC, my call: after Monday's weekly Dependabot runs); model: the strongest Claude model offered; how it was created (filled in by Task 10); how to trigger a run; **Remove it**: delete the routine (exact command or UI path, from Task 10), unpin and close the summary issue, delete the folder.
- [ ] **Step 4: Check** — `grep -c 'agentic-ppp-dependabot-routine' pocs/track-2/dependabot-routine/prompt.md` ≥ 1; the summary issue number in `prompt.md` matches step 1; no outside names.
- [ ] **Step 5: Commit, push, PR** — `feat(pocs): add the weekly Dependabot routine's prompt`; provenance. **James: merge.**

---

## Task 10: Create the routine and run it once

Outward action, after Tasks 8 and 9 merge and the TFD environment exists.

- [ ] **Step 1: Check what a routine can reach** — load the `schedule` skill (and the RemoteTrigger capability it uses). Find out: can one routine reach identity-stack, TFD and agentic-ppp; which environment it runs in; whether it can be triggered now; how a model is chosen. Write the answers into `pocs/track-2/dependabot-routine/README.md` in step 5.
- [ ] **Step 2: Create it** — one routine spanning the three repos if supported; otherwise one per repo, each posting on a pinned `Dependabot routine: weekly summaries` issue in its own repo (create those issues as Task 9 step 1, and adjust step 7 of the prompt per routine). Prompt: the contents of `~/repos/auth/agentic-ppp/pocs/track-2/dependabot-routine/prompt.md` on `main`. Schedule `0 6 * * 2`. Strongest model offered.
- [ ] **Step 3: Trigger the first run now** — Expected outcomes, each checked: a PR `build(deps): … (supersedes #491)` on identity-stack with the "review closely" line; a PR `… (supersedes #230)` on TFD (go-sdk 1.33 → 1.37 adapted until build, lint and unit tests pass); at most three PRs per repo; one summary comment listing the green PRs (expect #238/#239 if James hasn't merged them) and whether the alerts API worked.
- [ ] **Step 4: James: review the two PRs (#491's closely) and merge.**
- [ ] **Step 5: Note and README** — branch `docs/notes-dependabot-routine`: fill the "how it was created" and "Remove it" parts of `pocs/track-2/dependabot-routine/README.md`; create `notes/track-2/dependabot-routine.md` with one entry for the first run (facts as Task 7 step 1, plus: one routine or several and why, alerts API result, how it told secret-gated failures from real ones). PR `docs(notes): record the Dependabot routine's first run`; provenance. **James** writes the first-person parts and merges.

---

## Later plans

- identity-stack#474 with #406, then #475 with #407: cloud sessions on auth paths, one at a time, Red Team and Security lenses, close review by James.
- TFD#229 (a session pushes gosec fixes to James's branch), then TFD#109 (snake_case rename, nothing else on TFD while it runs).
- pi supervisor over a cloud batch, ISP#127, and the rho research note (a cloud session writing a note PR to agentic-ppp).
- ISP#66 on pi-durable-subagents, locally: proposes dispositions only, never dismisses alerts; separate Track 2 OpenRouter key, $30 limit.
- Posts drafted from the notes, one per technique, as PRs to personal-blog.
