#!/usr/bin/env bash
# Bring loadstone up to date after a fresh clone, reboot, or branch switch.
# Installs gems, runs pending migrations on dev + test, builds CSS once.
# Does NOT pull from git or run tests (use script/test.sh for that).

set -euo pipefail
cd "$(dirname "$0")/.."

# Use asdf-managed Ruby (system Ruby on macOS is too old for the Gemfile).
export PATH="$HOME/.asdf/shims:$PATH"

echo "==> bundle install"
bundle install

echo "==> db:prepare (development)"
bin/rails db:prepare

echo "==> db:prepare (test)"
RAILS_ENV=test bin/rails db:prepare

echo "==> tailwindcss:build"
bin/rails tailwindcss:build

echo
echo "Up to date. Run script/dev.sh to start the app or script/test.sh to run tests."
