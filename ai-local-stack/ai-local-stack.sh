#!/usr/bin/env bash
set -euo pipefail

# AI Local Stack Manager: Ollama + Open WebUI + MCP Jam
# Usage: ./ai-local-stack.sh {start|stop|status|restart|update|webui-logs|ollama-logs|mcpjam-logs}

# ─── Constants ────────────────────────────────────────────────────────────────
readonly SCRIPT_NAME="$(basename "${0}")"

readonly WEBUI_CONTAINER="open-webui"
readonly WEBUI_IMAGE="ghcr.io/open-webui/open-webui:main"
readonly WEBUI_VOLUME="open-webui"
readonly WEBUI_PORT=3000

readonly MCPJAM_CONTAINER="mcpjam"
readonly MCPJAM_IMAGE="mcpjam/mcp-inspector"
readonly MCPJAM_PORT=6274

readonly OLLAMA_PORT=11434
readonly OLLAMA_LOG="/tmp/ollama.log"

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} {start|stop|status|restart|update|webui-logs|ollama-logs|mcpjam-logs}

  start        Check updates + start all components (creates containers if missing)
  stop         Stop all components (0 resources used)
  status       Running state + update check
  restart      Stop + start
  update       Force update to latest images
  webui-logs   Tail Open WebUI container logs
  ollama-logs  Tail Ollama logs
  mcpjam-logs  Tail MCP Jam container logs
EOF
  exit 1
}

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Returns 0 if container is currently running, 1 otherwise
is_running() {
  podman ps --format '{{.Names}}' 2>/dev/null | grep -q "^${1}$"
}

# ─── Container lifecycle ──────────────────────────────────────────────────────

create_webui_container() {
  echo "  🔧 Creating ${WEBUI_CONTAINER}..."
  if podman create \
    -p "127.0.0.1:${WEBUI_PORT}:8080" \
    --network=pasta:-T,"${OLLAMA_PORT}" \
    --add-host=localhost:127.0.0.1 \
    --env 'OLLAMA_BASE_URL=http://host.containers.internal:11434' \
    --env 'ANONYMIZED_TELEMETRY=False' \
    -v "${WEBUI_VOLUME}":/app/backend/data \
    --label io.containers.autoupdate=registry \
    --name "${WEBUI_CONTAINER}" \
    "${WEBUI_IMAGE}"; then
    echo "  ✅ Open WebUI container created"
  else
    echo "  ❌ Failed to create Open WebUI container"
    exit 1
  fi
}

create_mcpjam_container() {
  echo "  🔧 Creating ${MCPJAM_CONTAINER}..."
  if podman create \
    -p "127.0.0.1:${MCPJAM_PORT}:${MCPJAM_PORT}" \
    --name "${MCPJAM_CONTAINER}" \
    "${MCPJAM_IMAGE}"; then
    echo "  ✅ MCP Jam container created"
  else
    echo "  ❌ Failed to create MCP Jam container"
    exit 1
  fi
}

# ─── Update logic ─────────────────────────────────────────────────────────────

# Pulls image and returns 0 if a newer version was downloaded, 1 if already current.
# Args: <image> <label>
pull_if_newer() {
  local image="$1" label="$2"
  echo "  🔍 Checking ${label}..."
  local local_digest
  local_digest=$(podman inspect "${image}" --format '{{index .RepoDigests 0}}' 2>/dev/null || echo "none")
  local timeout_cmd
  timeout_cmd=$(command -v gtimeout || command -v timeout || true)
  local pull_cmd=("podman" "pull" "--quiet" "${image}")
  [[ -n "${timeout_cmd}" ]] && pull_cmd=("${timeout_cmd}" "30" "${pull_cmd[@]}")
  if ! "${pull_cmd[@]}" >/dev/null 2>&1; then
    echo "     ⚠️  Could not reach registry (offline?), skipping update check"
    return 1
  fi
  local new_digest
  new_digest=$(podman inspect "${image}" --format '{{index .RepoDigests 0}}' 2>/dev/null || echo "unknown")
  if [[ "${local_digest}" != "${new_digest}" ]]; then
    echo "     ⚠️  Newer image available"
    return 0
  fi
  echo "     ✅ Up to date"
  return 1
}

