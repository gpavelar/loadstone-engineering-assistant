#!/usr/bin/env bash
# Run the loadstone test suite.
# Forwards extra args to `rails test` so you can run a single file or test:
#   script/test.sh test/services/skill_router_test.rb
#   script/test.sh test/models/idea_test.rb -n test_archived_scope_includes_only_archived

set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$HOME/.asdf/shims:$PATH"

# Unset shell-level ANTHROPIC_API_KEY so dotenv can populate it from .env.
# Tests never call the real API, but some adapters validate the key shape on boot.
unset ANTHROPIC_API_KEY

exec bin/rails test "$@"
