#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$REPO_ROOT/AURUM_full_bundle_v1_with_golden"

if [ ! -f "$WORKSPACE_DIR/Cargo.toml" ]; then
  echo "Workspace manifest not found at $WORKSPACE_DIR/Cargo.toml."
  exit 0
fi

cd "$WORKSPACE_DIR"

FUZZ_MANIFESTS=()
while IFS= read -r manifest; do
  FUZZ_MANIFESTS+=("$manifest")
done < <(find . -path './target' -prune -o -path '*/fuzz/Cargo.toml' -print)

if [ "${#FUZZ_MANIFESTS[@]}" -eq 0 ]; then
  echo "No cargo-fuzz manifests found; skipping fuzzing step."
  exit 0
fi

TOOLCHAIN="${RUST_FUZZ_TOOLCHAIN:-nightly}"
CARGO_CMD=(cargo "+${TOOLCHAIN}")

if ! command -v cargo &>/dev/null; then
  echo "cargo command not available in PATH."
  exit 1
fi

if [ "${FUZZ_MODE:-smoke}" = "nightly" ]; then
  MAX_TIME="${FUZZ_MAX_TOTAL_TIME:-7200}"
  FUZZ_ARGS=(-- "-max_total_time=${MAX_TIME}")
  MODE_DESC="nightly long-run"
else
  RUNS="${FUZZ_RUNS:-2000}"
  FUZZ_ARGS=(-- "-runs=${RUNS}")
  MODE_DESC="smoke"
fi

echo "Detected ${#FUZZ_MANIFESTS[@]} fuzz package(s); running in ${MODE_DESC} mode using toolchain '${TOOLCHAIN}'."

for manifest in "${FUZZ_MANIFESTS[@]}"; do
  crate_dir="$(dirname "$manifest")"
  pushd "$crate_dir" >/dev/null

  TARGETS=()
  while IFS= read -r raw_target; do
    raw_target="$(echo "$raw_target" | tr -d '\r')"
    raw_target="$(echo "$raw_target" | xargs)"
    [ -z "$raw_target" ] && continue
    TARGETS+=("$raw_target")
  done < <("${CARGO_CMD[@]}" fuzz list)

  if [ "${#TARGETS[@]}" -eq 0 ]; then
    echo "No fuzz targets defined in $crate_dir; skipping."
    popd >/dev/null
    continue
  fi

  for target in "${TARGETS[@]}"; do
    echo "Running fuzz target '$target' in $crate_dir"
    "${CARGO_CMD[@]}" fuzz run "$target" "${FUZZ_ARGS[@]}"
  done

  popd >/dev/null

done
