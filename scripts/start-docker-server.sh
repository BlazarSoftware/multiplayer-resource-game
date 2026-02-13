#!/usr/bin/env bash
set -euo pipefail

# Always run from project root (where docker-compose.yml lives)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Error: docker daemon is not running." >&2
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "Error: docker compose is not available." >&2
  exit 1
fi

echo "Rebuilding and starting game server container..."
"${COMPOSE_CMD[@]}" up --build -d

echo
"${COMPOSE_CMD[@]}" ps
echo
echo "Game server is up on udp://127.0.0.1:7777"
