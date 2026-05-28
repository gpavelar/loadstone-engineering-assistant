#!/usr/bin/env bash
# Start everything loadstone needs for local development:
#   - Rails web server (port 3000)
#   - Solid Queue worker (background jobs — required for /ideas investigations)
#   - Tailwind CSS watcher (rebuilds on .erb changes)
#
# All three run in the foreground; Ctrl-C stops them cleanly.
# Logs are interleaved with prefixes so you can tell who said what.

set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$HOME/.asdf/shims:$PATH"
export PORT="${PORT:-3000}"

# Unset shell ANTHROPIC_API_KEY so dotenv loads the value from .env.
# (If you have an old `export ANTHROPIC_API_KEY=...` in your shell rc, it
# silently shadows .env. We strip it for this process tree.)
unset ANTHROPIC_API_KEY

# Build CSS once up front — covers the case where tailwindcss:watch fails
# to start in some environments. Cheap (sub-second on this project).
bin/rails tailwindcss:build >/dev/null

pids=()
cleanup() {
  echo
  echo "==> stopping (pids: ${pids[*]:-})"
  for pid in "${pids[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  exit 0
}
trap cleanup INT TERM

prefix() {
  local label="$1"; shift
  "$@" 2>&1 | sed "s/^/[$label] /" &
  pids+=($!)
}

prefix web  bin/rails server -p "$PORT"
prefix jobs bin/jobs
prefix css  bin/rails tailwindcss:watch

echo "==> running on http://localhost:$PORT  (Ctrl-C to stop)"
wait
