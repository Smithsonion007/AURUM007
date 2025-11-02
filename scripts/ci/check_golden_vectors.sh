#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$REPO_ROOT/AURUM_full_bundle_v1_with_golden"
GOLDEN_FILE="AURUM_full_bundle_v1_with_golden/GOLDEN.json"

if [ ! -f "$WORKSPACE_DIR/Cargo.toml" ]; then
  echo "Workspace manifest not found at $WORKSPACE_DIR/Cargo.toml."
  exit 1
fi

pushd "$WORKSPACE_DIR" >/dev/null
cargo run -p aurum-pentest --bin gen_golden
popd >/dev/null

if ! git -C "$REPO_ROOT" diff --quiet -- "$GOLDEN_FILE"; then
  git -C "$REPO_ROOT" diff --stat -- "$GOLDEN_FILE"
  echo "Golden vectors are stale. Run 'cargo run -p aurum-pentest --bin gen_golden' and commit the changes." >&2
  exit 1
fi

echo "Golden vectors are up-to-date."
