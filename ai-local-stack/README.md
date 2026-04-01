# ai-local-stack

Manages a local AI development stack: **Ollama** (LLM runtime) + **Open WebUI** (chat UI) + **MCP Jam** (MCP inspector). Uses `podman` for containers, runs Ollama natively.

On first `start`, containers are created automatically. Subsequent starts are fast — containers already exist, only services are launched.

## Usage

```bash
./ai-local-stack.sh <command>
```

## Commands

| Command | Description |
|---------|-------------|
| `start` | Check for updates, create containers if needed, start all services |
| `stop` | Stop all services (frees all CPU/RAM) |
| `status` | Show running state + check for image updates |
| `restart` | Stop then start |
| `update` | Force-pull latest images and recreate containers |
| `webui-logs` | Tail Open WebUI container logs |
| `ollama-logs` | Tail Ollama process logs |
| `mcpjam-logs` | Tail MCP Jam container logs |

## Examples

```bash
# First run — creates containers, starts everything
./ai-local-stack.sh start

# Check what's running
./ai-local-stack.sh status

# Shut everything down (zero resource usage)
./ai-local-stack.sh stop

# Debug Open WebUI
./ai-local-stack.sh webui-logs
```

## Services & Ports

| Service | URL | Notes |
|---------|-----|-------|
| Open WebUI | http://localhost:3000 | Chat UI for Ollama models |
| MCP Jam | http://localhost:6274 | MCP protocol inspector |
| Ollama | http://localhost:11434 | LLM runtime (native process) |

## Dependencies

- `podman` — container runtime (replaces Docker)
- `ollama` — local LLM runtime, must be installed and on `$PATH`
- `curl` — used for Ollama health check on startup

## Ports in use

All services bind to `127.0.0.1` only (not exposed on the network):

- `3000` — Open WebUI
- `6274` — MCP Jam
- `11434` — Ollama

## Notes

- Ollama logs go to `/tmp/ollama.log`
- Open WebUI data persists in the `open-webui` podman volume (survives updates)
- On `start`, if newer images are available, you'll be prompted to update (~30s downtime)
- Open WebUI connects to Ollama via `host.containers.internal` using pasta networking
