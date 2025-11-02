# AURUM — Security-First Ledger Skeleton (with AEON T* scoring)

AURUM is a **safe-by-design ledger skeleton** in Rust:
- Keyed, domain-separated **BLAKE3**
- Canonical Tx/Block bytes (fixed order; Unicode confusables rejected)
- **Merkle** roots with odd-leaf duplication + frozen empty root
- **VRF** input hashing (length-tagged)
- **AEON** T* score (entropy + compressibility)
- **Dual-root** validator (Poseidon/private vs BLAKE3/public)
- Minimal **devnet node** with HTTP `/status`
- Static **explorer** page hitting `/status`
- CI: build, clippy, tests, miri; scheduled fuzz & coverage

> Maintainer / Attribution: **NS**

## Quick Start
```bash
# build
cargo build --workspace
# run node
cd aurum-node && cargo run
# open explorer by serving ./explorer directory (or add to node static serving)
```

## Layout
- `aurum-pentest/` — core library (hashing, merkle, canon, aeon, validator, vrf)
- `aurum-node/` — minimal devnet node + HTTP `/status`
- `explorer/` — static single-page explorer
- `sdk-ts/` — TypeScript helper lib (hash/merkle via blake3 npm)
