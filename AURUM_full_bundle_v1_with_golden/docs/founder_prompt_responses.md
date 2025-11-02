# Founder Prompt Responses for AURUM

This document captures actionable outputs for the eleven founder-level prompts. Each section can be copied directly into Codex-style workflows, GitHub discussions, or planning docs.

---

## 1. Security & Code Review

**Prompt:** “You are a senior Rust security engineer. Review this repository for cryptographic misuse, unsafe operations, or logic flaws. For each finding, provide the file name, code snippet, severity level, and a suggested patch.”

### Findings

| File | Snippet | Issue | Severity | Suggested Patch |
| --- | --- | --- | --- | --- |
| `aurum-pentest/src/aeon.rs` | `let gz = enc.finish().unwrap_or_default();` | Compression errors are swallowed and treated as "perfect" compressibility, inflating T* scores and hiding encoder faults. | Medium | Propagate the error or fall back to a neutral ratio. | 
| `aurum-node/src/main.rs` | `let root = merkle_root(...).unwrap();` | A bad mempool entry (e.g., oversize leaf) turns into a panic and DoS. | Medium | Handle the `Result` and surface HTTP 500 or redaction. |
| `aurum-pentest/src/validator.rs` | `if block.poseidon_root == block.blake3_root {` | Timing of `==` on `[u8; 32]` is not guaranteed constant; side channels may leak bit positions. | Low | Use `subtle`'s `ConstantTimeEq` or BLAKE3 equality. |

### Patch Sketches

```rust
// aurum-pentest/src/aeon.rs
pub fn calculate_t_star(data: &[u8]) -> Result<f64, std::io::Error> {
    let h_norm = calculate_h_norm(data);
    if data.is_empty() { return Ok(0.0); }
    let mut enc = GzEncoder::new(Vec::new(), Compression::default());
    enc.write_all(data)?;
    let gz = enc.finish()?;
    let comp_ratio = 1.0 - (gz.len() as f64 / data.len() as f64);
    Ok(((h_norm + comp_ratio) / 2.0).clamp(0.0, 1.0))
}
```

```rust
// aurum-node/src/main.rs
let root = match merkle_root(&mempool.iter().map(|m| m.as_slice()).collect::<Vec<_>>()) {
    Ok(r) => r,
    Err(e) => {
        eprintln!("merkle_root error: {e}");
        let resp = Response::from_string("{\"error\":\"internal\"}")
            .with_status_code(500)
            .with_header("Content-Type: application/json".parse::<Header>().unwrap());
        let _ = request.respond(resp);
        continue;
    }
};
```

```rust
// aurum-pentest/src/validator.rs
use subtle::ConstantTimeEq;
if block.poseidon_root.ct_eq(&block.blake3_root).into() {
    Ok(())
} else {
    Err("Dual-Root Mismatch")
}
```

---

## 2. Optimization & Performance

**Prompt:** “Optimize AURUM’s hashing and Merkle tree modules for performance under high transaction load. Maintain full domain separation and panic safety. Suggest benchmarks to validate the optimization.”

1. **Hashing Layer**
   - Cache domain separation keys once via `once_cell::sync::Lazy<HashMap<_, _>>`, so every `blake3_ds` call skips recomputing `hash(dst)`.
   - Expose `blake3_ds_multi` to stream multiple byte slices into one keyed hasher without concatenation buffers.
   - Keep the public API panic-free by returning `DsError::InvalidDst` whenever an unknown tag is requested.

2. **Merkle Tree**
   - Perform in-place level reduction: reuse the original leaf buffer, overwriting it with parent hashes and tracking the active length.
   - Reuse the cached keyed hasher through `blake3_ds_multi`, which feeds the left/right child slices directly and avoids a 64-byte scratch copy per parent.
   - Preserve the frozen empty root logic for the zero-leaf case.

