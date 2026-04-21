# omx-ralph-local

A standalone runner for a hybrid workflow:

- planning in **oh-my-codex (OMX)** with **Codex gpt-5.4**
- implementation in **Ralph** with **OpenCode** backed by a local **Ollama** coding model
- a final strict **merge gate** back on **Codex gpt-5.4**

The runner lives in its own repository and is callable from any target work repository.

It keeps run state inside the target repository, not inside this runner repository.

## Design

- install once, reuse across projects
- run from the current work directory or pass `--repo /path/to/repo`
- keep state under `<target-repo>/.ralph/` by default
- keep approved planning artifacts under `<target-repo>/.omx/`
- do not let the local implementation model rewrite the approved plan
- avoid rotation in the initial version

## Layout

```text
bin/omx-ralph
templates/roles/executor.md
templates/roles/debugger.md
templates/roles/verifier.md
templates/roles/merge-gate.md
examples/config.example.sh
````

## Install

Clone this repository and put `bin/omx-ralph` on your `PATH` (environment variable).

Example:

```bash
git clone https://github.com/carabinshely/omx-ralph-local.git
cd omx-ralph-local
chmod +x bin/omx-ralph
mkdir -p ~/.local/bin
ln -sf "$(pwd)/bin/omx-ralph" ~/.local/bin/omx-ralph
```

Then make sure `~/.local/bin` is on your `PATH`.

## Optional machine config

Create:

```text
~/.config/omx-ralph/config
```

Start from:

```bash
mkdir -p ~/.config/omx-ralph
cp examples/config.example.sh ~/.config/omx-ralph/config
```

Adjust values as needed.

For **WSL (Windows Subsystem for Linux)** with Ollama on Windows, the important part is that the Ollama HTTP API must be reachable from WSL. This runner checks the API, not the local `ollama` binary.

## Workflow

Inside the target work repository:

```bash
omx-ralph doctor
omx-ralph bootstrap
omx-ralph plan "Implement feature X"
```

Run planning in OMX:

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

Or target another repository explicitly:

```bash
omx-ralph --repo ~/work/social-knowledge-vault prepare "Implement feature X"
```

## Commands

```text
doctor
bootstrap
plan "task"
prepare "task"
current
exec
debug
verify
merge-gate
status
hint "text"
clear-hint
```

## Notes

* `bootstrap` writes `<repo>/opencode.json` if it does not exist.
* `bootstrap` adds `opencode.json` and `.ralph/` to `.git/info/exclude`.
* `prepare` snapshots the approved OMX planning artifacts into `<repo>/.ralph/runs/<run-id>/approved/`.
* `exec`, `debug`, and `verify` use the local OpenCode + Ollama path.
* `merge-gate` is intended to be strict and usually runs on Ralph's `codex` agent.
* if your Ollama model tag differs, change `LOCAL_MODEL` in your config.
