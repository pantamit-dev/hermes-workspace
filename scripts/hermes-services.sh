#!/usr/bin/env bash
# ==============================================================================
# Hermes Unified Service Controller
# Manages:
#   1. Hermes Gateway   (:8642)
#   2. Hermes Dashboard (:9119)
#   3. Hermes Workspace (:3002)
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

WORKSPACE_PORT="${PORT:-3002}"
DASHBOARD_PORT=9119
GATEWAY_PORT=8642

start_services() {
  echo "🚀 [1/3] Starting Hermes Gateway (:8642)..."
  hermes gateway start 2>/dev/null || hermes gateway restart

  echo "🚀 [2/3] Starting Hermes Dashboard (:9119)..."
  if ! curl -fsS "http://127.0.0.1:$DASHBOARD_PORT" >/dev/null 2>&1; then
    nohup hermes dashboard --port "$DASHBOARD_PORT" --host 127.0.0.1 --no-open >/dev/null 2>&1 &
    sleep 2
  else
    echo "  Hermes Dashboard already listening on :$DASHBOARD_PORT."
  fi

  echo "🚀 [3/3] Starting Hermes Workspace (:$WORKSPACE_PORT)..."
  PORT="$WORKSPACE_PORT" "$ROOT/scripts/start-stable.sh"

  echo ""
  echo "✨ All Hermes services are running!"
  echo "  • Workspace UI : http://127.0.0.1:$WORKSPACE_PORT"
  echo "  • Dashboard    : http://127.0.0.1:$DASHBOARD_PORT"
  echo "  • Gateway API  : http://127.0.0.1:$GATEWAY_PORT"
}

stop_services() {
  echo "🛑 Stopping Hermes Workspace..."
  PORT="$WORKSPACE_PORT" "$ROOT/scripts/stop-stable.sh" 2>/dev/null || true

  echo "🛑 Stopping Hermes Dashboard..."
  hermes dashboard --stop 2>/dev/null || true

  echo "🛑 Stopping Hermes Gateway..."
  hermes gateway stop 2>/dev/null || true

  echo "All Hermes services stopped."
}

status_services() {
  echo "════════════════════════════════════════════════════════════════"
  echo "                  Hermes Services Status                        "
  echo "════════════════════════════════════════════════════════════════"

  # 1. Gateway
  echo -n "• Hermes Gateway (:8642)   : "
  if curl -fsS "http://127.0.0.1:$GATEWAY_PORT/health" >/dev/null 2>&1; then
    echo "✅ UP (HTTP API Healthy)"
  else
    echo "❌ DOWN"
  fi

  # 2. Dashboard
  echo -n "• Hermes Dashboard (:9119) : "
  if curl -fsS "http://127.0.0.1:$DASHBOARD_PORT" >/dev/null 2>&1; then
    echo "✅ UP (Dashboard Active)"
  else
    echo "❌ DOWN"
  fi

  # 3. Workspace
  echo -n "• Hermes Workspace (:$WORKSPACE_PORT) : "
  if curl -fsS "http://127.0.0.1:$WORKSPACE_PORT/chat/new" >/dev/null 2>&1; then
    echo "✅ UP (UI Online)"
  else
    echo "❌ DOWN"
  fi

  echo ""
  echo "Connection probe from Workspace:"
  curl -s "http://127.0.0.1:$WORKSPACE_PORT/api/connection-status" 2>/dev/null | grep -o '"status":"[^"]*"' || echo "No response"
  echo "════════════════════════════════════════════════════════════════"
}

case "${1:-status}" in
  start)
    start_services
    ;;
  stop)
    stop_services
    ;;
  restart)
    stop_services
    sleep 1
    start_services
    ;;
  status)
    status_services
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
