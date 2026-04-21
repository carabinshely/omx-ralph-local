# shellcheck shell=bash

: "${LOCAL_MODEL:=ollama/qwen3-coder:30b}"
: "${OLLAMA_BASE_URL:=http://localhost:11434}"

: "${CODEX_MODEL:=gpt-5.4}"
: "${MERGE_GATE_AGENT:=codex}"
: "${MERGE_GATE_MODEL:=gpt-5.4}"

: "${BASE_BRANCH:=main}"

: "${RALPH_BIN:=ralph}"
: "${OPENCODE_BIN:=opencode}"
: "${OMX_BIN:=omx}"

: "${ALLOW_DIRTY:=0}"

: "${MAX_ITERS_EXEC:=12}"
: "${MAX_ITERS_DEBUG:=6}"
: "${MAX_ITERS_VERIFY:=3}"
: "${MAX_ITERS_MERGE_GATE:=2}"

: "${OLLAMA_HEALTH_RETRIES:=4}"
: "${OLLAMA_HEALTH_RETRY_DELAY:=2}"
: "${OLLAMA_REQUIRE_MODEL:=1}"