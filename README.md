# omx-ralph-local

A standalone runner for a hybrid workflow:

- planning in [oh-my-codex (OMX)](https://github.com/Yeachan-Heo/oh-my-codex) with Codex
- implementation in [open-ralph-wiggum](https://github.com/Th0rgal/open-ralph-wiggum) using the `opencode` agent backed by a local Ollama coding model
- a final strict merge gate back on Codex

The runner lives in its own repository and is callable from any target work repository.

It keeps run state inside the **target repository**, not inside this runner repository.

---

## What this is

`omx-ralph-local` is an orchestration layer, not a full framework.

It does **not**:

- generate planning artifacts by itself
- replace OMX planning
- replace Ralph's execution loop
- replace OpenCode or Ollama

It **does**:

- connect approved OMX planning artifacts to a local Ralph/OpenCode execution flow
- snapshot the approved plan for each run
- keep execution state under the target repo
- separate implementation from final merge review

---

## Dependencies and upstream projects

This runner depends on upstream tools and is designed to connect them into one workflow.

| Tool | Role in this workflow |
|---|---|
| [oh-my-codex (OMX)](https://github.com/Yeachan-Heo/oh-my-codex) | Planning workflow and artifact generation (`$deep-interview`, `$ralplan`, `.omx/` state) |
| [open-ralph-wiggum](https://github.com/Th0rgal/open-ralph-wiggum) | Iterative `ralph` loop used by `exec`, `debug`, `verify`, and `merge-gate` |
| OpenCode | Local implementation agent used through Ralph (`--agent opencode`) |
| Ollama | Local model serving backend for OpenCode |
| Codex CLI | Used by OMX for planning and optionally by Ralph as the strict merge gate |

### Dependency model

```text
Planning:
  OMX + Codex
    ↓
  .omx/plans/prd-*.md
  .omx/plans/test-spec-*.md

Execution:
  omx-ralph-local
    ↓
  Ralph + OpenCode + local Ollama model

Final gate:
  Ralph + Codex
````

---

## Design goals

| Goal                                        | Meaning                                                      |
| ------------------------------------------- | ------------------------------------------------------------ |
| Install once, reuse across projects         | The runner is separate from the target repo                  |
| Keep state in the target repo               | `.ralph/` lives under the work repo by default               |
| Keep approved artifacts immutable per run   | `prepare` copies approved OMX artifacts into a run snapshot  |
| Do not let the local model rewrite the plan | Implementation reads from the snapshotted approved artifacts |
| Separate implementation from merge approval | `merge-gate` is a distinct step                              |

---

## Repository layout

```text
bin/omx-ralph
templates/roles/executor.md
templates/roles/debugger.md
templates/roles/verifier.md
templates/roles/merge-gate.md
examples/config.example.sh
```

---

## State layout inside the target repository

By default, the runner writes state under `<target-repo>/.ralph/`.

```text
<target-repo>/
├─ .omx/
│  ├─ plans/
│  │  ├─ prd-*.md
│  │  └─ test-spec-*.md
│  └─ ...
├─ .ralph/
│  ├─ roles/
│  ├─ prompts/
│  ├─ runs/
│  │  └─ <run-id>/
│  │     ├─ approved/
│  │     ├─ logs/
│  │     └─ manifest.txt
│  ├─ current-run
│  ├─ current-branch
│  └─ current-task
└─ opencode.json
```

---

## Install

Clone this repository and put `bin/omx-ralph` on your `PATH`.

Example:

```bash
git clone https://github.com/carabinshely/omx-ralph-local.git
cd omx-ralph-local
chmod +x bin/omx-ralph
mkdir -p ~/.local/bin
ln -sf "$(pwd)/bin/omx-ralph" ~/.local/bin/omx-ralph
```

Then make sure `~/.local/bin` is on your `PATH`.

---

## Optional machine config

Create:

```bash
~/.config/omx-ralph/config
```

Start from:

```bash
mkdir -p ~/.config/omx-ralph
cp examples/config.example.sh ~/.config/omx-ralph/config
```

### Useful config values

| Variable           | Purpose                                         | Example                  |
| ------------------ | ----------------------------------------------- | ------------------------ |
| `LOCAL_MODEL`      | Local model used for `exec`, `debug`, `verify`  | `ollama/qwen3-coder:30b` |
| `OLLAMA_BASE_URL`  | Ollama HTTP API base URL                        | `http://localhost:11434` |
| `CODEX_MODEL`      | Codex model used by default                     | `gpt-5.4`                |
| `MERGE_GATE_AGENT` | Ralph agent for final gate                      | `codex`                  |
| `MERGE_GATE_MODEL` | Model used by final gate                        | `gpt-5.4`                |
| `BASE_BRANCH`      | Base branch for feature branches and comparison | `main`                   |
| `ALLOW_DIRTY`      | Allow prepare on dirty working tree             | `0` or `1`               |

For WSL (Windows Subsystem for Linux) with Ollama on Windows, the important part is that the **Ollama HTTP API** must be reachable from WSL. `doctor` checks the API, not just the local `ollama` binary.

---

## Global options

All commands support these global options before the command name.

| Option             | Meaning                               |
| ------------------ | ------------------------------------- |
| `--repo PATH`      | Run against another target repository |
| `--state-dir PATH` | Override the default state directory  |
| `--config PATH`    | Use a different config file           |
| `--verbose`        | Print extra runner logs               |

Example:

```bash
omx-ralph --repo ~/work/social-knowledge-vault doctor
omx-ralph --repo ~/work/social-knowledge-vault prepare "Implement feature X"
```

---

## Mental model

The most important distinction in this tool is:

* `plan "task"` is **informational**
* `prepare "task"` is **stateful**

```text
plan "task"
   ↓
prints the recommended OMX planning recipe only
   ↓
you run planning in OMX / Codex
   ↓
.omx/plans/prd-*.md + test-spec-*.md exist
   ↓
prepare "task"
   ↓
creates branch + run context
snapshots approved artifacts
stores current task/branch/run pointers
   ↓
exec / debug / verify / merge-gate
   ↓
build role-specific prompt from saved run state
   ↓
run Ralph with OpenCode or Codex
```

---

## Execution model

This runner intentionally does **not** use Ralph tasks mode.

The workflow is:

- approved OMX artifacts are the planning source of truth
- `prepare` snapshots those artifacts into the active run
- `exec`, `debug`, `verify`, and `merge-gate` generate role-specific prompts from that saved run state
- Ralph keeps looping until it sees a terminal promise tag
- OpenCode `todowrite` may appear during execution, but it is only the agent's internal scratchpad and is **not** the orchestration source of truth

### Promise contract

For this runner, a loop step is considered complete only when the final non-empty line is exactly one of these promise tags:

```text
<promise>COMPLETE</promise>
<promise>BLOCKED</promise>
````

Bare `COMPLETE` or `BLOCKED` is not enough.
If anything appears after the promise tag, Ralph may continue looping.

---

## Quick start

Inside the target work repository:

```bash
omx-ralph doctor
omx-ralph bootstrap
omx-ralph plan "Implement feature X"
```

Then run planning in OMX:

```bash
omx --high
# inside OMX / Codex
$deep-interview --quick "Implement feature X"
$ralplan --interactive "Implement feature X"
```

Do not start implementation until the approved OMX artifacts exist:

```text
.omx/plans/prd-*.md
.omx/plans/test-spec-*.md
```

Then continue:

```bash
omx-ralph prepare "Implement feature X"
omx-ralph exec
omx-ralph debug
omx-ralph verify
omx-ralph merge-gate
```

`exec`, `debug`, `verify`, and `merge-gate` do not use Ralph tasks mode; they rely on the saved run state plus terminal promise tags for loop control.

---

## Command reference

| Command          | What it actually does                                                                                                                                                                            |                      Uses `"task"`? |         Writes state? | Requires approved `.omx` artifacts? |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------: | --------------------: | ----------------------------------: |
| `doctor`         | Resolves the target repo, checks required commands, checks OMX on `PATH`, checks Ollama API reachability, and tries to confirm the configured local model tag                                    |                                  No |                    No |                                  No |
| `bootstrap`      | Ensures `.ralph/` directories exist, copies role templates if missing, writes `opencode.json` if missing, and adds ignore lines to `.git/info/exclude`                                           |                                  No |                   Yes |                                  No |
| `plan "task"`    | Prints the recommended OMX planning steps for that task                                                                                                                                          |               Yes, but display-only |                    No |                                  No |
| `prepare "task"` | Validates clean tree, finds latest approved artifacts, checks out base branch, creates or switches to a feature branch, snapshots approved artifacts, writes manifest and current state pointers |                                 Yes |                   Yes |                                 Yes |
| `current`        | Prints current repo, state dir, active run, active branch, active task, and manifest                                                                                                             |                                  No |                    No |                                  No |
| `exec`           | Builds the `executor` prompt from the saved run and launches Ralph with the local OpenCode + Ollama path                                                                                         | Indirectly, from saved current task |           Prompt only |                                 Yes |
| `debug`          | Same as `exec`, but with the `debugger` role                                                                                                                                                     |                          Indirectly |           Prompt only |                                 Yes |
| `verify`         | Same as `exec`, but with the `verifier` role                                                                                                                                                     |                          Indirectly |           Prompt only |                                 Yes |
| `merge-gate`     | Same as `exec`, but with the `merge-gate` role and usually Codex                                                                                                                                 |                          Indirectly |           Prompt only |                                 Yes |
| `status`         | Delegates to `ralph --status` in the target repo                                                                                                                                         |                                  No |                    No |                                  No |
| `hint "text"`    | Adds extra Ralph context                                                                                                                                                                         |                                  No | Ralph-managed context |                                  No |
| `clear-hint`     | Clears previously added Ralph context                                                                                                                                                            |                                  No | Ralph-managed context |                                  No |

---

## How `"task"` is used

The `"task"` argument is **not** used the same way by every command.

### `plan "task"`

`plan` does **not** run planning by itself.

It prints the recommended OMX commands and inserts the task text into those examples.

In other words, for `plan`, `"task"` is instructional text only.

### `prepare "task"`

`prepare` is where the task becomes state.

It uses `"task"` to:

1. create a slug
   example: `Implement feature X` → `implement-feature-x`
2. create or switch to a feature branch named `ralph/<slug>`
3. create a run id like `<timestamp>-<slug>`
4. store the exact original text in `.ralph/current-task`
5. record it in `.ralph/runs/<run-id>/manifest.txt`
6. inject it later into the prompts used by `exec`, `debug`, `verify`, and `merge-gate`

### Example

```text
task:
  "Implement SEQ-008 from the approved plan"

becomes:

slug:
  implement-seq-008-from-the-approved-plan

branch:
  ralph/implement-seq-008-from-the-approved-plan

run dir:
  .ralph/runs/20260421-153045-implement-seq-008-from-the-approved-plan/

saved task:
  .ralph/current-task
```

---

## What `prepare` really does

`prepare` is the command that turns planning output into an executable run.

### Preconditions

| Requirement                 | Why                                            |
| --------------------------- | ---------------------------------------------- |
| Git repository              | The runner works against a target repo         |
| Clean working tree          | Prevent accidental mixing of unrelated changes |
| Approved planning artifacts | The run snapshot must have a PRD and test spec |

### Required approved artifacts

```text
.omx/plans/prd-*.md
.omx/plans/test-spec-*.md
```

Optional, if present:

```text
.omx/specs/deep-interview-*.md
.omx/interviews/*.md
```

### Side effects

| Side effect                              | Result                                                        |
| ---------------------------------------- | ------------------------------------------------------------- |
| Checks out the base branch first         | Ensures the feature branch starts from the configured base    |
| Creates or switches `ralph/<slug>`       | One branch per slugged task name                              |
| Creates `.ralph/runs/<run-id>/approved/` | Immutable copy of approved artifacts for this run             |
| Writes `manifest.txt`                    | Records task, branch, base branch, commit, and artifact paths |
| Writes `.ralph/current-run`              | Points to the active run                                      |
| Writes `.ralph/current-branch`           | Points to the active feature branch                           |
| Writes `.ralph/current-task`             | Saves the original task text                                  |

---

## What later commands read

`exec`, `debug`, `verify`, and `merge-gate` do **not** take a task argument.

They rebuild context from the current saved state:

```text
.ralph/current-run
.ralph/current-branch
.ralph/current-task
.ralph/runs/<run-id>/approved/*
.ralph/roles/<role>.md
```

Then they generate a role-specific prompt under:

```text
.ralph/prompts/current-<role>.md
```

That prompt includes:

* the role instructions
* current task
* current branch
* base branch
* run manifest path
* approved artifact snapshot paths
* hard guardrails such as:

  * plan artifacts are immutable for this run
  * stay inside approved scope
  * use concrete evidence
  * if blocked, end with `<promise>BLOCKED</promise>` as the final non-empty line
  * if complete, end with `<promise>COMPLETE</promise>` as the final non-empty line

---

## FAQ

### Can I run `prepare "task"` without running `plan "task"`?

Yes.

`plan` only prints the recommended planning recipe.

If you already ran OMX planning another way and the required artifacts already exist:

```text
.omx/plans/prd-*.md
.omx/plans/test-spec-*.md
```

then you can go straight to:

```bash
omx-ralph prepare "Your task"
omx-ralph exec
```

### Does `prepare "task"` verify that the latest PRD and test spec really belong to that exact task?

No.

`prepare` snapshots the latest matching planning artifacts it finds.
It does **not** semantically verify that those files correspond to the task string you passed.

Keep your `.omx/plans/` directory clean and avoid leaving unrelated newer artifacts around.

### Does `bootstrap` overwrite my existing prompt files or `opencode.json`?

No.

`bootstrap` is designed to keep existing role files and `opencode.json` if they already exist.

### What does `doctor` check?

At a high level:

* target repo resolution
* required commands on `PATH`
* OMX on `PATH`
* Ollama HTTP API reachability
* whether the configured local model tag appears in Ollama tags

### Can I run against another repository?

Yes.

Use `--repo`:

```bash
omx-ralph --repo ~/work/another-repo doctor
omx-ralph --repo ~/work/another-repo prepare "Implement feature X"
```

### Can I keep state outside `.ralph/`?

Yes.

Use `--state-dir`:

```bash
omx-ralph --repo ~/work/project --state-dir ~/.cache/omx-ralph/project-state prepare "Implement feature X"
```

### Does this runner use `.ralph/ralph-tasks.md`?

No.

This workflow uses approved OMX artifacts as the planning source of truth and uses Ralph only as the execution loop.
Loop control is based on terminal promise tags, not Ralph tasks mode.

OpenCode may still use its own internal `todowrite` tool during execution, but that is not the source of orchestration truth for this runner.

---

## Notes and assumptions

| Note                                                                         | Why it matters                                                  |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `bootstrap` adds `opencode.json` and `.ralph/` to `.git/info/exclude`        | Keeps runner state out of normal Git status output              |
| `exec`, `debug`, and `verify` normally use the local OpenCode + Ollama path  | Local implementation path                                       |
| `merge-gate` is intended to be strict and usually uses Ralph's `codex` agent | Separate final approval from local implementation               |
| Branch names are derived from slugified task text                            | Similar task names can intentionally reuse the same branch      |
| Approved artifacts are snapshotted per run                                   | The run keeps its own frozen copy even if `.omx/` changes later |
| This runner does not use Ralph tasks mode                                        | Avoids conflicting task systems between OMX artifacts, Ralph tasks mode, and OpenCode `todowrite` |

---

## Troubleshooting

### `doctor` says the Ollama API is not reachable

Check the API directly:

```bash
curl http://localhost:11434/api/tags
```

If you run WSL with Ollama on Windows, make sure the Windows Ollama HTTP API is reachable from WSL.

### `prepare` fails with a dirty tree error

Either clean the working tree first:

```bash
git status
git add -A
git commit -m "save work before prepare"
```

or override intentionally:

```bash
ALLOW_DIRTY=1 omx-ralph prepare "Implement feature X"
```

### `prepare` fails because artifacts are missing

You have not completed planning yet, or the expected files are not present.

Required:

```text
.omx/plans/prd-*.md
.omx/plans/test-spec-*.md
```

### `exec` / `debug` / `verify` / `merge-gate` fail with “no active run”

You need to run:

```bash
omx-ralph prepare "Your task"
```

first.

### `Completion promise: not detected`

Ralph only detects completion when the final non-empty line is exactly a promise tag such as:

```text
<promise>COMPLETE</promise>
````

For blocking, it should end with:

```text
<promise>BLOCKED</promise>
```

Important details:

* bare `COMPLETE` or `BLOCKED` is not enough
* printing the promise tag earlier in the output is not enough
* if anything appears after the promise tag, completion may not be detected
* this runner does not use Ralph tasks mode, so OpenCode `todowrite` output does not count as completion

---

## License

Apache-2.0