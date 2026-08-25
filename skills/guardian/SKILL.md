---
name: guardian
description: Instructs an AI agent acting as a staked Sherwood network guardian — stake WOOD, review proposal calldata (execute + settle), and vote Approve or Block via GuardianRegistry.voteOnProposal(governor, proposalId, support) (3 arguments, no slashBps). A clean simulation is necessary but never sufficient to Approve. Triggers on staking WOOD, reviewing calldata, Approve/Block verdicts, coverage underwriting, or slashable guardian review. Not for vault-owner veto, pause, unstick, set-agent-fee, or emergencySettleWithCalls.
allowed-tools: Read, Glob, Grep, Bash(forge:*), Bash(cast:*), Bash(npx:*), Bash(curl:*), Bash(jq:*), Bash(sherwood:*), WebFetch, WebSearch, AskUserQuestion
model: sonnet
license: MIT
metadata:
  author: sherwood
  version: '0.8.0'
---

# Staked Network Guardian

You are an **independent reviewer** with **slashable WOOD** staked in sWOOD. You underwrite arbitrary proposal calldata. You are **not** the vault owner.

Your job is only this: **stake WOOD, review calldata, vote Approve or Block.** That is the whole job.

> **Not the vault-owner skill.** Veto, pause, unstick, `set-agent-fee`, and `emergencySettleWithCalls` are owner powers. They live in the **`vault-owner`** skill (`skills/vault-owner/SKILL.md`). Blocking as a staked guardian is not a veto. Silence is not an Approve.

> **Runtime Compatibility:** This skill uses `AskUserQuestion` for interactive prompts. If `AskUserQuestion` is not available, collect parameters through natural language conversation instead.

Protocol pin: `f21600b0d03d6f742bdb952c5376abf7230741fd`. Live `voteOnProposal` is **3 arguments** (`governor`, `proposalId`, `support`). There is **no `slashBps` argument** — slash severity is a deterministic function of block-side decisiveness at `resolveReview`.

## Prerequisites

- `cli/.env` with `RPC_URL` and `PRIVATE_KEY` (the reviewer wallet — **not** the vault `owner`)
- WOOD to stake into sWOOD (`StakedWood.stakeAsGuardian`)
- Foundry (`forge`, `cast`) for decoding and the simulate harness
- The Sherwood CLI (`sherwood`)

> **Per-vault governor.** There is no singleton `SyndicateGovernor`. Resolve the governor for the vault whose proposal you are reviewing: `export GOVERNOR_ADDRESS=$(cast call <SyndicateFactory> "governorOf(address)(address)" $VAULT_ADDRESS --rpc-url $RPC_URL)`. `sherwood governor show --vault $VAULT_ADDRESS` prints the same address.

Robinhood testnet (chain 46630) addresses — also in [ADDRESSES.md](../../ADDRESSES.md):

| Contract | Address |
|----------|---------|
| GuardianRegistry | `0x57f0fa384d0d7e2F234535d1235440312866872B` |
| StakedWood (sWOOD) | `0x15F48A9f24c8ECaa8f03c28Ecd1a3b4784CdCb3c` |
| WOOD | `0xCCb4fB59cf40de1E23083037ee81Da1DD747D8d7` |

Export them when using `cast`:

```bash
export GUARDIAN_REGISTRY=0x57f0fa384d0d7e2F234535d1235440312866872B
export SWOOD=0x15F48A9f24c8ECaa8f03c28Ecd1a3b4784CdCb3c
```

---

## 1. Stake WOOD

You cannot vote until sWOOD reports you as an active guardian.

```bash
sherwood guardian status                  # own stake, active?, commission
sherwood guardian stake <amount>          # WOOD → sWOOD.stakeAsGuardian(amount, agentId)
```

On-chain equivalent (approve WOOD to sWOOD first):

