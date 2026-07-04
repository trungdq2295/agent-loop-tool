#!/usr/bin/env bash
# verify.sh — this project's definition of "correct". Exit 0 = pass.
# Runs OUTSIDE the agent, after every iteration. The agent cannot skip it.
set -euo pipefail
cd "$(dirname "$0")/.."

# Replace with this project's real checks (cheapest first, fail fast):
npm run typecheck
npm run lint
npm test