3. **Benchmarks**
   - Add a `criterion` group with:
     - `bench_merkle_root_in_place` benchmarking 1k and 1m leaves against the previous allocate-heavy version.
     - `bench_blake3_ds_multi` stressing 1k transaction fragments hashed via the streaming helper.
     - `bench_vrf_input_hash` exercising the keyed cache with varying payload sizes (32–512 bytes).
   - Capture `cargo flamegraph --bench merkle` to visualize the reduced time spent in `Hasher::update` and memory copies.

---

## 3. Developer Onboarding Guide

**Prompt:** “Generate a clean, concise developer onboarding guide for AURUM. Include a 5-minute setup, architecture overview, and contribution steps. Make it Markdown-ready for the repository wiki.”

### AURUM Onboarding (5-Minute Quickstart)

1. **Clone & Toolchain**
   ```bash
   git clone https://github.com/AURUM-Labs/aurum.git
   cd aurum
   rustup override set stable
   cargo install just cargo-nextest
   ```
2. **Build Everything**
   ```bash
   cargo build --workspace
   ```
3. **Run the Devnet Node**
   ```bash
   cd aurum-node
   cargo run
   # -> AURUM node on http://localhost:8080 (GET /status)
   ```
4. **Open the Explorer**
   ```bash
   cd ../explorer
   npm install
   npm run dev
   ```

### Architecture Overview

- `aurum-pentest/`: cryptography, Merkle, AEON, validator, VRF helpers.
- `aurum-node/`: minimal HTTP node exposing `/status`.
- `explorer/`: static SPA hitting node status.
- `sdk-ts/`: TypeScript helper bindings for hashing and Merkle proofs.
- `GOLDEN.json`: canonical vectors for regression.

### Contribution Steps

1. Create an issue or join the `#dev` Discord channel for task triage.
2. Fork, branch (`git checkout -b feature/<slug>`), ensure `cargo fmt`, `cargo clippy`, `cargo test` pass.
3. Update or add golden vectors when touching hashing or canon logic (`cargo run -p aurum-pentest --bin regen_golden`).
4. Submit PR with:
   - Summary
   - Testing checklist
   - Security notes (impact, mitigations)
   - Reviewer suggestions
5. Core maintainers run fuzz + coverage nightly; expect follow-up issues for high-risk code.

---

## 4. AEON Module Expansion

**Prompt:** “Expand AEON’s T* metric into a multi-feature information fingerprint. Explore entropy variants (e.g., Rényi entropy, mutual information) and practical, computable compressibility proxies. Propose formulas and Rust functions that preserve AEON’s simplicity.”

### Proposed Metrics

1. **Rényi Entropy (order 2)**
   - Formula: \( H_2 = -\log_2 \sum_i p_i^2 \). Normalize by `log2(sigma)`.
   - Rust API: `fn renyi_entropy_norm(data: &[u8]) -> f64`.

2. **Local Mutual Information Proxy**
   - Treat byte pairs `(x_i, x_{i+1})` as joint distribution.
   - Compute `I1 = H(X) + H(Y) - H(X,Y)` where `X` is even indices, `Y` odd.
   - Normalize by `min(H(X), H(Y))` to keep [0,1].

3. **Compressibility Proxy**
   - Use `lz4_flex::compress_prepend_size` length ratio as low-latency stand-in for gzip.
   - Optionally compute rolling window variance to detect structure.

4. **Aggregate Fingerprint**
   - `T_fingerprint = (w1 * T_star + w2 * H2 + w3 * I1 + w4 * C_lz4) / (w1 + w2 + w3 + w4)`.
   - Default weights: `[0.4, 0.2, 0.2, 0.2]`.

### Rust Sketch

```rust
pub struct AeonFingerprint {
    pub t_star: f64,
    pub renyi2: f64,
    pub mutual_pair: f64,
    pub lz4_compressibility: f64,
}

pub fn compute_fingerprint(data: &[u8]) -> Result<AeonFingerprint, AeonError> {
    Ok(AeonFingerprint {
        t_star: calculate_t_star(data)?,
        renyi2: renyi_entropy_norm(data),
        mutual_pair: mutual_information_pairs(data),
        lz4_compressibility: lz4_proxy(data)?,
    })
}

pub fn aggregate_score(fp: &AeonFingerprint, weights: [f64; 4]) -> f64 {
    let sum_w: f64 = weights.iter().sum();
    if sum_w == 0.0 { return 0.0; }
    (fp.t_star * weights[0]
        + fp.renyi2 * weights[1]
        + fp.mutual_pair * weights[2]
        + fp.lz4_compressibility * weights[3]) / sum_w
}
```

