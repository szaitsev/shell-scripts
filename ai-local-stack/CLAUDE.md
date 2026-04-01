# CLAUDE.md — ai-local-stack

## Purpose
Manages a local AI development stack: Ollama (native process) + Open WebUI + MCP Jam (both podman containers).
Handles full lifecycle: container creation, startup, health checking, image updates, and log tailing.

## Key dependencies
- `podman` — container runtime (not Docker; commands differ subtly)
- `ollama` — must be installed natively, launched as a background process via `ollama serve`
- `curl` — health check for Ollama readiness on port 11434
- pasta networking — used to bridge Open WebUI container to Ollama on the host

## Constants (all `readonly` at top of file)
All port numbers, container names, image refs, and the Ollama log path are defined once
as `readonly` constants. Never inline these values anywhere else in the script.

| Constant | Value |
|----------|-------|
| `WEBUI_PORT` | 3000 |
| `MCPJAM_PORT` | 6274 |
| `OLLAMA_PORT` | 11434 |
| `OLLAMA_LOG` | /tmp/ollama.log |

## Design decisions
- `podman` is used instead of Docker — don't swap to `docker` commands without testing
- Startup order matters: Ollama must pass health check before WebUI/MCP Jam start
- `pull_if_newer` returns 0 on update available, 1 if current — intentional, used as boolean
- `check_updates` is called with `|| true` in `show_status` to prevent `set -e` from exiting
- `(( attempts++ )) || true` prevents `set -e` from exiting when counter increments from 0
- Open WebUI data lives in a named volume (`open-webui`) — never remove it during updates
- All services bind to `127.0.0.1` only — do not change to `0.0.0.0`

## Things to preserve
- `set -euo pipefail` at the top — any workarounds for intentional non-zero exits use `|| true`
- The `[[ $# -gt 0 ]] || usage` guard before `case` — required by `set -u` when no args given
- `readonly` on all top-level constants — do not make them mutable
- `is_running()` uses `podman ps`, not `podman container exists` — these are intentionally different
- Container creation happens in dedicated functions (`create_webui_container`, etc.) — keep separate from start logic

## Testing this script
```bash
bash -n ai-local-stack.sh          # syntax check (no execution)
./ai-local-stack.sh                # should print usage and exit 1
./ai-local-stack.sh status         # safe read-only check
./ai-local-stack.sh start          # full integration test (requires podman + ollama)
```