# Pulls both images; returns 0 if at least one has an update available.
check_updates() {
  echo "🔍 Checking for updates..."
  local webui_new=1 mcpjam_new=1
  pull_if_newer "${WEBUI_IMAGE}"  "Open WebUI" && webui_new=0 || true
  pull_if_newer "${MCPJAM_IMAGE}" "MCP Jam"    && mcpjam_new=0 || true
  [[ ${webui_new} -eq 0 || ${mcpjam_new} -eq 0 ]]
}

# Tears down, re-pulls, and recreates a single container.
# Args: <container> <image> <label> <create_fn>
update_one() {
  local container="$1" image="$2" label="$3" create_fn="$4"
  echo "  🔄 Updating ${label}..."
  podman stop "${container}" 2>/dev/null && echo "     ✅ Stopped" || echo "     ⚠️  Was not running"
  podman rm   "${container}" 2>/dev/null && echo "     ✅ Removed" || echo "     ⚠️  Already removed"
  if ! podman pull "${image}"; then
    echo "     ❌ Failed to pull ${label} image"
    return 1
  fi
  echo "     ✅ Latest image pulled"
  "${create_fn}"
}

update_stack() {
  update_one "${WEBUI_CONTAINER}"  "${WEBUI_IMAGE}"  "Open WebUI" create_webui_container  || exit 1
  update_one "${MCPJAM_CONTAINER}" "${MCPJAM_IMAGE}" "MCP Jam"    create_mcpjam_container || exit 1
  echo "✅ Update complete"
}

# ─── Stack operations ─────────────────────────────────────────────────────────

start_stack() {
  echo "🚀 Starting AI Local Stack..."

  # ── Ensure containers exist ────────────────────────────────────────────────
  if ! podman container exists "${WEBUI_CONTAINER}" 2>/dev/null; then
    echo "  ℹ️  Open WebUI container not found, creating..."
    create_webui_container
  else
    echo "  ✅ Open WebUI container exists"
  fi

  if ! podman container exists "${MCPJAM_CONTAINER}" 2>/dev/null; then
    echo "  ℹ️  MCP Jam container not found, creating..."
    create_mcpjam_container
  else
    echo "  ✅ MCP Jam container exists"
  fi

  # ── Offer to update if newer images found ─────────────────────────────────
  if check_updates; then
    echo ""
    echo "  📦 Newer images available for one or more components"
    echo "  💾 Data:     Settings/chats preserved (volumes untouched)"
    echo "  ⏱️  Downtime: ~30s"
    read -p "  Update now? [y/N]: " -n 1 -r
    echo
    if [[ ${REPLY} =~ ^[Yy]$ ]]; then
      update_stack
    else
      echo "  ⏭️  Skipping update, using current images"
    fi
  fi

  # ── Ollama ─────────────────────────────────────────────────────────────────
  if ! pgrep -x "ollama" >/dev/null 2>&1; then
    echo "  🦙 Starting Ollama (logs: ${OLLAMA_LOG})..."
    ollama serve >>"${OLLAMA_LOG}" 2>&1 &
    local attempts=0
    while ! curl -sf "http://127.0.0.1:${OLLAMA_PORT}/api/tags" >/dev/null; do
      sleep 1
      (( attempts++ )) || true
      if (( attempts >= 10 )); then
        echo "  ❌ Ollama failed to start within 10s (check ${OLLAMA_LOG})"
        pkill -x ollama 2>/dev/null || true
        exit 1
      fi
    done
    echo "  ✅ Ollama started"
  else
    echo "  ✅ Ollama already running"
  fi

  # ── Open WebUI ─────────────────────────────────────────────────────────────
  if ! is_running "${WEBUI_CONTAINER}"; then
    echo "  🐳 Starting Open WebUI..."
    if podman start "${WEBUI_CONTAINER}"; then
      sleep 2
      echo "  ✅ Open WebUI started"
    else
      echo "  ❌ Failed to start Open WebUI"
      exit 1
    fi
  else
    echo "  ✅ Open WebUI already running"
  fi

  # ── MCP Jam ────────────────────────────────────────────────────────────────
  if ! is_running "${MCPJAM_CONTAINER}"; then
    echo "  🔌 Starting MCP Jam..."
    if podman start "${MCPJAM_CONTAINER}"; then
      sleep 1
      echo "  ✅ MCP Jam started"
    else
      echo "  ❌ Failed to start MCP Jam"
      exit 1
    fi
  else
    echo "  ✅ MCP Jam already running"
  fi

  echo ""
  echo "✅ Stack ready!"
  echo "   🌐 Open WebUI:  http://localhost:${WEBUI_PORT}"
  echo "   🔌 MCP Jam:     http://localhost:${MCPJAM_PORT}"
  echo "   🦙 Models:      ollama list"
  echo "   📋 Ollama logs: tail -f ${OLLAMA_LOG}"
  echo "   🛑 Stop:        ${SCRIPT_NAME} stop"
}

