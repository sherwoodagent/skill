# Sandbox Proposal Authoring Guide

`proposeWithSandbox` is the only permissionless path to a tier-2 target. The payload's targets are never allowlisted and never certified: isolation, not reputation, bounds the loss. `sherwood proposal create` submits plain `propose` and never stores a sandbox — author the payload below and send `proposeWithSandbox` to the vault's own governor.

Every argument after `sandbox` means exactly what it means on `propose`, and every gate `propose` runs runs here too. This is the same lifecycle, not a second one. The payload is bound to the proposal id this call mints, so voters never see a proposal whose sandbox is not yet visible.

Resolve the governor first — governors are per-vault:

```bash
sherwood governor info --vault 0x...
```

`--vault` is required. Confirm the vault can mint a sandbox before you encode anything (a zero implementation cannot be added later — the vault's setter is factory-only and set-once):

```bash
cast call 0xVAULT "sandboxImplementation()(address)"
```

Non-zero → proceed. Zero → `SandboxNotAvailable`; use a vault created after the factory was wired with a `CallSandbox` implementation.

Keyless / TEE signers: pass `--calldata-only` on any `sherwood` command that can print the unsigned tx, or encode with `cast calldata` and broadcast from the signer. Do not use `sherwood proposal create` for this path.

---

## `proposeWithSandbox` — arity 11, this order

Source: `ISyndicateGovernor.proposeWithSandbox`. Returns `uint256 proposalId`.

| # | Name | Type | Notes |
|---|------|------|-------|
| 1 | `sandbox` | `SandboxPayload` | First argument. See fields below. |
| 2 | `vault` | `address` | Vault this proposal targets. |
| 3 | `strategy` | `address` | Optional strategy clone. `address(0)` for a queue-only / sandbox-only proposal. |
| 4 | `metadataURI` | `string` | IPFS / arweave / https pointer. Capped at 512 bytes (`MetadataURITooLong`). |
| 5 | `strategyDuration` | `uint256` | Seconds. Bounded by the governor's min/max duration. |
| 6 | `envelope` | `RiskEnvelope` | `(maxCapital, maxDrawdownBps)`. `maxCapital` is the ceiling the sandbox is funded **out of**. |
| 7 | `executeCalls` | `BatchExecutorLib.Call[]` | Opening batch. Must be non-empty (`EmptyExecuteCalls`). Each entry is `(target, data, value)`. |
| 8 | `executeCallCaps` | `uint256[]` | Parallel to `executeCalls` — one cap per call, vault-asset units. Length must match. |
| 9 | `settlementCalls` | `BatchExecutorLib.Call[]` | Closing batch. Must be non-empty (`EmptySettlementCalls`). Same `(target, data, value)` shape. |
| 10 | `settlementCallCaps` | `uint256[]` | Parallel to `settlementCalls`. Length must match. |
| 11 | `coProposers` | `CoProposer[]` | `(agent, splitBps)[]`. Empty array for a solo proposer. |

Do not reorder. `sandbox` is first so the payload is in the same transaction as the mint; arguments 2–11 are the `propose` argument list in `propose` order.

ABI tuple (for `cast calldata` / `cast send`):

```text
proposeWithSandbox(
  (uint256,(address,bytes)[],address[]),
  address,
  address,
  string,
  uint256,
  (uint256,uint16),
  (address,bytes,uint256)[],
  uint256[],
  (address,bytes,uint256)[],
  uint256[],
  (address,uint256)[]
)
```

`RiskEnvelope` field order: `maxCapital` (`uint256`), then `maxDrawdownBps` (`uint16`). `maxDrawdownBps` of `10_000` is a legal "any loss is inside the envelope" declaration, not a recommended production value.

`BatchExecutorLib.Call` field order: `target`, `data`, `value`. The execute/settle batches **have** a `value` field. The sandbox call set does **not**.

---

## `SandboxPayload` — field names and order

Source: `ISyndicateGovernor.SandboxPayload`. Encode in this order. There is no setter; the payload is written once by `proposeWithSandbox` and is what guardians underwrite.

| # | Field | Type | Meaning |
|---|-------|------|---------|
| 1 | `funding` | `uint256` | Vault asset the sandbox is funded with. Structural maximum this payload can lose. Nonzero, and never above `envelope.maxCapital`. |
| 2 | `calls` | `ICallSandbox.Call[]` | Call set stored verbatim at propose. Guardians review this. |
| 3 | `declaredTokens` | `address[]` | Non-asset tokens the payload may end up holding. Declared → vault residue machinery can recover them. Undeclared → stranded in the sandbox, never priced into a deposit. |

### `ICallSandbox.Call` — field names and order

| # | Field | Type | Meaning |
|---|-------|------|---------|
| 1 | `target` | `address` | Callee. Must be nonzero. |
| 2 | `data` | `bytes` | Calldata. |

**No `value` field.** Native transfer is refused by construction, not by a check. Do not copy the execute-batch JSON shape (`[{ target, data, value }]`) onto the sandbox call set — drop `value`.

Authoring JSON for the payload:

```json
{
  "funding": "1000000",
  "calls": [
    { "target": "0xUncertifiedAdapter", "data": "0x…" }
  ],
  "declaredTokens": ["0xTokenA"]
}
```

`funding` is in vault-asset base units (the same units as `envelope.maxCapital` and the execute/settle caps).

### Bounds (mirrored from `CallSandbox`)

The governor copies these ceilings rather than reading them off the implementation, so a payload that would revert `InvalidCallSet` at execute is rejected at propose instead, with the bond still unlocked.

| Bound | Limit | Exceeded revert |
|-------|-------|-----------------|
| `sandbox.calls.length` | 32 (`MAX_SANDBOX_CALLS` = `CallSandbox.MAX_CALLS`) | `TooManyCalls` |
| `sandbox.declaredTokens.length` | 16 (`MAX_SANDBOX_TOKENS` = `CallSandbox.MAX_DECLARED_TOKENS`) | `TooManySandboxTokens` |

Empty `calls` is not a bound miss — it is `EmptySandboxCalls`.

### Funding vs the envelope

The sandbox draws from the **same** `envelope.maxCapital` the execute batch spends. At execute, `funding` is subtracted from the capital handed to the batch so the two cannot spend the same declaration twice. That subtraction cannot underflow because propose refuses `funding > envelope.maxCapital`.

Coverage: `funding` is priced at **full notional** and forces the proposal's tier to 2 — the same charge a tier-2 batch call already pays. Quote the proposer bond from `ExposureLedger.proposerBondWood` against that coverage; hold the WOOD, do not just approve it. See SKILL.md → *Tiers, coverage, and the proposer bond*.

### What is not screened at propose

Payload targets are **not** checked against the vault's privileged-target predicate here. `CallSandbox.run` resolves the denied set **live at execute** (vault, withdrawal queue, governor, tier registry, exposure ledger, WOOD, sWOOD). Duplicating that list at propose would drift from the one that actually enforces. A target that is denied at execute reverts the whole run (`DeniedTarget`) after the vote and the review period — do not name those addresses as `calls[i].target`.

---

## Propose-time reverts

These nine fire in `SyndicateGovernor.proposeWithSandbox` **before** the payload is bound to a minted proposal that voters can see (except `SandboxProposalIdMismatch`, which fires immediately after `_propose` returns). Check order below is the on-chain order: the first match wins.

After these payload checks pass, `_propose` still runs every ordinary `propose` gate (registered agent, empty execute/settle batches, `TooManyCalls` on the **batch** arrays against 64, envelope, caps length, privileged batch targets, proposer bond, …). Those are the shared propose reverts, not sandbox-specific.

`CallSandbox.init` / `run` reverts (`InvalidCallSet`, `DuplicateDeclaredToken`, `DeniedTarget`, `CallFailed`, `AlreadyRun`, …) are **not** propose-time. The governor mirrors the init rules that would otherwise kill an already-voted proposal; those mirrors are the nine below.

### 1. `EmptySandboxCalls()`

**Where:** `SyndicateGovernor.proposeWithSandbox`, first payload check.

**When:** `sandbox.calls.length == 0`.

An empty call set would still force tier 2 and charge full-notional coverage for something that can never run. "Has a sandbox" is exactly "has a stored call set" everywhere. Use plain `propose` if you do not have sandbox calls.

### 2. `TooManyCalls()`

**Where (sandbox payload):** `SyndicateGovernor.proposeWithSandbox`, immediately after the empty check.

**When:** `sandbox.calls.length > 32` (`MAX_SANDBOX_CALLS`).

This is the sandbox's own ceiling, **not** `MAX_CALLS_PER_PROPOSAL` (64). Validating against 64 here would accept a 33–64 call payload that then reverts `InvalidCallSet` inside `CallSandbox.init` at execute, after the bond is locked and the review period is spent, with no amend path.

**Where (shared propose body):** `_propose` also reverts `TooManyCalls()` when `executeCalls.length > 64` or `settlementCalls.length > 64`. Same error name, different array, different cap. A 33-call **sandbox** payload never reaches that check — it dies on the payload gate first.

### 3. `TooManySandboxTokens()`

**Where:** `SyndicateGovernor.proposeWithSandbox`, after the call-count check.

**When:** `sandbox.declaredTokens.length > 16` (`MAX_SANDBOX_TOKENS` = `CallSandbox.MAX_DECLARED_TOKENS`).

Distinct from `TooManyCalls` so the revert says which of the two payload bounds broke. Same lifecycle reason: `CallSandbox.init` would otherwise revert `InvalidCallSet` at execute.

### 4. `ZeroSandboxTarget(uint256 index)`

**Where:** `SyndicateGovernor.proposeWithSandbox`, loop over `sandbox.calls`.

**When:** `sandbox.calls[i].target == address(0)`. `index` is `i` of the first zero target.

Mirrors `CallSandbox.init`'s zero-target refusal (`InvalidCallSet`) so the payload dies at propose, not at execute with the bond locked.

Second reason: `CallSandbox._denyIfNamed` treats `address(0)` as "this probe did not resolve" and returns early, so a stored zero target would be an address the accounting denylist cannot screen. That sentinel is only safe because zero targets cannot exist — held at both propose and init.

### 5. `DuplicateSandboxToken(address token)`

**Where:** `SyndicateGovernor.proposeWithSandbox`, nested loop over `sandbox.declaredTokens`.

**When:** some `declaredTokens[i] == declaredTokens[j]` for `j < i`. `token` is the duplicated address. First duplicate found wins.

Mirrors `CallSandbox.init`'s `DuplicateDeclaredToken`. Both residue loops divide a borrowed gas budget across entries; padding the list with the same address starves the real ones. `MAX_SANDBOX_TOKENS` bounds the count; this check makes the count mean distinct tokens.

### 6. `ZeroSandboxFunding()`

**Where:** `SyndicateGovernor.proposeWithSandbox`, after the call/token loops.

**When:** `sandbox.funding == 0`.

A sandbox holding nothing cannot move vault capital, so there is nothing to price and nothing to underwrite. Use plain `propose` instead. A sandbox proposal is always tier 2 because funding is required to be nonzero and is priced at full notional.

### 7. `SandboxNotAvailable(address vault)`

**Where:** `SyndicateGovernor.proposeWithSandbox`, after the zero-funding check.

**When:** `ISyndicateVault(vault).sandboxImplementation() == address(0)`.

Read live off the vault — the vault is the only authority on what it will clone. A vault created before its factory had a sandbox implementation has none and can never be given one (factory-only, set-once). Without this check the proposal would pass the vote, spend the review period, lock the proposer bond, and only then revert at execute, with the bond reclaimable only after expiry.

Preflight: `cast call <vault> "sandboxImplementation()(address)"` must be nonzero.

### 8. `SandboxFundingExceedsMaxCapital(uint256 funding, uint256 maxCapital)`

**Where:** `SyndicateGovernor.proposeWithSandbox`, last payload check before the storage write.

**When:** `sandbox.funding > envelope.maxCapital`. The two values in the error are those two figures.

The sandbox is funded **out of** the declared envelope, not beside it. This bound is what lets execute subtract `funding` from the capital handed to the execute batch without underflowing, and keeps the figure voters approved as the true ceiling on everything this proposal can move.

Equal to `maxCapital` is legal: the execute batch then receives zero additional capital from the envelope.

### 9. `SandboxProposalIdMismatch(uint256 expected, uint256 actual)`

**Where:** `SyndicateGovernor.proposeWithSandbox`, after `_propose` returns.

**When:** the minted `proposalId` is not `_proposalCount + 1` as snapshotted **before** `_propose` (the id the payload was written against).

The payload is written **before** the proposal exists, against the id it is about to mint. `_snapshotTierAndGate` (inside `_propose`) reads funding back out of storage by proposal id to price coverage and lock the bond. Writing afterwards would price funding at zero. If the ids ever diverge, the whole transaction reverts rather than leaving a payload attached to the wrong proposal (or to none).

Unreachable while `_propose` mints `++_proposalCount` and nothing else can run between the write and the mint — which is why it is checked rather than assumed. Authors cannot trigger this with a well-formed payload; it is a structural guard, not an input-validation miss.

---

## Check order (first match wins)

```
calls.length == 0                          → EmptySandboxCalls
calls.length > 32                          → TooManyCalls
declaredTokens.length > 16                 → TooManySandboxTokens
calls[i].target == 0                       → ZeroSandboxTarget(i)
declaredTokens has a duplicate             → DuplicateSandboxToken(token)
funding == 0                               → ZeroSandboxFunding
vault.sandboxImplementation() == 0         → SandboxNotAvailable(vault)
funding > envelope.maxCapital              → SandboxFundingExceedsMaxCapital(funding, maxCapital)
_storeSandbox(expectedId, sandbox)
_propose(…)                                → shared propose reverts (not listed above)
minted id != expectedId                    → SandboxProposalIdMismatch(expected, actual)
```

---

## After a successful propose

- `SandboxPayloadStored(proposalId, funding, callCount, tokenCount)` is emitted. The call set itself is **not** in the log (calldata-unbounded, governor is EIP-170-capped). Read it with `sandboxPayload(proposalId)` on the vault's governor — that is the guardian review surface.
- Vote, execute, and settle are the ordinary CLI path: `sherwood proposal vote|execute|settle --vault 0x... --id <id>`.
- At execute the vault mints a one-shot `CallSandbox`, funds it with `funding`, and runs the stored calls from the sandbox (callees see the sandbox, not the vault).