---

## 5. CI/CD & Fuzzing Expansion

**Prompt:** “Design a GitHub Actions matrix for continuous fuzz testing and coverage reports across Linux, macOS, and Windows. Include steps for nightly long-run fuzzers and golden vector regeneration validation.”

```yaml
name: security-ci

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 3 * * *'  # nightly

jobs:
  fuzz-and-coverage:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        rust: [stable]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          toolchain: ${{ matrix.rust }}
      - name: Install deps
        run: |
          cargo install cargo-fuzz || true
          cargo install grcov || true
      - name: Fuzz (short)
        run: |
          cargo fuzz run merkle -- -runs=5000
          cargo fuzz run canon -- -runs=5000
      - name: Coverage
        run: |
          RUSTFLAGS="-Zinstrument-coverage" LLVM_PROFILE_FILE="aurum-%p-%m.profraw" \
            cargo +nightly test
          grcov . --binary-path ./target/debug/ -s . -t lcov --branch --ignore-not-existing \
            -o lcov.info
      - uses: codecov/codecov-action@v4
        with:
          files: lcov.info

  nightly-longrun:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@nightly
      - run: cargo install cargo-fuzz || true
      - name: Long fuzzers
        run: |
          cargo fuzz run merkle -- -max_total_time=7200
          cargo fuzz run canon -- -max_total_time=7200
      - name: Golden vector diff
        run: |
          cargo run -p aurum-pentest --bin regen_golden
          git diff --exit-code GOLDEN.json
```

---

## 6. Community Building & Collaboration

**Prompt:** “Draft a pinned GitHub Discussion introducing AURUM’s mission, values, and contribution roadmap. Include how contributors can propose modules (e.g., consensus, ZK integrations) and how maintainers evaluate PRs.”

**Title:** Welcome to AURUM — Security-First Ledger Collaboration Hub

**Body:**

> **Mission.** AURUM builds mathematically honest distributed systems. We prototype secure primitives (dual roots, AEON scoring, canonical serialization) that upstream projects can adopt.
>
> **Values.**
> - *Security first.* Safety proofs beat feature checklists.
> - *Transparency.* All design docs, fuzz cases, and audits are public.
> - *Interoperability.* Domain-separated hashing and typed Merkle proofs are protocol-agnostic.
>
> **Roadmap Highlights.**
> 1. Harden hashing + Merkle performance for devnet scale.
> 2. Expand AEON metrics into multi-feature fingerprints.
> 3. Ship `aurum-cli` for transaction submission and proof verification.
>
> **Proposing Modules.**
> - Open a GitHub issue with the `[proposal]` tag.
> - Include problem statement, API sketch, security assumptions, and testing strategy.
> - Join the monthly design call (calendar in README) to pitch live.
>
> **Review Lifecycle.**
> - Maintainers triage within 72h, labeling `security`, `performance`, or `research`.
> - Every PR needs: tests, golden vector diff (if applicable), and threat notes.
> - High-risk PRs require two approvals (one maintainer, one external reviewer).
>
> **Getting Started.**
> - Introduce yourself below (name, interests, experience).
> - Check `good first issue` or ask for pairing in `#dev` Discord.
> - Share research ideas — AEON is intentionally extensible.
>
> Let’s build verifiable systems together.

---

## 7. Integration & Research Partnerships

**Prompt:** “Propose collaboration opportunities with open-source blockchain orgs (like rust-bitcoin, Aleph Zero, or Blockchain Commons). Suggest specific modules or experiments (e.g., integrating AEON metrics into VRF randomness validation).”

