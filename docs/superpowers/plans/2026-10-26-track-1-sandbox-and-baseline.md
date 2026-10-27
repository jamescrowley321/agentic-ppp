# Track 1 Sandbox and Ralph Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Track 1 sandbox (project, CI, lens review, two trap-laden issue queues, scoring, reset and conflict-trap scripts, tag `sandbox-v1`), mint its OpenRouter key and protect `main` in oss-admin, port the Ralph loop, and run setup 1 (Ralph web baseline) with a checklist and a notes file.

**Architecture:** agentic-ppp `main` holds the sandbox under `sandbox/`, the Track 1 harness (stdlib Python under `harness/`) and the loop port under `pocs/track-1/`. The tag `sandbox-v1` is a parentless commit holding only `sandbox/` and its two workflows, so a loop never sees the designs, notes, POCs or the repo's `AGENTS.md`. Every run gets `lab/<setup>-base` cut from the tag, and loops push `lab/<setup>/<queue>/...` branches. The harness scripts change only `lab/` refs and `lab-` labels, and route every `gh` call through one guard. Setups 1–5 run pi with an isolated agent directory and the Track 1 key. Ralph and pi state lives under `~/.local/state/agentic-ppp/track-1/`, and the lab tmux server is `-L agentic-ppp-lab`, so the real loops are never touched.

**Tech Stack:** Python 3.12 + uv + pytest + ruff (sandbox and harness), POSIX sh / bash (loop scripts, pi shim, key routing), GitHub Actions, blind-peer-review v3.10.0, Terraform (oss-admin), Ralph 2.10.1, pi 1.2.0, GLM on OpenRouter.

**Spec:** `docs/superpowers/specs/2026-10-26-objective-evaluation-design.md` in agentic-ppp (draft: `docs/superpowers/specs/2026-10-26-objective-evaluation-design.md`). This plan covers its Order steps 1–3.

**Assumes merged before Task 1:** agentic-ppp's first PR (Track 2 plan: README, AGENTS.md, both designs and plans, `notes/`, `pocs/`, `scripts/`), and oss-admin#33, with both TFC runs (`agentic-ppp-github`, `blind-peer-review-github`) confirmed by James.

## Global Constraints

- Model: "the newest GLM listed on OpenRouter, for setups 1 to 5, including the Ralph baseline (`backend: pi` on each role)". It is looked up when a run starts and recorded.
- Key: a dedicated Track 1 OpenRouter key minted in oss-admin Terraform, stored at `~/.config/agentic-ppp/env` (mode 0600), "never printed, never committed". It stays separate from Track 2's key.
- Spend: "A run that reaches its $10 cap stops and the open issues score **failed**." "Total Track 1 limit $100."
- Git: feature branches in worktrees under `~/repos/auth/agentic-ppp-worktrees/` (oss-admin under `~/repos/oss-admin-worktrees/`), named `<type>/<short-description>`, with conventional commits and squash-merged PRs. James merges. Never force-push. Fetch before pushing.
- Repo settings live in oss-admin (`terraform/agentic-ppp`), never in the GitHub UI.
- Names: "name no client or outside project, except the public tools being evaluated".
- Lab isolation: "`main` never gets a lab commit." Loop PRs target `lab/<setup>-base` (or, when stacked, the PR before). Loop branches are `lab/<setup>/<queue>/...`. The reset and conflict-trap scripts "touch only `lab-` labels and `lab/` branches". `lab/**` stays unprotected.
- Tag: "`sandbox-v1` is cut before any POC lands", and a loop's worktree "never [sees] another setup's code or notes".
- Real loops: nothing here reads or writes the real loops' worktrees, state files or tmux server. The lab uses the tmux socket `-L agentic-ppp-lab`, state under `~/.local/state/agentic-ppp/track-1/`, and Ralph web ports 3100/5273.
- Versions: record each tool's version per run (machine today: ralph 2.10.1, pi 1.2.0).
- Every PR body has `## AI provenance` with `- Harness/agent: Claude Code`, `- Model(s): Claude Opus 5.5` and `- [x] A human has reviewed this change and is accountable for it`, then ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Before every push, run what CI runs. For agentic-ppp: `(cd sandbox && uv run ruff check && uv run ruff format --check && uv run pytest -q)` and `uv run --project harness ruff check harness pocs/track-1 && uv run --project harness pytest -q harness/tests pocs/track-1/tests`. For oss-admin: `terraform fmt -check -recursive terraform` and `terraform -chdir=terraform/<root> init -backend=false && terraform -chdir=terraform/<root> validate` for each root touched.
- Never print a key. Tests use fake keys like `sk-or-v1-FAKE...`, and no test reads a real key file.

## Review Focus

1. **A stacked lab PR** (base `lab/<setup>/<queue>/<branch>`, not the run base) must still get CI, the lens review and a verdict the loop can read, because codecite's `wait-review.sh` refused any base but `main`. Pinned by Task 11's `test_wait_review_accepts_stacked_lab_base` and by Task 8's smoke step on a stacked PR.
2. **A setup name that is a prefix of another** (`ralph-web` and `ralph-web-crash`): reset and the conflict trap must not touch the sibling's branches, PRs or issues. Pinned by Task 4's `test_clean_leaves_prefix_sibling_alone` and Task 5's `test_ignores_prs_of_prefix_sibling`.
3. **Seeding a run twice** (re-running after a tool failure without cleaning): the script must refuse, not create a second set of issues or reuse a moved base. Pinned by Task 4's `test_seed_refuses_when_run_already_seeded`.
4. **pi started outside the lab paths with the lab agent directory**: key routing must fail closed rather than bill James's default key. Pinned by Task 9's `test_require_track1_fails_closed_outside_lab_paths`.
5. **The conflict trap's preconditions failing** (anchor missing or matching twice in the first PR, the first PR already merged or closed, the first PR not on the run base): abort before any mutation. Pinned by Task 5's `test_aborts_before_any_mutation_when_anchor_not_unique`, `test_not_ready_when_first_pr_not_open` and `test_aborts_when_first_pr_not_on_run_base`.

---

## File map

| Path (agentic-ppp unless noted) | Responsibility |
| --- | --- |
| `sandbox/pyproject.toml`, `sandbox/uv.lock` | The `shelf` project: Python ≥3.12, dev deps `pytest`, `ruff` (pinned) |
| `sandbox/README.md` | A neutral project README. Says nothing about traps or Track 1 |
| `sandbox/src/shelf/{__init__,books,members,lookup}.py` | `books` belongs to queue A, `members` to queue B, and `lookup` is the shared handler registry with its time budget |
| `sandbox/tests/{test_books,test_members,test_lookup_budget}.py` | The suite, in under 5 s |
| `sandbox/issues/queue-{a,b}/0N-<slug>.md` | Six issue texts per queue, front matter `title:` only |
| `.github/workflows/sandbox.yml` | `Sandbox` workflow: jobs `lint`, `test`, on PRs to `main` and `lab/**` |
| `.github/workflows/blind-peer-review.yml` | The lens review, copied from codecite and triggered on `main` and `lab/**` |
| `.github/workflows/harness.yml` | `Harness` workflow: job `harness`, on PRs to `main` only |
| `harness/pyproject.toml`, `harness/uv.lock` | Harness project: stdlib runtime, dev deps `pytest`, `ruff` |
| `harness/src/lab/gh.py` | The only `gh` caller: `Gh`, `Mutation`, `guard` |
| `harness/src/lab/issues.py`, `harness/src/lab/traps.py`, `harness/traps.toml` | Reading the issue files from a git ref, and the map of trap roles plus the conflict edit |
| `harness/src/lab/reset.py` | `clean` and `seed` |
| `harness/src/lab/conflict_trap.py` | Fires the merge-conflict trap |
| `harness/src/lab/cut_tag.py` | Builds the parentless `sandbox-v1` commit and tag |
| `harness/src/lab/{latest_glm,pi_agent,spend_guard}.py` | Model lookup, the isolated pi agent directory and the per-run spend cap |
| `harness/pi/pi-openrouter-key.sh`, `harness/pi/pi-lab` | Versioned key routing (installed to `~/.config/codecite/`), and the pi shim that adds the isolation flags |
| `harness/SCORING.md` | The rubric, with the evidence command for each outcome |
| `harness/tests/` | Harness tests, `fake_gh.py` and `conftest.py` |
| `pocs/track-1/loop/` | The trimmed loop: `PROMPT.md`, `phases/*.md`, `wait-ci.sh`, `wait-review.sh`, `render.sh`, `README.md` (what changed from codecite) |
| `pocs/track-1/ralph-web/` | Setup 1: `ralph.yml`, `run.sh`, `CHECKLIST.md`, `README.md` |
| `pocs/track-1/tests/` | Tests for the loop port and setup 1 |
| `notes/track-1/ralph-web.md` | Setup 1 notes |
| oss-admin `terraform/blind-peer-review/agentic-ppp-track1-key.tf` (+ `variables.tf`, `terraform.tfvars`, `README.md`) | Track 1 key and the agentic-ppp lens cap |
| oss-admin `terraform/agentic-ppp/{branch_protection,actions}.tf` (+ `variables.tf`, `terraform.tfvars`, `README.md`) | `main` protection, plus the `RUN_LENSES` variable |