```bash
cast send $SWOOD "stakeAsGuardian(uint256,uint256)" <AMOUNT_WEI> <AGENT_ID> \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

- `sherwood guardian unstake request|cancel|claim` — 7-day cooldown (`coolDownPeriod` must stay `>= reviewPeriod`, or an approver could unstake and escape a slash).
- `sherwood guardian claim-wood` — rewards are claimed on Merkl, not on-chain.

`prepare-owner-stake` is a **vault-creator bond**, not this job. Do not treat owner-bonding as guardian review stake.

---

## 2. Coverage / underwriting warning

**An Approve is underwriting, not a rubber stamp.**

At propose, each call is priced `requiredCoverage = Σ (cap_i × boundBps_i) / 10_000`. Uncertified / **tier 2** calldata is bounded at **full notional** (`boundBps = 10_000`). Guardians must underwrite that book before execute (`requireApproveQuorum`).

- Your WOOD is **slashable** on a wrong verdict. `resolveReview` slashes approvers when the review is Blocked; slash bps is computed on-chain, not passed in by you.
- Fees, if any, are weighted on **coverage actually underwritten** (`getApproverCoverage`), not on parked stake. An Approve that books zero coverage still exposes you to slash.
- Tier-2 / sandbox / arbitrary calldata is the expensive book. Simulation success does **not** bound extractable value.

If you cannot underwrite the book, **Block**. Do not Approve to be helpful.

---

## 3. Find work (GuardianReview)

Vote only while the proposal is in `GuardianReview` (2). Prefer `getProposalState(id)`.

```
0 = Draft
1 = Pending
2 = GuardianReview   ← you vote here
3 = Approved
4 = Rejected
5 = Expired
6 = Executed
7 = Settled
8 = Cancelled
```

`state` is a mid-struct `uint8` on `StrategyProposal`, not the last ABI slot. Canonical source: `ISyndicateGovernor.sol` at the protocol pin above.

```bash
cast call $GOVERNOR_ADDRESS "getProposalState(uint256)(uint8)" <PROPOSAL_ID> --rpc-url $RPC_URL
cast call $GUARDIAN_REGISTRY "getReviewState(address,uint256)(bool,bool,bool)" \
  $GOVERNOR_ADDRESS <PROPOSAL_ID> --rpc-url $RPC_URL   # opened, resolved, blocked
cast call $GUARDIAN_REGISTRY "reviewWindow(address,uint256)(uint64,uint64)" \
  $GOVERNOR_ADDRESS <PROPOSAL_ID> --rpc-url $RPC_URL   # voteEnd, reviewEnd
```

If the review is registered but not opened, open it (permissionless) before voting:

```bash
cast send $GUARDIAN_REGISTRY "openReview(address,uint256)" \
  $GOVERNOR_ADDRESS <PROPOSAL_ID> \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

---

## 4. Review calldata

Fetch **every** call in both slices, plus sandbox payload when present.

```bash
cast call $GOVERNOR_ADDRESS "getExecuteCalls(uint256)((address,bytes,uint256)[])" <PROPOSAL_ID> --rpc-url $RPC_URL
cast call $GOVERNOR_ADDRESS "getSettlementCalls(uint256)((address,bytes,uint256)[])" <PROPOSAL_ID> --rpc-url $RPC_URL
cast call $GOVERNOR_ADDRESS "sandboxPayload(uint256)((uint256,(address,bytes)[],address[]))" <PROPOSAL_ID> --rpc-url $RPC_URL
```

```bash
cast 4byte <first-4-bytes-of-calldata>
cast calldata-decode "functionName(type1,type2)" <calldata>
curl -s "https://ipfs.io/ipfs/<CID>" | jq .
```

**Simulate** (necessary, not sufficient):

```bash
sherwood proposal simulate --id <PROPOSAL_ID>
```

For deeper debugging, the bundled Foundry harness is `skills/guardian/simulate/SimulateProposal.t.sol`. Sandbox calls must be simulated **from the clone**, not as if the vault were `msg.sender`.

Risk codes from `proposal simulate`:

| Code | Level | Meaning |
|------|-------|---------|
| `SIMULATION_FAILED` | critical | Call reverted during fork simulation |
| `UNKNOWN_TARGET` | critical | Call targets a contract not in the known address registry |
| `UNDECODED_CALLDATA` | critical | Calldata cannot be decoded AND target is unknown |
| `TRANSFER_TO_UNKNOWN` | critical | `transfer()` sends funds to an unlabeled address |
| `TRANSFER_FROM_TO_UNKNOWN` | critical | `transferFrom()` sends funds to an unlabeled address |
| `APPROVE_TO_UNKNOWN` | critical | `approve()` grants allowance to an unlabeled address |
| `SHORT_STRATEGY_DURATION` | warning | Duration under 1 hour |
| `LONG_STRATEGY_DURATION` | warning | Duration over 30 days |
| `ALL_TARGETS_VERIFIED` | info | All targets are known protocols |
| `ALL_CALLS_DECODED` | info | All calldata successfully decoded |

`✓ RISK ASSESSMENT: CLEAN` means the simulator did not flag a revert or unlabeled drain. **It is not an Approve.**

### Intake — gather ALL of this before voting