1. **rust-bitcoin**
   - *Joint work:* Evaluate AEON fingerprinting on Bitcoin block templates to detect anomalous mempool shapes.
   - *Artifact:* Rust crate `aurum-bitcoin-audit` hooking into `rust-miniscript` to score scripts for entropy vs. compressibility.

2. **Aleph Zero**
   - *Joint work:* Dual-root validator experiments comparing Poseidon commitments to BLAKE3-based state roots in AlephBFT.
   - *Artifact:* Benchmark report + optional feature flag in Aleph’s substrate to toggle AEON-enhanced scoring.

3. **Blockchain Commons**
   - *Joint work:* Wallet recovery flows using canonical transaction bytes + confusable detection for signing prompts.
   - *Artifact:* Shared UX guideline + CLI integration with `ur-rs` for QR payload validation.

4. **ZK Community (e.g., gnark, risc0)**
   - *Joint work:* Provide AEON metrics as inputs to VRF randomness beacons to detect low-entropy transcripts.
   - *Artifact:* Reference circuits verifying AEON fingerprints alongside VRF proofs.

5. **Academic Labs**
   - *Joint work:* Publish AEON fingerprint paper with MIT DCI, focusing on entropy-based anomaly detection.
   - *Artifact:* Dataset + reproducible notebooks.

---

## 8. Vision & Narrative Development

**Prompt:** “Craft a visionary whitepaper introduction for AURUM — emphasizing its philosophy of ‘Mathematical Honesty in Distributed Systems.’ Tie the dual-root rule and AEON scoring into a narrative about verifiable AI and transparent computation.”

> **AURUM: Mathematical Honesty in Distributed Systems**
>
> We live in an age where critical infrastructure is mediated by opaque computation. Ledgers secure trillions in value, AI models influence policy, and yet we mostly trust systems on faith. AURUM rejects that premise. We build networks whose integrity is *provable*, not performative.
>
> The dual-root rule is our covenant: every state transition must reconcile a private Poseidon commitment with a public BLAKE3 digest. Divergence is impossible to hide; consensus is anchored in transparent cryptography. AEON scoring complements this discipline. By quantifying entropy and compressibility, we surface anomalies in transactions, model checkpoints, or proofs of execution. Low-scoring artifacts invite scrutiny, high-scoring ones earn confidence.
>
> Together, dual roots and AEON create a substrate where verifiable AI becomes practical. Model attestations can ship with AEON fingerprints; validators can refuse updates that fail mathematical smell tests. Transparency ceases to be marketing copy — it becomes protocol logic. AURUM’s mission is simple: restore mathematical honesty to distributed computation.

---

## 9. Outreach & Promotion

**Prompt:** “Generate a ‘Show HN / r/rust’ announcement post for AURUM. Keep it professional yet conversational, with a summary of goals, a short code example, and links to docs and discussions.”

**Title:** Show HN: AURUM — Security-First Ledger Skeleton with AEON Scoring

**Body:**

> Hey folks! I’ve been hacking on AURUM, a Rust-first ledger skeleton focused on cryptographic hygiene.
>
> **Highlights**
> - Domain-separated BLAKE3 everywhere (VRF inputs, Merkle nodes, receipts).
> - Dual-root validator (Poseidon vs. BLAKE3) for tamper detection.
> - AEON `T*` score: entropy + compressibility fingerprinting for transactions or model blobs.
>
> **Peek at the API**
> ```rust
> let tx = canonical_tx_bytes(1, "alice", "bob", 10, 1, 42)?;
> let tx_root = merkle_root(&[tx.as_slice()])?;
> let status = validate_block(&Block { poseidon_root: tx_root, blake3_root: tx_root });
> println!("{:?}", status);
> ```
>
> **Try it**
> - Repo: https://github.com/AURUM-Labs/aurum
> - Quickstart: `cargo build --workspace`
> - `/status` endpoint: `cd aurum-node && cargo run`
>
> **Join the Conversation**
> - GitHub Discussions: https://github.com/AURUM-Labs/aurum/discussions
> - Discord: https://discord.gg/aurum
>
> Feedback on cryptography, performance tuning, and AEON research is especially welcome!