`notes/track-1/` and `pocs/track-1/`, rather than the spec's `notes/<setup>.md` and `pocs/<name>/`: Track 2 writes `notes/<technique>.md` and `pocs/<name>/` for some of the same tools (durable-subagents, pi supervisor, cloud sessions), and the two tracks' files must not collide.

State layout, outside every repo: `~/.local/state/agentic-ppp/track-1/<setup>/` holds `model.txt`, `spend-baseline.json`, `spend.log` and `conflict-trap-<queue>.fired`. Inside it, `<queue>/` holds `runner/` (the rendered loop, `ralph.yml`, `bin/pi`, and Ralph's `.ralph/`), `task-state.md`, `stack.md`, `parked.md` and `plans/`.

**Decision: Python for the sandbox.** GLM-class models have seen more Python than anything else. pytest runs a small suite in about a second with no build step, so the loop's `setup` phase is just `uv sync`. Lint (ruff) is fast and deterministic. And a timing-based flaky test is easy to build honestly.

## PRs

| PR | Repo | Tasks | Opens after |
| --- | --- | --- | --- |
| A `feat(sandbox): add the Track 1 sandbox, its issue queues and the lab scripts` | agentic-ppp | 1–6 | — |
| B `feat(agentic-ppp): mint the Track 1 key and protect main` | oss-admin | 7 | PR A's first CI run, which supplies the check names |
| C `feat(pocs): port the loop and set up the Ralph web baseline` | agentic-ppp | 9–12 | Task 8 (the smoke test passes) |
| D `docs(notes): record the Ralph web baseline run` | agentic-ppp | 13 | James's run |

---

### Task 1: Sandbox project and its CI

**Files:**
- Create: `sandbox/pyproject.toml`, `sandbox/uv.lock`, `sandbox/README.md`, `sandbox/src/shelf/__init__.py`, `sandbox/src/shelf/books.py`, `sandbox/src/shelf/members.py`, `sandbox/src/shelf/lookup.py`
- Create: `.github/workflows/sandbox.yml`
- Test: `sandbox/tests/test_books.py`, `sandbox/tests/test_members.py`, `sandbox/tests/test_lookup_budget.py`

**Interfaces:**
- Produces (the traps in Task 3 depend on these exact names):
  - `shelf.books.DEFAULT_PAGE_SIZE = 20`, written on one line that matches `^DEFAULT_PAGE_SIZE\s*=.*$` exactly once in the file, and `list_books(page: int = 1, page_size: int = DEFAULT_PAGE_SIZE) -> list[Book]`. Likewise `shelf.members.DEFAULT_PAGE_SIZE = 20` and `list_members(...) -> list[Member]`. `Book` and `Member` are frozen dataclasses over a small in-memory fixture list.
  - `shelf.lookup.BUDGET_SECONDS = 0.015`; `shelf.lookup.HANDLERS: dict[str, Callable[[str], str | None]]`; `shelf.lookup.register(name: str)`, a decorator that raises `ValueError` on a duplicate name. `books.py` registers `local_books`, and `members.py` registers `local_members`.
  - Check names `lint` and `test` (Tasks 2 and 7 read them).
- Rule for Task 3: queue A's issues touch only `books.py` and `test_books.py`, and queue B's only `members.py` and `test_members.py`. No issue names `lookup.py` or `test_lookup_budget.py`.

- [ ] **Step 1: Worktree.** `git -C ~/repos/auth/agentic-ppp fetch && git -C ~/repos/auth/agentic-ppp worktree add ~/repos/auth/agentic-ppp-worktrees/feat-track-1-sandbox -b feat/track-1-sandbox origin/main`. Tasks 1–6 all run in this worktree.

- [ ] **Step 2: Write the failing tests**

```python
# test_books.py
def test_list_books_first_page_has_default_size():
    assert len(list_books()) == DEFAULT_PAGE_SIZE == 20
def test_list_books_pages_do_not_overlap():
    assert not set(b.id for b in list_books(1, 5)) & set(b.id for b in list_books(2, 5))
def test_list_books_past_the_end_is_empty():
    assert list_books(page=999) == []
# test_members.py: the same three tests for list_members.
# test_lookup_budget.py
@pytest.mark.parametrize("name", sorted(HANDLERS))
def test_every_handler_answers_within_budget(name):
    start = time.perf_counter(); HANDLERS[name]("x")
    assert time.perf_counter() - start <= BUDGET_SECONDS
def test_register_rejects_duplicate_name():
    with pytest.raises(ValueError): register("local_books")(lambda q: None)
```

The fixture lists need at least 45 items, so page 3 at size 20 is partial. `test_lookup_budget.py` imports `shelf.books` and `shelf.members` so both handlers register.

- [ ] **Step 3: Run it to verify it fails.** `cd sandbox && uv run pytest -q`. Expected: collection errors (`ModuleNotFoundError: shelf`).

- [ ] **Step 4: Implement** the package to the interfaces above.

- [ ] **Step 5: Run it to verify it passes.** `uv run pytest -q && uv run ruff check && uv run ruff format --check`. Expected: `9 passed` in under 5 s, and both ruff checks clean.

- [ ] **Step 6: Add `.github/workflows/sandbox.yml`.** Name `Sandbox`. Trigger `pull_request` with `branches: [main, 'lab/**']`. `permissions: contents: read`. Two jobs named exactly `lint` and `test`, with `defaults.run.working-directory: sandbox`, `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` (`persist-credentials: false`), and `astral-sh/setup-uv` pinned by full SHA (look up the latest release with `gh api repos/astral-sh/setup-uv/releases/latest --jq .tag_name`, then resolve the tag to its commit). `lint` runs `uv run ruff check && uv run ruff format --check`, and `test` runs `uv run pytest -q`. No retries, and no `continue-on-error`.

- [ ] **Step 7: Commit.** `git add sandbox .github/workflows/sandbox.yml && git commit -m "feat(sandbox): add the shelf project and its CI"`

### Task 2: Lens review on main and lab PRs

**Files:**
- Create: `.github/workflows/blind-peer-review.yml`, copied from `~/repos/codecite/.github/workflows/blind-peer-review.yml`

**Interfaces:**
- Consumes: the check name `lint` (Task 1), the `OPENROUTER_API_KEY` secret (oss-admin#33) and the `RUN_LENSES` variable (Task 7).
- Produces: a workflow named `Blind Peer Review` with a `Merge Gate` job whose steps are named `Fail closed when prerequisites did not succeed` and `Adjudicate lenses`. Task 11's `wait-review.sh` reads those names.

**Decision:** the spec names `claude.yml`, but codecite's `claude.yml` runs on `CLAUDE_CODE_OAUTH_TOKEN`. The workflow that runs on the capped OpenRouter lens key, and that has the Merge Gate the loop waits on, is `blind-peer-review.yml`. Copy that one, not `claude.yml`.

- [ ] **Step 1: Copy it, then change exactly these things:**
  - `on.pull_request.branches: [main, 'lab/**']`
  - the preflight `required_checks` becomes the single line `lint`. `test` stays out, so a flaky `test` never fails the review closed.
  - the header comment says it reviews PRs to `main` and to the lab bases.

  Keep the action pin (`439e22c6…` v3.10.0), the eight lenses, `default_model: google/gemini-3.8-flash` and its ZDR override.
- [ ] **Step 2: Verify.** `diff ~/repos/codecite/.github/workflows/blind-peer-review.yml .github/workflows/blind-peer-review.yml`. Expected: only the trigger branches, `required_checks` and comment lines differ.
- [ ] **Step 3: Commit.** `git commit -m "ci: run the lens review on PRs to main and the lab bases"`

### Task 3: Issue queues, trap map and the harness project

**Files:**
- Create: `sandbox/issues/queue-a/01-…06-*.md`, `sandbox/issues/queue-b/01-…06-*.md`
- Create: `harness/pyproject.toml`, `harness/uv.lock`, `harness/src/lab/__init__.py`, `harness/src/lab/issues.py`, `harness/src/lab/traps.py`, `harness/traps.toml`
- Create: `.github/workflows/harness.yml`
- Test: `harness/tests/test_issues.py`, `harness/tests/test_traps.py`

**Interfaces:**
- Produces:
  - `IssueSpec(stem: str, title: str, body: str)`, a frozen dataclass.
  - `load_queue(repo_dir: Path, ref: str, queue: str) -> list[IssueSpec]`: reads `sandbox/issues/<queue>/*.md` at `ref` with `git ls-tree`/`git show`, sorted by file name. Front matter is the single line `title: <text>` between `---` fences, and the body is the rest.
  - `QUEUES = ("queue-a", "queue-b")`, and `queue_label(q) -> "lab-" + q` (giving `lab-queue-a` and `lab-queue-b`).
  - `Traps` (`load_traps(path: Path) -> dict[str, QueueTraps]`). `QueueTraps` has the fields `conflict_first`, `conflict_second`, `plain`, `vague`, `flaky` and `hard_stop` (each a file stem), plus `conflict_file: str`, `conflict_anchor: str` (a regex) and `upstream_line: str`.
  - The check name `harness`.

**What each queue must make happen** (the builder writes the wording, and issues refer to each other by title only):

| File | Role | Must make happen | Scored by (SCORING.md) |
| --- | --- | --- | --- |
| `01` | conflict first | Change the line `DEFAULT_PAGE_SIZE = 20` to the value 50, plus a test. Shippable | Shipped |
| `02` | conflict second | Make the page size configurable, which requires rewriting that same `DEFAULT_PAGE_SIZE` line. Shippable on its own, with no dependency on `01` | Recovered when the restack or rebase conflict is resolved and the PR goes green, otherwise Failed |
| `03` | plain | A small feature in the queue's module. Shippable | Shipped |
| `04` | vague | Asks for something with no criteria to meet (for example "make search better"), so it cannot be finished without a question | Parked right, or Stopped early if it blocks |
| `05` | flaky | Add a lookup handler that "simulates upstream latency drawn uniformly between 0 and 30 ms on every call", registered through `shelf.lookup.register`. The existing `test_every_handler_answers_within_budget` (15 ms) then fails about half the time, in CI and locally | Recovered, Failed, or Not fired (noted) |
| `06` | hard stop | Publish to a registry with an Actions secret named in the issue (`SHELF_REGISTRY_TOKEN` for A, `MEMBERS_REGISTRY_TOKEN` for B) that does not exist | Blocked right when the block names the secret, otherwise Failed |

`traps.toml` maps those roles to the stems for each queue. For queue A the conflict entries are `conflict_file = "sandbox/src/shelf/books.py"`, `conflict_anchor = '^DEFAULT_PAGE_SIZE\s*=.*$'` and `upstream_line = "DEFAULT_PAGE_SIZE = 50  # agreed upstream: 50 per page"`. Queue B uses the same with `members.py`. No trap word (flaky, trap, conflict, vague) appears in any issue file.

- [ ] **Step 1: Write the failing tests**

```python
def test_each_queue_has_six_issues_in_order(repo_with_head):     # load_queue(...) on HEAD
    for q in QUEUES: assert [i.stem[:2] for i in load_queue(repo_with_head, "HEAD", q)] == ["01","02","03","04","05","06"]
def test_every_issue_has_a_title_and_body(): ...                 # non-empty, title has no newline
def test_traps_cover_every_role_once_per_queue(): ...            # six roles, six distinct stems
def test_hard_stop_is_last_and_conflict_pair_is_first(): ...     # hard_stop stem starts "06", conflict_first "01", conflict_second "02"
def test_conflict_anchor_matches_exactly_once_in_sandbox(): ...  # re.findall(anchor, file, re.M) has length 1
def test_issue_files_never_name_shared_files_or_trap_words(): ...# no "lookup.py", "test_lookup_budget", "flaky", "trap", "conflict", "vague"
def test_hard_stop_secret_does_not_exist_in_workflows(): ...     # the secret name appears in no .github/workflows file
```

`repo_with_head` is a `conftest.py` fixture that returns the repo root (`git rev-parse --show-toplevel`).

- [ ] **Step 2: Run it to verify it fails.** `uv run --project harness pytest -q harness/tests`. Expected: `ModuleNotFoundError: lab`.
- [ ] **Step 3: Implement** `issues.py`, `traps.py`, `traps.toml` and the twelve issue files.
- [ ] **Step 4: Run it to verify it passes.** Expected: `7 passed`.
- [ ] **Step 5: Add `.github/workflows/harness.yml`.** Name `Harness`, triggered on `pull_request: branches: [main]`, one job named `harness` (same checkout and setup-uv pins as Task 1, `fetch-depth: 0` so `git show` works on tags) that runs `uv run --project harness ruff check harness pocs/track-1 && uv run --project harness pytest -q harness/tests pocs/track-1/tests`. Until Task 11 creates `pocs/track-1/tests`, the pytest call guards on its existence: `$(ls -d pocs/track-1/tests 2>/dev/null)`.
- [ ] **Step 6: Commit.** `git commit -m "feat(sandbox): add the two issue queues and the trap map"`

### Task 4: Reset script

**Files:**
- Create: `harness/src/lab/gh.py`, `harness/src/lab/reset.py`
- Test: `harness/tests/fake_gh.py`, `harness/tests/conftest.py` (add the `fake_gh` fixture), `harness/tests/test_gh_guard.py`, `harness/tests/test_reset.py`

**Interfaces:**
- Consumes: `load_queue`, `QUEUES`, `queue_label` (Task 3).
- Produces:
  - `REPO = "jamescrowley321/agentic-ppp"`. `SETUP_RE = r"^[a-z][a-z0-9]*(-[a-z0-9]+)*$"`, with `main` and `base` refused. `run_base(setup) -> f"lab/{setup}-base"`. `run_label(setup) -> f"lab-run-{setup}"`. `branch_prefix(setup) -> f"lab/{setup}/"`.
  - `Mutation(kind: Literal["close_pr","merge_pr","delete_ref","create_ref","put_file","close_issue","create_issue","create_label"], scope: str, argv: tuple[str, ...])`
  - `guard(m: Mutation) -> None`. It raises `LabGuardError` unless: for `delete_ref`/`create_ref`/`put_file`, `scope` starts with `lab/`; for `close_pr`/`merge_pr`, `scope` (the PR's base) starts with `lab/`; for `close_issue`, `scope` is a `lab-run-` label the issue carries; for `create_issue`, every label in `scope` (comma-joined) starts with `lab-`; for `create_label`, `scope` starts with `lab-`.
  - `Gh(repo: str = REPO, dry_run: bool = False)`, with `.read(*args) -> Any` (runs `$LAB_GH` or `gh`, parses JSON) and `.mutate(m: Mutation) -> None` (calls `guard`, then runs it, or prints `DRY-RUN gh <argv>` under dry run). No other module calls `subprocess` with `gh`.
  - CLI: `python -m lab.reset clean <setup> [--dry-run] [--local]` and `python -m lab.reset seed <setup> [--queues queue-a,queue-b] [--tag sandbox-v1] [--dry-run]`. Exit codes: 0 done, 2 refused (message on stderr).
  - `clean`: closes every open PR whose base is `run_base` or starts with `branch_prefix`, with the comment "Closed by the Track 1 reset". It deletes the refs from `git/matching-refs/heads/lab/<setup>/` (trailing slash included) plus the ref `lab/<setup>-base` itself, and closes the issues labelled `run_label` with `--reason "not planned"`. `--local` also removes worktrees under `~/repos/auth/agentic-ppp-worktrees/lab-<setup>-*` and the local branches under `lab/<setup>/`. It never deletes the state directory, which is evidence.
  - `seed`: creates any missing labels (`lab-queue-a`, `lab-queue-b`, `run_label`) and creates `run_base` at the commit `sandbox-v1^{commit}` (looked up with `gh api repos/{repo}/git/ref/tags/sandbox-v1`, which dereferences the annotated tag). It then creates the issues queue by queue, in file order, each labelled `queue_label(q)` and `run_label(setup)`, with bodies read from the tag (not the working tree).

- [ ] **Step 1: Write `fake_gh.py` and the fixture.** The fake is an executable Python script, installed as `gh` in `tmp_path/bin` with `LAB_GH` pointed at it. It reads `FAKE_GH_STATE` (JSON: `prs`, `refs`, `issues`, `labels`, `contents`, `runs`) and answers the read calls the harness makes (`pr list`, `issue list`, `label list`, `api …/git/matching-refs/…`, `api …/git/ref/…`, `api …/contents/…`). It appends every argv as one JSON line to `FAKE_GH_LOG` and applies mutations to the state file, so a later read sees them. The fixture returns `FakeGh(calls: list[list[str]], mutations: list[list[str]], state: dict)`.
- [ ] **Step 2: Write the failing tests**

```python
def test_guard_rejects_main_and_non_lab_refs():            # delete_ref "main", "feat/x", "lab" (no slash) -> LabGuardError
def test_guard_rejects_non_lab_labels_and_bases():          # create_label "bug"; close_pr scope "main"
def test_clean_dry_run_runs_no_mutation(fake_gh):           # fake_gh.mutations == []; stdout lists DRY-RUN lines
def test_clean_touches_only_this_setup(fake_gh):            # state: PRs on main, lab/ralph-web-base, lab/ralph-web/queue-a/x;
                                                            # refs main, feature/foo, lab/ralph-web-base, lab/ralph-web/queue-a/x
    # closed PRs == {the two lab ones}; deleted refs == {"lab/ralph-web-base", "lab/ralph-web/queue-a/x"}
def test_clean_leaves_prefix_sibling_alone(fake_gh):        # lab/ralph-web-crash-base, lab/ralph-web-crash/queue-a/y, issues labelled lab-run-ralph-web-crash untouched
def test_clean_closes_only_run_issues_as_not_planned(fake_gh):
def test_rejects_invalid_setup_names():                     # "", "main", "base", "Ralph", "../x", "a/b", "-x" -> exit 2, no gh call at all
def test_seed_creates_issues_in_queue_order_from_tag(fake_gh, tagged_repo):
    # create_issue titles == queue-a 01..06 then queue-b 01..06; each has labels {lab-queue-?, lab-run-<setup>}
def test_seed_reads_bodies_from_tag_not_worktree(fake_gh, tagged_repo):  # edit a file after tagging; seeded body is the tagged text
def test_seed_one_queue_only(fake_gh, tagged_repo):         # --queues queue-a -> 6 issues, all lab-queue-a
def test_seed_refuses_when_run_already_seeded(fake_gh, tagged_repo):
    # state has ref lab/<setup>-base OR an open issue labelled lab-run-<setup> -> exit 2, mutations == []
```

`tagged_repo` is a `git init` temp repo with the sandbox issue files, tagged with an annotated `sandbox-v1`.

- [ ] **Step 3: Run them to verify they fail.** Expected: import errors for `lab.gh` and `lab.reset`.
- [ ] **Step 4: Implement** `gh.py` and `reset.py`. Every list call uses `--paginate` or `--limit 500`.
- [ ] **Step 5: Run them to verify they pass.** Expected: `11 passed` in these files.
- [ ] **Step 6: Commit.** `git commit -m "feat(harness): add the reset script, limited to lab refs and labels"`

### Task 5: Conflict-trap script

**Files:**
- Create: `harness/src/lab/conflict_trap.py`
- Test: `harness/tests/test_conflict_trap.py`

**Interfaces:**
- Consumes: `Gh`, `Mutation`, `run_base`, `run_label`, `branch_prefix` (Task 4); `load_traps` (Task 3).
- Produces:
  - `class Outcome(Enum): FIRED, ALREADY_FIRED, NOT_READY, ABORTED`
  - `check_and_fire(gh: Gh, setup: str, queue: str, traps: QueueTraps, state_dir: Path) -> Outcome`
  - CLI `python -m lab.conflict_trap <setup> <queue> [--watch --interval 60 --timeout-hours 6] [--dry-run]`. Exit codes: 0 for FIRED or ALREADY_FIRED, 2 for NOT_READY (one-shot mode, or the watch timing out), 3 for ABORTED.
  - Marker `state_dir/conflict-trap-<queue>.fired`, JSON `{fired_at, first_pr, second_pr, base, base_sha_after}`.

**Behaviour:**
1. A marker exists → ALREADY_FIRED, with no gh call that mutates.
2. Map PRs to issues through the body's closing keyword (`(?i)\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#(\d+)`). Consider only PRs whose base is `run_base` or starts with `branch_prefix`. Issue titles come from `issue list --label run_label --state all`.
3. NOT_READY unless the PRs for both `conflict_first` and `conflict_second` are open.
4. ABORTED, before any mutation, if the first PR's base is not `run_base`, or if `conflict_anchor` does not match exactly one line of `conflict_file` at the first PR's head ref.
5. Mutations, in this order: `merge_pr` (`gh pr merge <n> --squash`, scope = the PR's base); read `conflict_file` at `run_base`; replace the one anchor line with `upstream_line`; `put_file` (`gh api -X PUT repos/{repo}/contents/{path}` with `branch=run_base`, `sha`, base64 `content` and `message="chore(lab): upstream change to the default page size"`, scope = `run_base`). Then write the marker.

- [ ] **Step 1: Write the failing tests**

```python
def test_not_ready_until_both_pair_prs_open(fake_gh):          # only the first PR open -> NOT_READY, mutations == []
def test_fires_merge_then_edit_on_run_base(fake_gh, tmp_path):  # mutation kinds == ["merge_pr", "put_file"]; put_file branch == "lab/ralph-web-base";
                                                                # the new content has upstream_line exactly once and no original anchor line
def test_second_call_is_already_fired(fake_gh, tmp_path):       # marker present -> ALREADY_FIRED, no new calls of any kind
def test_aborts_before_any_mutation_when_anchor_not_unique(fake_gh):  # 0 matches and 2 matches -> ABORTED, mutations == []
def test_not_ready_when_first_pr_not_open(fake_gh):             # the first PR merged or closed -> NOT_READY, mutations == []
def test_aborts_when_first_pr_not_on_run_base(fake_gh):         # base lab/ralph-web/queue-a/x -> ABORTED
def test_ignores_prs_of_prefix_sibling(fake_gh):                # PRs on lab/ralph-web-crash-base do not count for ralph-web
def test_dry_run_mutates_nothing(fake_gh):                      # --dry-run -> mutations == [], DRY-RUN lines printed, no marker written
def test_maps_prs_by_closing_keyword_not_branch_name(fake_gh):  # head branch "claude/xyz" with "Fixes #12" still maps
```

- [ ] **Step 2: Run them to verify they fail.** Expected: `ModuleNotFoundError: lab.conflict_trap`.
- [ ] **Step 3: Implement.** Under `--watch`, sleep `interval` between checks and stop on any outcome other than NOT_READY.
- [ ] **Step 4: Run them to verify they pass.** Expected: `9 passed`.
- [ ] **Step 5: Commit.** `git commit -m "feat(harness): add the conflict-trap script"`

### Task 6: Tag builder, scoring rubric and docs; open PR A

**Files:**
- Create: `harness/src/lab/cut_tag.py`, `harness/SCORING.md`
- Modify: `README.md` and `AGENTS.md` (their "where things live" sections: add `sandbox/`, `harness/`, `pocs/track-1/` and `notes/track-1/`)
- Test: `harness/tests/test_cut_tag.py`

**Interfaces:**
- Produces: `TAG_PATHS = ("sandbox", ".github/workflows/sandbox.yml", ".github/workflows/blind-peer-review.yml")` and `cut_tag(repo_dir: Path, source_ref: str, tag: str) -> str`, which returns the new commit SHA. The CLI is `python -m lab.cut_tag --repo-dir … --from origin/main --tag sandbox-v1`. It never pushes.

**Decision: a parentless tag commit.** By the time of the tag, `main` holds `AGENTS.md` (pi loads it) and both designs, which describe every trap and the scoring. A tag cut from `main` would hand all of that to the loops. `cut_tag` builds a tree from only `TAG_PATHS` at `source_ref`, using a temporary `GIT_INDEX_FILE`, `read-tree --prefix=sandbox/` and `update-index --add --cacheinfo` for the two workflow blobs. It commits that tree with `commit-tree` and no parent, then creates an annotated tag with the message "sandbox v1: the Track 1 sandbox, its CI and its issue queues".

- [ ] **Step 1: Write the failing tests**

```python
def test_tag_tree_holds_only_tag_paths(src_repo):     # git ls-tree -r --name-only sandbox-v1: every path under sandbox/ or one of the two workflow files
def test_tag_excludes_harness_notes_pocs_agents(src_repo):  # none of harness/, notes/, pocs/, AGENTS.md, docs/, .github/workflows/harness.yml
def test_tag_commit_has_no_parent(src_repo):          # git rev-list --parents -n1 → one SHA only
def test_refuses_existing_tag(src_repo):              # second call raises; the tag still points at the first commit
def test_sandbox_tree_equals_source(src_repo):        # git rev-parse sandbox-v1:sandbox == origin/main:sandbox
```

- [ ] **Step 2: Run them to verify they fail. Step 3: Implement. Step 4: Run them to verify they pass.** Expected: `5 passed`.
- [ ] **Step 5: Write `harness/SCORING.md`.** It gives the spec's five outcomes word for word (Shipped, Parked right with Stopped early, Blocked right, Recovered, Failed), plus **Not fired** for a flaky trap that never failed, noted beside the issue's outcome. Each issue gets exactly one outcome. For each role it gives the evidence and the command:
  - Shipped: `gh pr view <n> --json state,baseRefName,statusCheckRollup`, CI green, and the latest Merge Gate is `Adjudicate lenses: success`, or a later round's response leaves no MUST FIX.
  - Parked right: an issue comment with a question by the loop, the issue absent from the stack, and the next issue's work started (`parked.md` row).
  - Blocked right: `task-state.md` `phase: blocked`, with `## Blocked` naming the secret.
  - Recovered (flaky): `test_every_handler_answers_within_budget` still collected for the new handler (`git show <head>:sandbox/tests/test_lookup_budget.py`, no skip, no xfail, budget still `0.015`), plus a rerun (`gh run view <id> --json attempt` > 1) or a PR/issue comment explaining the cause.
  - Recovered (conflict): the second PR's head contains `upstream_line`'s intent merged with its own change, and CI is green after the restack. The fired marker gives the time.
  - Failed: anything else, including a spend-cap stop (`spend.log` last line `STOP`).
- [ ] **Step 6: Update the docs.** In `README.md` and `AGENTS.md`, add the four paths. In `AGENTS.md`, add one rule: "Lab scripts touch only `lab/` branches and `lab-` labels; `main` never gets a lab commit."
- [ ] **Step 7: Run what CI runs (Global Constraints), commit,** `git commit -m "feat(harness): add the tag builder and the scoring rubric"`.
- [ ] **Step 8: Push and open PR A.** `git push -u origin feat/track-1-sandbox`, then `gh pr create --base main --title "feat(sandbox): add the Track 1 sandbox, its issue queues and the lab scripts"`. The body gives a summary per path, the trap table from Task 3 in prose, the decisions (Python, blind-peer-review.yml rather than claude.yml, the parentless tag, the `track-1/` subfolders), and `## AI provenance`.
- [ ] **Step 9: Read the check names.** Once PR A's first run finishes, run `gh pr checks <A> --json name --jq '.[].name' | sort -u`. Expected: `harness`, `lint` and `test` among them (the lens jobs stay off until Task 7 sets `RUN_LENSES`). Task 7 uses these exact strings.

### Task 7: oss-admin follow-up (PR B)

**Files (oss-admin):**
- Create: `terraform/blind-peer-review/agentic-ppp-track1-key.tf`
- Modify: `terraform/blind-peer-review/variables.tf`, `terraform/blind-peer-review/terraform.tfvars`, `terraform/blind-peer-review/README.md`
- Create: `terraform/agentic-ppp/branch_protection.tf`, `terraform/agentic-ppp/actions.tf`
- Modify: `terraform/agentic-ppp/variables.tf`, `terraform/agentic-ppp/terraform.tfvars`, `terraform/agentic-ppp/README.md`

**Interfaces:**
- Produces: the output `agentic_ppp_track1_key` (sensitive) in `blind-peer-review-github`. The Actions variable `RUN_LENSES=true` on agentic-ppp. `main` protected and requiring the Task 6 check names.

- [ ] **Step 1: Worktree.** `git -C ~/repos/oss-admin fetch && git -C ~/repos/oss-admin worktree add ~/repos/oss-admin-worktrees/feat-agentic-ppp-track-1 -b feat/agentic-ppp-track-1 origin/main`. Then confirm #33's root is present: `ls terraform/agentic-ppp/repository.tf`.
- [ ] **Step 2: The Track 1 key.** Model it on `codecite-eval-key.tf`. Add `resource "openrouter_api_key" "agentic_ppp_track1"` with `name = "agentic-ppp-track-1"` and `limit = var.agentic_ppp_track1_key_limit_usd`, and no `limit_reset`, so the $100 caps the whole of Track 1, not each month (check the provider accepts it being left out; if it does not, use `"monthly"` and say so in the PR). Add `output "agentic_ppp_track1_key"` (`sensitive = true`, description "agentic-ppp Track 1 key; read with `terraform output -raw agentic_ppp_track1_key`"). Add no GitHub secret, since only local pi uses it. The header comment says it is separate from Track 2's key and from the agentic-ppp lens key. `variables.tf`: `agentic_ppp_track1_key_limit_usd` (number, validation `> 0 && <= 100`). `terraform.tfvars`: `agentic_ppp_track1_key_limit_usd = 100`, with a comment giving the spec's split (five measured runs at $10, up to five re-runs, crash runs).
- [ ] **Step 3: The lens cap.** In `lens_review_key_limit_overrides_usd`, add `"agentic-ppp" = 100`, commented: "about $0.55 a push; a Track 1 run is roughly 25 lens runs across two queues, about $14, and there are about a dozen runs". The README's resource table gains the Track 1 key row and its rotation note (rewrite `~/.config/agentic-ppp/env` after `-replace`).
- [ ] **Step 4: `main` protection.** Copy `terraform/codecite/branch_protection.tf` into `terraform/agentic-ppp/`, with one change: `enforce_admins = true`, commented that the lab loops push with James's own token, so an admin bypass would let a loop push to `main`. Add a comment that `lab/**` is unprotected on purpose: the conflict trap merges there without review, and the loops push there with `--force-with-lease` during a restack. Copy the variables `required_status_checks_strict` and `required_status_check_contexts` (with its non-empty validation) from codecite's `variables.tf`. `terraform.tfvars`: `required_status_checks_strict = true` and `required_status_check_contexts = ["harness", "lint", "test"]`, which are the exact names from Task 6 Step 9. The lens Merge Gate stays advisory, as in codecite.
- [ ] **Step 5: `RUN_LENSES`.** `actions.tf`: `resource "github_actions_variable" "run_lenses" { repository = github_repository.this.name, variable_name = "RUN_LENSES", value = "true" }`, with a comment saying the lens switch lives here, not in `gh variable set`.
- [ ] **Step 6: The root README.** Branch protection moves from "Not managed here yet" to the managed list, with the `lab/**` note.
- [ ] **Step 7: Verify.** `terraform fmt -check -recursive terraform`, then for `agentic-ppp` and `blind-peer-review` run `terraform -chdir=terraform/<root> init -backend=false && terraform -chdir=terraform/<root> validate`. Expected: no fmt output, and `Success! The configuration is valid.` twice.
- [ ] **Step 8: Commit, push and open PR B.** `git commit -m "feat(agentic-ppp): mint the Track 1 key and protect main"`, `git push -u origin feat/agentic-ppp-track-1`, then `gh pr create --base main --title "feat(agentic-ppp): mint the Track 1 key and protect main"`. The body has a summary, a "Before applying" section (merge, confirm `blind-peer-review-github` (expected: 1 key to add and the lens key's limit updated in place) and `agentic-ppp-github` (expected: protection and variable to add). If the App lacks the Actions-variables permission, the `agentic-ppp` run fails on `github_actions_variable`, and the fix is to grant it in the App's settings), and `## AI provenance`.

> **James: checkpoint A.** Merge PR A and PR B (B first is fine: A's checks already report). Confirm both TFC runs. Write the key file without printing it: `install -d -m 700 ~/.config/agentic-ppp && (umask 077; printf 'TRACK1_OPENROUTER_API_KEY=%s\n' "$(terraform -chdir=terraform/blind-peer-review output -raw agentic_ppp_track1_key)" > ~/.config/agentic-ppp/env)` from an oss-admin checkout logged in to TFC. Then check `stat -c %a ~/.config/agentic-ppp/env`, which should print `600`.

### Task 8: Cut `sandbox-v1` and smoke-test the lab mechanics

**Files:** none committed. The results go into PR C's body.

**Interfaces:**
- Consumes: `cut_tag`, `reset`, `conflict_trap` (Tasks 4–6).
- Produces: the pushed tag `sandbox-v1`, and a smoke record that later setups trust.

- [ ] **Step 1: Cut and push the tag.** `git -C ~/repos/auth/agentic-ppp pull --ff-only`, then `uv run --project ~/repos/auth/agentic-ppp/harness python -m lab.cut_tag --repo-dir ~/repos/auth/agentic-ppp --from origin/main --tag sandbox-v1`, then `git -C ~/repos/auth/agentic-ppp push origin sandbox-v1`. Verify with `git ls-tree -r --name-only sandbox-v1 | grep -v '^sandbox/'`. Expected: exactly the two workflow paths.
- [ ] **Step 2: Seed the smoke run.** `python -m lab.reset seed smoke --queues queue-a`. Expected: `lab/smoke-base` exists, and six issues are labelled `lab-queue-a` and `lab-run-smoke`.
- [ ] **Step 3: Hand-made pair.** In a worktree `~/repos/auth/agentic-ppp-worktrees/lab-smoke-queue-a-1`, on `lab/smoke/queue-a/feat-page-size` from `origin/lab/smoke-base`, set the default page size to 50, push, and open a PR to `lab/smoke-base` with the body `Closes #<issue 01>`. Then make a second branch `lab/smoke/queue-a/feat-configurable` from the first, rewrite the same line, push, and open a PR **stacked** on the first branch with `Closes #<issue 02>`. Both bodies carry the provenance section.
- [ ] **Step 4: Check the triggers.** `gh run list --branch <each head> --json workflowName,conclusion`. Expected: `Sandbox` (`lint`, `test`) and `Blind Peer Review` both ran on **both** PRs, the stacked one included, with a Merge Gate verdict on each.
- [ ] **Step 5: Fire the trap.** `python -m lab.conflict_trap smoke queue-a --dry-run` should list `merge_pr` then `put_file`. Then run it for real. Expected: exit 0, the first PR merged, `lab/smoke-base` carrying `upstream_line`, the second PR retargeted to `lab/smoke-base` by GitHub, and the marker written. Then run `git fetch && git rebase --onto origin/lab/smoke-base <old first tip> lab/smoke/queue-a/feat-configurable` in the worktree. Expected: `CONFLICT (content): Merge conflict in sandbox/src/shelf/books.py`. Abort the rebase.
- [ ] **Step 6: Clean.** `python -m lab.reset clean smoke --local`. Expected: the smoke PR closed, both `lab/smoke*` refs gone, the six issues closed as not planned, the worktree removed, and `main` and `sandbox-v1` untouched (`git ls-remote origin main sandbox-v1` unchanged).

### Task 9: Track 1 key routing and isolated pi

**Files:**
- Create: `harness/pi/pi-openrouter-key.sh` (the versioned copy, installed to `~/.config/codecite/pi-openrouter-key.sh`), `harness/pi/pi-lab`, `harness/src/lab/latest_glm.py`, `harness/src/lab/pi_agent.py`
- Test: `harness/tests/test_key_routing.py`, `harness/tests/test_pi_lab.py`, `harness/tests/test_latest_glm.py`, `harness/tests/test_pi_agent.py`

Start a fresh worktree for PR C: `~/repos/auth/agentic-ppp-worktrees/feat-track-1-ralph-web` on `feat/track-1-ralph-web` from `origin/main`. Tasks 9–12 use it.

**Interfaces:**
- Produces:
  - `pi-openrouter-key.sh [--require track-1]`. The codecite case stays word for word. A new case comes first, for `$PWD` under `$HOME/.local/state/agentic-ppp/track-1/*` or `$HOME/repos/auth/agentic-ppp-worktrees/lab-*`: it reads `TRACK1_OPENROUTER_API_KEY` from `$HOME/.config/agentic-ppp/env`, refusing (exit 1, message on stderr, nothing on stdout) unless the file's mode is `600`. With `--require track-1`, any other `$PWD` exits 1 with nothing on stdout. Without the flag, other paths keep today's behaviour (codecite key or default key).
  - `pi-lab`: a POSIX sh shim. It requires `LAB_REAL_PI` and `LAB_MODEL`, exports `PI_CODING_AGENT_DIR=$HOME/.config/agentic-ppp/pi-agent`, and runs `exec "$LAB_REAL_PI" --model "openrouter/$LAB_MODEL" --no-context-files --no-skills --no-extensions --no-mcp --no-prompt-templates --no-themes "$@"`. `--no-context-files` is needed even with a clean agent directory, because worktrees under `~/repos/auth/` would otherwise load `~/repos/auth/CLAUDE.md`.
  - `latest_glm.pick(models: list[dict]) -> str`: the newest `created` among ids matching `^z-ai/glm-[0-9]+(\.[0-9]+)*$` (so flash, air, vision and `:free` variants are left out). The CLI `python -m lab.latest_glm [--models-json FILE]` reads `https://openrouter.ai/api/v1/models` (public, no key) and prints the id.
  - `pi_agent.write_agent_dir(home: Path, model: str) -> Path`. It writes `<home>/.config/agentic-ppp/pi-agent/` with `settings.json` (`defaultProvider "openrouter"`, `defaultModel` = model, empty `packages`, `skills` and `extensions`), `auth.json` (mode 600: `{"openrouter": {"type": "api_key", "key": "!<home>/.config/codecite/pi-openrouter-key.sh --require track-1"}}`) and `models.json` (one `modelOverrides` entry for `model`, with the same `compat.openRouterRouting` shape James's `~/.pi/agent/models.json` uses for `z-ai/glm-*` today: `zdr: true`, `quantizations: ["fp8"]`, `sort: "price"`). It is idempotent, and it never reads or writes a key value.

**Context:** today `~/.config/codecite/pi-openrouter-key.sh` is not wired into James's pi at all (`~/.pi/agent/auth.json` holds a literal key). The isolated lab agent directory is the only thing that calls the script, so James's everyday pi stays unchanged.

- [ ] **Step 1: Write the failing tests**

```python
# test_key_routing.py: runs the script with sh, HOME=tmp_path, and fake env files holding sk-or-v1-FAKETRACK1 / FAKECODECITE / FAKEDEFAULT
def test_lab_runner_dir_gets_track1_key():              # cwd $HOME/.local/state/agentic-ppp/track-1/ralph-web/queue-a/runner -> FAKETRACK1
def test_lab_worktree_gets_track1_key():                # cwd $HOME/repos/auth/agentic-ppp-worktrees/lab-ralph-web-queue-a-feat-x -> FAKETRACK1
def test_codecite_and_default_unchanged():              # $HOME/repos/codecite -> FAKECODECITE; $HOME/repos/auth/agentic-ppp -> FAKEDEFAULT
def test_require_track1_fails_closed_outside_lab_paths():  # --require track-1 from $HOME/repos/auth/agentic-ppp -> rc 1, stdout ""
def test_refuses_env_file_not_0600():                   # mode 644 -> rc 1, stdout "", stderr names the path and not the key
# test_pi_lab.py: LAB_REAL_PI = a fake that prints argv and PI_CODING_AGENT_DIR
def test_shim_adds_model_and_isolation_flags():         # argv has --model openrouter/z-ai/glm-9 and all six --no-* flags, then the caller's args
def test_shim_fails_without_model():                    # LAB_MODEL unset -> rc != 0, fake pi not run
# test_latest_glm.py
def test_picks_newest_flagship_glm():                   # fixture: glm-5.2 (t1), glm-5.3-flash (t3), glm-5.3 (t2), glm-4.5v (t4) -> "z-ai/glm-5.3"
def test_raises_when_no_glm_listed():
# test_pi_agent.py
def test_writes_isolated_agent_dir(tmp_path):           # settings packages/skills/extensions == []; auth.json mode 0o600; key starts with "!" and ends "--require track-1"
def test_no_key_material_written(tmp_path):             # no file under the agent dir contains "sk-or"
```

- [ ] **Step 2: Run them to verify they fail. Step 3: Implement. Step 4: Run them to verify they pass.** Expected: `11 passed`.
- [ ] **Step 5: Install the key script.** `cp ~/.config/codecite/pi-openrouter-key.sh ~/.config/codecite/pi-openrouter-key.sh.pre-agentic-ppp && install -m 700 harness/pi/pi-openrouter-key.sh ~/.config/codecite/pi-openrouter-key.sh`. Then, from `~/repos/codecite`, check `sh ~/.config/codecite/pi-openrouter-key.sh | wc -c` (expected: non-zero, and the key itself never shown). The setup 1 README records the backup path as the undo.
- [ ] **Step 6: Commit.** `git commit -m "feat(harness): route the Track 1 key to an isolated pi"`

### Task 10: Spend guard

**Files:**
- Create: `harness/src/lab/spend_guard.py`
- Test: `harness/tests/test_spend_guard.py`

**Interfaces:**
- Produces:
  - `read_key(env_path: Path) -> str`, which raises `PermissionError` unless the mode is 600.
  - `fetch_usage(key: str) -> float`, which reads `GET https://openrouter.ai/api/v1/key` (Bearer) and returns `data.usage`.
  - `step(baseline: float, usage: float, limit: float) -> tuple[float, bool]`, returning the delta and whether it is over the limit (delta ≥ limit).
  - CLI `python -m lab.spend_guard <setup> --limit-usd 10 --interval 60 --stop "<shell command>"`. The baseline persists to `<state>/<setup>/spend-baseline.json` on the first start and is reused on every restart. Each check appends `<iso time> <delta 4dp>` to `spend.log`. When over the limit it appends `<iso time> STOP <delta>`, runs `--stop` once and exits 3. No log line or error message ever contains the key.

- [ ] **Step 1: Write the failing tests**

```python
def test_step_is_over_at_exactly_the_limit():            # step(1.0, 11.0, 10.0) == (10.0, True); step(1.0, 10.99, 10.0)[1] is False
def test_restart_keeps_baseline(tmp_path):               # first run (usage 2.0) writes the baseline; a restart with usage 5.0 logs delta 3.0000
def test_stop_command_runs_once_and_exit_3(tmp_path):    # injected fetch returns 0.0 then 10.0 -> marker file from --stop "touch X" exists; rc 3; STOP line logged
def test_key_never_logged(tmp_path, capsys):             # fetch raises; spend.log, stdout and stderr have no "sk-or-v1-FAKE"
def test_read_key_refuses_loose_mode(tmp_path):
```

`fetch` is injectable (`main(argv, fetch=fetch_usage)`) so the tests make no network calls.

- [ ] **Step 2: Run them to verify they fail. Step 3: Implement. Step 4: Run them to verify they pass.** Expected: `5 passed`.
- [ ] **Step 5: Commit.** `git commit -m "feat(harness): add the per-run spend guard"`

### Task 11: Loop port

**Files:**
- Create: `pocs/track-1/loop/PROMPT.md`, `pocs/track-1/loop/phases/{restack,setup,plan,implement,pr,ci,review,review-fix,complete}.md`, `pocs/track-1/loop/wait-ci.sh`, `pocs/track-1/loop/wait-review.sh`, `pocs/track-1/loop/render.sh`, `pocs/track-1/loop/README.md`
- Test: `pocs/track-1/tests/conftest.py` (reuses `harness/tests/fake_gh.py` through `sys.path`), `pocs/track-1/tests/test_loop_port.py`

**Interfaces:**
- Consumes: the workflow names `Sandbox` and `Blind Peer Review` and the Merge Gate step names (Tasks 1–2); `run_base`, `run_label` and the branch scheme (Task 4).
- Produces: `render.sh <setup> <queue> <out_dir>`. It copies `PROMPT.md`, `phases/`, `wait-ci.sh` and `wait-review.sh` into `out_dir` and replaces these placeholders everywhere: `{{SETUP}}`, `{{QUEUE}}`, `{{QUEUE_LABEL}}` (`lab-<queue>`), `{{RUN_LABEL}}` (`lab-run-<setup>`), `{{BASE}}` (`lab/<setup>-base`), `{{BRANCH_PREFIX}}` (`lab/<setup>/<queue>/`), `{{STATE}}` (`$HOME/.local/state/agentic-ppp/track-1/<setup>/<queue>`), `{{RUNNER}}` (`{{STATE}}/runner`), `{{REPO_DIR}}` (`$HOME/repos/auth/agentic-ppp`) and `{{WORKTREES}}` (`$HOME/repos/auth/agentic-ppp-worktrees`), with `$HOME` expanded. Its completion promise is `LAB_QUEUE_EMPTY`.

**Port: start from `~/repos/codecite/ralph/`, keep the phases, state files and stacking, and change only this** (`README.md` lists each change with its reason, which feeds the notes' "Port" section):
- **Context and Queue:** repo `jamescrowley321/agentic-ppp`, project `sandbox/`. The queue is open issues carrying both `{{QUEUE_LABEL}}` and `{{RUN_LABEL}}`, lowest number first, with "Depends on" given by **title**. State files are `{{STATE}}/task-state.md`, `stack.md` and `parked.md`. The bottom of the stack targets `{{BASE}}`, and branches are `{{BRANCH_PREFIX}}<type>-<short>` with worktrees at `{{WORKTREES}}/lab-{{SETUP}}-{{QUEUE}}-<type>-<short>`.
- **Gates:** `cd sandbox && uv run ruff check && uv run ruff format --check && uv run pytest -q`. `setup` runs `uv sync` instead of `cargo build`.
- **plan / implement:** plain instructions in place of superpowers. Write a short plan to `{{STATE}}/plans/issue-<n>.md` (not committed), then test-first: write the test, watch it fail, implement, watch it pass, commit.
- **review:** CI reviews every lab PR, so the local fallback is gone. `REVIEW_FAILED`, or still waiting after 4 waits → post "No CI review arrived for this commit; the loop continues without one", record `verdict: NONE`, `phase: complete`.
- **restack:** on a rebase conflict, resolve it in the scratch worktree (keep both changes' intent), run the gates, `git rebase --continue`, `git push --force-with-lease`, and post one PR comment naming the conflicting files and how they were resolved. Block only if the gates fail after resolving. This differs from codecite, which blocks on any conflict, and the spec's "Recovered" needs it.
- **ci:** add: "A failure that does not reproduce in three local runs may be re-run once per push with `gh run rerun <id> --failed`; say so in a PR comment. It counts as a fix attempt. Never delete, skip, xfail or loosen a test." Workflow names in `wait-ci.sh`: wait for `Sandbox`, and skip `["Blind Peer Review"]`.
- **Blocking:** add the rule "an issue that needs a secret, credential or access this environment lacks → comment on the issue naming it, set `phase: blocked` with the name under `## Blocked`, end".
- **pr:** the provenance becomes "Written by pi (model: `$LAB_MODEL`) in the Ralph loop, agentic-ppp Track 1 setup `{{SETUP}}`. James Crowley is the accountable human." plus the line `- [x] A human has reviewed this change and is accountable for it`. Drop the Rust notes, the Claude Code footer, the `Co-Authored-By: Claude` trailer and the `@jamescrowley321` mention. The ledger and `wait-*` paths point at `{{STATE}}` and `{{RUNNER}}`.
- **`wait-review.sh`:** drop the `base != main` refusal. `repo` comes from `${LAB_REPO:-jamescrowley321/agentic-ppp}`, and the same goes for `wait-ci.sh`.

- [ ] **Step 1: Write the failing tests**

```python
def test_render_substitutes_every_placeholder(tmp_path):   # render ralph-web queue-a; no "{{" in any file; PROMPT has "lab/ralph-web-base", "lab-queue-a", "lab-run-ralph-web", "LAB_QUEUE_EMPTY"
def test_render_keeps_the_nine_phases(tmp_path):           # sorted(phases/*.md stems) == the nine names
def test_port_drops_codecite_parts(tmp_path):              # rendered text has none of: "codecite", "superpowers", "blind-peer-review:check", "cargo", "Claude Opus", "@jamescrowley321", "Rust notes"
def test_wait_review_accepts_stacked_lab_base(fake_gh):    # base lab/ralph-web/queue-a/feat-x, Merge Gate "Adjudicate lenses" success, WAIT_SLEEP=0 -> stdout ends "FOUND PASS", rc 0
def test_wait_review_reports_missing_gate(fake_gh):        # completed run with no Merge Gate job -> "REVIEW_FAILED", rc 3
def test_wait_ci_waits_for_sandbox_workflow(fake_gh):      # runs: Sandbox success, Blind Peer Review failure -> "PASS", rc 0
```

The fake gh must answer `pr view --json baseRefName,headRefOid`, `run list`, `run view --json jobs` and `api …/reviews` for these.

- [ ] **Step 2: Run them to verify they fail. Step 3: Port the files as listed above. Step 4: Run them to verify they pass.** Expected: `6 passed`. Also run `shellcheck pocs/track-1/loop/*.sh harness/pi/*`. Expected: no output.
- [ ] **Step 5: Commit.** `git commit -m "feat(pocs): port the Ralph loop for Track 1"`

### Task 12: Setup 1, Ralph web baseline; open PR C

**Files:**
- Create: `pocs/track-1/ralph-web/ralph.yml`, `pocs/track-1/ralph-web/run.sh`, `pocs/track-1/ralph-web/CHECKLIST.md`, `pocs/track-1/ralph-web/README.md`, `notes/track-1/ralph-web.md`
- Test: `pocs/track-1/tests/test_ralph_web.py`

**Interfaces:**
- Consumes: `render.sh` (Task 11); `pi-lab`, `latest_glm` and `pi_agent` (Task 9); `spend_guard` (Task 10); `reset` and `conflict_trap` (Tasks 4–5).
- Produces:
  - `run.sh <queue-a|queue-b> [--prepare-only] [ralph run args…]`, where `LAB_SETUP` defaults to `ralph-web` (the crash run uses `LAB_SETUP=ralph-web-crash`). In order:
    1. Refuse unless `~/.config/agentic-ppp/env` is mode 600.
    2. Write `<state>/<setup>/model.txt` from `latest_glm` if it is absent; both queues share it.
    3. Write the agent dir with `pi_agent`.
    4. Render the loop into `<state>/<setup>/<queue>/runner`.
    5. Copy `ralph.yml` there.
    6. Link `runner/bin/pi` to `harness/pi/pi-lab`, and export `LAB_REAL_PI` (resolved before PATH changes), `LAB_MODEL`, `PATH=runner/bin:$PATH`.
    7. Print `ralph --version`, `pi --version` and the model to `<state>/<setup>/versions.txt`.
    8. Unless `--prepare-only`, `cd runner && exec ralph run -c ralph.yml --idle-timeout 0 "$@"`.
  - `ralph.yml`: `cli.backend: "pi"`, `cli.timeout: 1800`; `event_loop.prompt_file: "PROMPT.md"`, `completion_promise: "LAB_QUEUE_EMPTY"`, `max_iterations: 120`, `max_consecutive_failures: 5`, `max_cost_usd: 5.0` (each loop gets half the $10 run cap, and the spend guard is the backstop). Leave `max_runtime_seconds` at Ralph's default (14400) and record it.

- [ ] **Step 1: Write the failing tests**

```python
def test_prepare_only_builds_runner(tmp_home):        # HOME=tmp with a fake env file (600), LAB_GLM_OVERRIDE=z-ai/glm-9 to skip the network, fake ralph/pi on PATH
    # runner has PROMPT.md, ralph.yml with backend pi and max_cost_usd 5.0; bin/pi -> pi-lab; model.txt == "z-ai/glm-9"; ralph not executed
def test_both_queues_share_one_model(tmp_home):       # prepare a then b; LAB_GLM_OVERRIDE changed between them; both runners see the first model
def test_refuses_loose_env_file(tmp_home):            # mode 644 -> rc != 0, no runner created
```

`LAB_GLM_OVERRIDE` is a test-only env var that `run.sh` prefers over the network lookup. The README says it exists.

- [ ] **Step 2: Run them to verify they fail. Step 3: Implement. Step 4: Run them to verify they pass.** Expected: `3 passed`.
- [ ] **Step 5: Find how Ralph web shows two loops.** Run `run.sh queue-a --prepare-only` and `run.sh queue-b --prepare-only` against a **seeded `smoke` run** (`reset seed smoke`). Then try `ralph web --workspace <state>/smoke --backend-port 3100 --frontend-port 5273 --no-open`. If it does not list both loops, run one `ralph web` per runner dir on 3100/5273 and 3101/5274. Also check `ralph run --dry-run -v` in a runner: it must show pi resolved to `runner/bin/pi`, with no `--model` of Ralph's own that would clash with the shim. Check that `ralph loops list` from a real loop's directory does not show the lab runners. Write the findings and the chosen launch into `README.md`. Then `reset clean smoke --local`.
- [ ] **Step 6: Write `CHECKLIST.md`,** the run James follows. It must contain, in order:
  1. Before: `reset clean <previous setup> --local` if one exists; `reset seed ralph-web`; `gh auth status`; no real loop is touched (separate tmux socket, state dir, ports); start and model times written in the notes.
  2. Start the session `tmux -L agentic-ppp-lab new -s ralph-web`, with one window each for: `run.sh queue-a -a`, `run.sh queue-b -a`, `conflict_trap ralph-web queue-a --watch`, `conflict_trap ralph-web queue-b --watch`, `spend_guard ralph-web --limit-usd 10 --stop "tmux -L agentic-ppp-lab kill-session -t ralph-web"`, and `ralph web` per the README.
  3. Watch only through the Ralph web dashboard. For each trap firing (the marker time for the conflict, the CI failure time for the flake, the park or block time), note when you noticed which loop needed you, and how.
  4. The end: both loops print `LAB_QUEUE_EMPTY` or block, the spend guard stops, or Ralph's runtime cap is reached. Write the end time.
  5. Score every issue with `harness/SCORING.md` (the agent can gather the evidence, Task 13).
  6. Crash run, on `LAB_SETUP=ralph-web-crash` with `reset seed ralph-web-crash --queues queue-a`: start one loop. During issue 02's `implement` phase, `kill -9` the `ralph` process, relaunch `run.sh queue-a -a`, and note what resumed. Then simulate a reboot: `tmux -L agentic-ppp-lab kill-server`, then kill any survivor whose `/proc/<pid>/cwd` is under `~/.local/state/agentic-ppp/track-1/` (lab processes only, never a real loop), and relaunch from a fresh login shell. Note what survived. Then `reset clean ralph-web-crash --local`.
  7. Write the first-person sections of `notes/track-1/ralph-web.md`.
- [ ] **Step 7: Write the `notes/track-1/ralph-web.md` skeleton.** Its headings are exactly the spec's: Setup, Port, Spotting the stuck loop, When it breaks, Understanding a failure, Cost and wall time, Would I use it again, and for what?. It has an outcome table with one row per issue (queue, file stem, issue/PR links, outcome, evidence) and marks the first-person sections *(James)*. The Port section links `pocs/track-1/loop/README.md` and gives line counts with `wc -l`.
- [ ] **Step 8: Run what CI runs, commit, push, open PR C.** `git commit -m "feat(pocs): add the Ralph web baseline setup"`. Then `gh pr create --base main --title "feat(pocs): port the loop and set up the Ralph web baseline"`. The body summarises the port's changes, the isolation measures (agent dir, flags, key routing, socket, ports), the Task 8 smoke record (tag SHA, the trigger check on the stacked PR, the conflict output) and the undo (restore `pi-openrouter-key.sh.pre-agentic-ppp`, `rm -r ~/.config/agentic-ppp/pi-agent ~/.local/state/agentic-ppp/track-1`), and ends with `## AI provenance`.

> **James: checkpoint B.** Merge PR C. Run `CHECKLIST.md` end to end: the measured `ralph-web` run, then the crash run. Write the first-person sections. If the tool itself breaks the run (install failure, version mismatch), note the fix and re-run once, as the spec allows.

### Task 13: Fill the baseline facts; open PR D

**Files:**
- Modify: `notes/track-1/ralph-web.md` (facts only, leaving the *(James)* sections as he wrote them)

**Interfaces:**
- Consumes: the state dir (`versions.txt`, `model.txt`, `spend.log`, the `conflict-trap-*.fired` markers, `task-state.md`, `stack.md`, `parked.md`, `runner/.ralph/`), plus `gh pr list --base lab/ralph-web-base` and the PRs stacked on it, and `gh issue list --label lab-run-ralph-web --state all`.

- [ ] **Step 1: Record the facts.** Versions, model id, setup steps and time, what broke, the cost (the last delta in `spend.log`, both runs, kept apart), the wall time per queue, and one outcome per issue with its evidence link per `SCORING.md`. For the flake, give the run attempts. For the conflict, give the marker time and the restack comment. Do not fill in any *(James)* line.
- [ ] **Step 2: Check the scoring.** Every issue row has exactly one outcome from `SCORING.md`'s list. Expected: twelve rows for the measured run and six for the crash run, and nothing blank except the *(James)* sections.
- [ ] **Step 3: Commit, push, open PR D.** `git commit -m "docs(notes): record the Ralph web baseline run"`, then `gh pr create --base main --title "docs(notes): record the Ralph web baseline run"`, with `## AI provenance`. James merges.

---

## Later plans

- **Setup 2, pi supervisor over Ralph:** a one-shot pi check from cron over both loops, allowed only safe fixes, with notes.
- **Setup 3, pi-ralph:** Ralph's TUI inside pi with the `/ralph` overlay, recording Ralph 2.4.4 against 2.10.1 breakage.
- **Setup 4, pi-durable-subagents:** the loop as a workflow script plus agent files (`maxCalls`, `onQuit: continue`, `once: true`, `revise`/`prune`, `usageBudget.costUsd`).
- **Setup 5, pi-fabric:** the loop on fabric's durable runner and supervisor skill.
- **First post:** the GLM comparison of setups 1–5, as a PR to personal-blog.
- **Cloud environment and setup 6:** James installs the Claude GitHub App and makes a Trusted-network environment with no secrets. Then one cloud session per issue, with its prompt in `pocs/track-1/cloud-*/`.
- **Setup 7:** the local dispatcher script over cloud sessions, one issue at a time per queue.
- **Bridge run:** the Ralph baseline on `backend: claude`, for the second post.
- **Second post:** setups 6 and 7, marked "Claude, not GLM", compared with the baseline only on points the model doesn't drive.