stop_stack() {
  echo "🛑 Stopping AI Local Stack..."

  if is_running "${WEBUI_CONTAINER}"; then
    echo "  🐳 Stopping Open WebUI..."
    podman stop "${WEBUI_CONTAINER}" 2>/dev/null \
      && echo "  ✅ Open WebUI stopped" \
      || echo "  ❌ Failed to stop Open WebUI"
  else
    echo "  ⚠️  Open WebUI not running"
  fi

  if is_running "${MCPJAM_CONTAINER}"; then
    echo "  🔌 Stopping MCP Jam..."
    podman stop "${MCPJAM_CONTAINER}" 2>/dev/null \
      && echo "  ✅ MCP Jam stopped" \
      || echo "  ❌ Failed to stop MCP Jam"
  else
    echo "  ⚠️  MCP Jam not running"
  fi

  if pgrep -x "ollama" >/dev/null 2>&1; then
    echo "  🦙 Stopping Ollama..."
    pkill -x ollama 2>/dev/null \
      && echo "  ✅ Ollama stopped" \
      || echo "  ❌ Failed to stop Ollama"
  else
    echo "  ⚠️  Ollama not running"
  fi

  echo ""
  echo "✅ Stack stopped (0 CPU/RAM usage)"
}

show_status() {
  echo "📊 AI Local Stack Status:"
  echo ""

  if pgrep -x "ollama" >/dev/null 2>&1; then
    echo "  🦙 Ollama:     ✅ RUNNING"
  else
    echo "  🦙 Ollama:     🔴 STOPPED"
  fi

  if is_running "${WEBUI_CONTAINER}"; then
    echo "  🐳 Open WebUI: ✅ RUNNING  → http://localhost:${WEBUI_PORT}"
  elif podman container exists "${WEBUI_CONTAINER}" 2>/dev/null; then
    echo "  🐳 Open WebUI: 🔴 STOPPED  (run '${SCRIPT_NAME} start')"
  else
    echo "  🐳 Open WebUI: ❌ NOT CREATED (run '${SCRIPT_NAME} start')"
  fi

  if is_running "${MCPJAM_CONTAINER}"; then
    echo "  🔌 MCP Jam:    ✅ RUNNING  → http://localhost:${MCPJAM_PORT}"
  elif podman container exists "${MCPJAM_CONTAINER}" 2>/dev/null; then
    echo "  🔌 MCP Jam:    🔴 STOPPED  (run '${SCRIPT_NAME} start')"
  else
    echo "  🔌 MCP Jam:    ❌ NOT CREATED (run '${SCRIPT_NAME} start')"
  fi

  echo ""
  check_updates || true
}

# ─── Entrypoint ───────────────────────────────────────────────────────────────

[[ $# -gt 0 ]] || usage

case "$1" in
  start)        start_stack ;;
  stop)         stop_stack ;;
  status)       show_status ;;
  restart)      stop_stack; sleep 2; start_stack ;;
  update)
    if podman container exists "${WEBUI_CONTAINER}" 2>/dev/null \
    || podman container exists "${MCPJAM_CONTAINER}" 2>/dev/null; then
      update_stack
    else
      echo "❌ No containers found. Run '${SCRIPT_NAME} start' first."
    fi
    ;;
  webui-logs)
    podman container exists "${WEBUI_CONTAINER}" 2>/dev/null \
      && podman logs -f "${WEBUI_CONTAINER}" \
      || echo "❌ No Open WebUI container found."
    ;;
  ollama-logs)
    [[ -f "${OLLAMA_LOG}" ]] \
      && tail -f "${OLLAMA_LOG}" \
      || echo "❌ No Ollama log found at ${OLLAMA_LOG} (has Ollama been started?)"
    ;;
  mcpjam-logs)
    podman container exists "${MCPJAM_CONTAINER}" 2>/dev/null \
      && podman logs -f "${MCPJAM_CONTAINER}" \
      || echo "❌ No MCP Jam container found."
    ;;
  *)            usage ;;
esac