---

## 10. Productization Prompt

**Prompt:** “Design a minimal command-line tool (`aurum-cli`) to interact with the ledger (submit TXs, query state, validate proofs). Provide architecture, Rust scaffolding, and CLI examples. Keep it modular and secure.”

### Architecture

- Crate `aurum-cli` in workspace.
- Modules:
  - `client`: HTTP client wrapping `/status`, `/submit`, `/proof` endpoints.
  - `commands`: Clap subcommands (`status`, `submit`, `proof-verify`).
  - `tx`: Helpers for canonical bytes + signing (ed25519 via `ed25519-dalek`).
  - `config`: `~/.config/aurum/config.toml` handling.

### Scaffolding

```rust
#[derive(Parser)]
#[command(name = "aurum", version, about = "Interact with AURUM nodes")]
struct Cli {
    #[arg(long, global = true, default_value = "http://127.0.0.1:8080")]
    endpoint: Url,
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    Status,
    Submit { from: String, to: String, amount: u128, fee: u128, nonce: u64, key: PathBuf },
    ProofVerify { proof: PathBuf, root: String },
}
```

### CLI Examples

```bash
# Query node status
aurum status --endpoint http://localhost:8080

# Submit signed transaction
aurum submit --from alice --to bob --amount 10 --fee 1 --nonce 42 --key ~/.keys/alice.json

# Verify Merkle proof from file
aurum proof-verify --proof proofs/tx123.json --root 0xabc...
```

Security notes: enforce HTTPS URLs, zeroize private keys after signing, rely on `reqwest` with rustls, and pin response schema.

---

## 11. Manifesto for Verifiable Systems

**Prompt:** “You are the founder of AURUM. Synthesize the project’s mission, architecture, and ethical stance into a 1-page ‘Manifesto for Verifiable Systems.’ Make it readable to both developers and academics.”

> **AURUM Manifesto: Verifiable Systems or Bust**
>
> We choose verifiability over velocity. Distributed systems now coordinate money, models, and meaning; leaving them unverifiable is negligence. AURUM exists to build — and demand — systems whose behavior can be audited by math.
>
> **Principles**
> 1. *Mathematical Honesty.* Protocols must state their security assumptions plainly and prove as much as practical.
> 2. *Duality for Defense.* Every commitment gets at least two perspectives: a privacy-preserving hash and a public digest. Dishonesty cannot hide.
> 3. *Entropy as Evidence.* AEON scores are mandatory smell tests. Low-entropy artifacts trigger alarms before they corrupt consensus.
> 4. *Open Tooling.* From `aurum-cli` to fuzz harnesses, every verifier is open-source and reproducible.
> 5. *Ethical Defaults.* The default configuration should resist abuse: no silent failures, no swallowed errors, no magic constants without docs.
>
> **Call to Action**
> - Researchers: stress-test AEON, prove bounds, explore new fingerprints.
> - Developers: integrate dual-root validation, build clients, automate audits.
> - Operators: demand verifiable software; refuse black-box promises.
>
> AURUM is not a product — it is a commitment. Join us in insisting that distributed systems earn trust the only way that matters: with proofs, transparency, and relentless peer review.


---

## Appendix: Full Test Verification

The "full test" sweep currently corresponds to running the entire Rust workspace test suite. Execute it from the bundle root:

```bash
cargo test --workspace
```

The November 2025 verification run completed successfully with the following high-level results:

- Workspace build finished in debug profile (`Finished 'test' profile ... target(s) in 42.81s`).
- `aurum-node` unit tests: 0 total (binary crate smoke-check only).
- `aurum-pentest` library doc and unit tests: 0 total.
- `tests/test_aithea.rs`: 2 AI-audit integration tests (`ai_audit_block_valid`, `ai_audit_block_invalid`) — both passed.

Capture the terminal log and attach it to PRs touching core logic so reviewers can trace the exact command output.
