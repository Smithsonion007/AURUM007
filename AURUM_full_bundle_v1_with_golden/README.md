# AURUM — Security-First Ledger Skeleton (with AEON T* scoring)

AURUM is a security-first Rust ledger skeleton designed to showcase “mathematical honesty” across hashing, validation, and AEON-style entropy scoring. It provides a minimal but auditable stack for experimenting with verifiable computation, deterministic encoding, and dual-root validation. Every component is wired for domain-separated hashing, panic safety, and predictable behavior under load.

Key capabilities include:
- Keyed, domain-separated **BLAKE3** primitives
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
# Build everything
cargo build --workspace

# Run the Rust devnet node
cargo run --package aurum-node --bin aurum-node

# (Optional) Serve the explorer locally
npx serve explorer
```

## Contributor Guide
- Run `cargo fmt`, `cargo clippy --workspace --all-targets`, and `cargo test --workspace` before opening a pull request.
- Document architectural changes in `docs/` and update relevant READMEs when adding new modules.
- Prefer domain-separated hashing helpers and panic-free APIs throughout contributions.
- Join the community touchpoints below to propose ideas, report bugs, or coordinate large changes.

## Community & Support
- [GitHub Issues](https://github.com/AURUM-Labs/aurum/issues)
- [GitHub Discussions](https://github.com/AURUM-Labs/aurum/discussions)

## Repository Topics
`rust` · `blockchain` · `cryptography` · `security` · `audit` · `ai-audit` · `entropy` · `ledger` · `open-source`

## Layout
- `aurum-pentest/` — core library (hashing, merkle, canon, aeon, validator, vrf)
- `aurum-node/` — minimal devnet node + HTTP `/status`
- `explorer/` — static single-page explorer
- `sdk-ts/` — TypeScript helper lib (hash/merkle via blake3 npm)