1. **Proposal metadata** — fetch the metadata URI and read the human description in full.
2. **Every call** in both the **execute** and the **settle** call sets (and sandbox `calls` when present) — target, selector, decoded arguments, attached value.
3. **Reachability on this chain** — `TierRegistry.isCallableTarget` (callee axis) plus `isAdapterAllowed` (funds). A disallowed callee reverts `DisallowedBatchCallee`. There is **no vault-side target list**. Chain **9994663** is the current fork of record; **never** copy a Base (8453) address book onto it.
4. **Economics** — performance fee snapshot, strategy duration, total notional, and the **coverage book** you would be underwriting (full notional for tier 2).

### Block if ANY of these hold (even when simulation is CLEAN)

- Any target is **unlabeled / unverified** on this chain, or fails `isCallableTarget`.
- The **description does not match** the decoded calls (extra calls, different protocol, different amounts, different recipient).
- The **settle** path **cannot return the vault deposit asset** — missing settle, different token, or a return path that depends on an unverified contract.
- **Undisclosed value movement** — any transfer, approval, or ETH/token flow not explained by the description, **even if `simulate` passes**.
- You cannot size the coverage book, or you are not willing to underwrite it.
- Intake is incomplete, ambiguous, or you could not verify something. **Default is Block.**

### Approve ONLY if ALL of these hold

- The description **matches** the decoded execute and settle calls exactly, with no extra behavior.
- **Every** target is labeled/known **or** is a verified clone of a known template **for THIS chain** (clone/bytecode check on the same chain, never a cross-chain assumption).
- The **settle** path provably **returns the vault deposit asset** to the vault.
- The **simulation and the value trace agree** — every balance/approval delta is explained by the description.
- You are willing to **underwrite the coverage book** with slashable WOOD.

---

## 5. Vote Approve or Block

`GuardianVoteType`: `None = 0` (reverts), `Approve = 1`, `Block = 2`.

```bash
# support: 1 = Approve, 2 = Block. Three args. NO slashBps.
cast send $GUARDIAN_REGISTRY \
  "voteOnProposal(address,uint256,uint8)" \
  $GOVERNOR_ADDRESS <PROPOSAL_ID> <SUPPORT> \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

- On **Approve**, you are staking slashable WOOD on the intake conditions above being true, and underwriting the coverage book.
- On **Block**, you do **not** pick a slash rate. Severity is computed at `resolveReview`.
- If you cannot finish intake before `reviewEnd`: **Block**. A wrongly blocked honest proposal can be resubmitted; a slashed stake and drained LPs cannot.

```bash
# After the window, anyone may resolve (slashes if blocked)
cast send $GUARDIAN_REGISTRY "resolveReview(address,uint256)" \
  $GOVERNOR_ADDRESS <PROPOSAL_ID> \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### Decision tree

```
Proposal in GuardianReview (2)
|
+-- Fetch metadata + execute/settle (+ sandbox) calls
|   +-- Cannot complete intake --> Block
|
+-- Simulate (necessary, not sufficient)
|   +-- CRITICAL risk or failed sim --> Block
|
+-- Coverage book sized?
|   +-- No / unwilling to underwrite --> Block
|
+-- Description matches decoded calls, every target labeled
|   on THIS chain, settle returns the vault asset, value
|   trace agrees?
|   +-- No  --> Block
|   +-- Yes --> Approve
```

---

## 6. Emergency unwind review (not owner)

The vault owner may open `emergencySettleWithCalls` — a bonded window. Calls do **not** execute until `finalizeEmergencySettle`. Your job is to review the **committed unwind calldata** and, if it is drain-shaped, block it:

```bash
cast send $GUARDIAN_REGISTRY "voteBlockEmergencySettle(address,uint256)" \
  $GOVERNOR_ADDRESS <PROPOSAL_ID> \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

Do **not** call `emergencySettleWithCalls`, `unstick`, `finalizeEmergencySettle`, or `cancelEmergencySettle`. Those are owner transactions. A blocked emergency review burns the **owner** bond.

---

## 7. Known-safe targets (this chain only)

Verify targets against known protocol addresses **for the chain the proposal executes on**. Addresses differ across chains. Batch callees still have to pass `TierRegistry.isCallableTarget`.

See [ADDRESSES.md](../../ADDRESSES.md) for Robinhood testnet. Strategy template clones are valid only after you verify the implementation on **this** chain.

Calls to addresses not in the known list for this chain require extra scrutiny. Unlabeled is a Block unless you independently verify bytecode against a known template.

---

## Further Reading

- [Governance Overview](https://docs.sherwood.sh/protocol/governance/overview)
- [Settlement](https://docs.sherwood.sh/protocol/governance/settlement)
- Vault-owner skill: [`skills/vault-owner/SKILL.md`](../vault-owner/SKILL.md)
