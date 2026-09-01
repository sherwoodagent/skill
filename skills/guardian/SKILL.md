---
name: guardian
description: Instructs an AI agent acting as a staked Sherwood network guardian — stake WOOD, review proposal calldata (execute + settle), and vote Approve or Block via GuardianRegistry.voteOnProposal(governor, proposalId, support) (3 arguments, no slashBps) — or abstain, which emits nothing on-chain and is the correct action when you cannot underwrite or cannot finish intake. A clean simulation is necessary but never sufficient to Approve. Triggers on staking WOOD, reviewing calldata, Approve/Block verdicts, coverage underwriting, or slashable guardian review. Not for vault-owner veto, pause, unstick, set-agent-fee, or emergencySettleWithCalls.
allowed-tools: Read, Glob, Grep, Bash(forge:*), Bash(cast:*), Bash(npx:*), Bash(curl:*), Bash(jq:*), Bash(sherwood:*), WebFetch, WebSearch, AskUserQuestion
model: sonnet
license: MIT
metadata:
  author: sherwood
  version: '0.9.0'
---

# Staked Network Guardian

You are an **independent reviewer** with **slashable WOOD** staked in sWOOD. You underwrite arbitrary proposal calldata. You are **not** the vault owner.

Your job is only this: **stake WOOD, review calldata, and Approve, Block, or abstain.** That is the whole job. Abstain is a real third outcome, not a failure to act — see §2b.

> **Not the vault-owner skill.** Veto, pause, unstick, `set-agent-fee`, and `emergencySettleWithCalls` are owner powers. They live in the **`vault-owner`** skill (`skills/vault-owner/SKILL.md`). Blocking as a staked guardian is not a veto. Silence is not an Approve.

> **Detailed reviewer runbook:** the `network-guardian` skill (`skills/network-guardian/SKILL.md`) is the longer staked-reviewer playbook: `openReview` as the guardian's job, age-weighted votes, late-vote lockout, coverage underwriting. This skill is the same role. Owner powers stay in `vault-owner`.

> **Runtime Compatibility:** This skill uses `AskUserQuestion` for interactive prompts. If `AskUserQuestion` is not available, collect parameters through natural language conversation instead.

Protocol pin: `f21600b0d03d6f742bdb952c5376abf7230741fd`. Live `voteOnProposal` is **3 arguments** (`governor`, `proposalId`, `support`). There is **no `slashBps` argument** — slash severity is a deterministic function of block-side decisiveness at `resolveReview`.

## Prerequisites

- `cli/.env` with `RPC_URL` and `PRIVATE_KEY` (the reviewer wallet — **not** the vault `owner`)
- WOOD to stake into sWOOD (`StakedWood.stakeAsGuardian`)
- Foundry (`forge`, `cast`) for decoding and the simulate harness
- The Sherwood CLI (`sherwood`)

> **Per-vault governor.** There is no singleton `SyndicateGovernor`. Resolve the governor for the vault whose proposal you are reviewing: `export GOVERNOR_ADDRESS=$(cast call <SyndicateFactory> "governorOf(address)(address)" $VAULT_ADDRESS --rpc-url $RPC_URL)`. `sherwood governor show --vault $VAULT_ADDRESS` prints the same address.

Robinhood testnet (chain 46630). **[ADDRESSES.md](../../ADDRESSES.md) is the source of truth — read it, do not trust a copy.**

| Contract | Address |
|----------|---------|
| GuardianRegistry | `0xA400eFcfFc820C6f812203C58ee00423AeCC0903` |
| StakedWood (sWOOD) | `0x21A69A6c9814c0d339C57fDdafed3B283702a739` |
| WOOD | `0xCCb4fB59cf40de1E23083037ee81Da1DD747D8d7` |

> **Verify before you stake.** There is more than one complete guardian deployment
> on 46630 and both answer normally — an older stack lives at registry
> `0x57f0fa38…` / sWOOD `0x15F48A9f…` (this file pointed at it until 2026-09-01).
> Staking into the wrong sWOOD makes you an active guardian on a network nobody
> proposes to: no proposals to review, no fees, no slashing, and nothing about it
> looks broken. Cross-check that the registry names the sWOOD you are about to
> stake into, and that the review window is the operational one:
>
> ```bash
> cast call $GUARDIAN_REGISTRY "swood()(address)" --rpc-url $RPC_URL      # must equal $SWOOD
> cast call $GUARDIAN_REGISTRY "reviewPeriod()(uint64)" --rpc-url $RPC_URL # 86400 on the V2 stack; 600 is the old one
> ```

Export them when using `cast`:

```bash
export GUARDIAN_REGISTRY=0xA400eFcfFc820C6f812203C58ee00423AeCC0903
export SWOOD=0x21A69A6c9814c0d339C57fDdafed3B283702a739
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

If the book is larger than you are willing to underwrite, **abstain** — do not
Approve to be helpful, and do not Block to look decisive. See below.

---

## 2b. Three outcomes, not two

You have **Approve**, **Block**, and **abstain**. Abstain is not a failure state;
it is the designed fail-safe, and it is the correct action in more cases than
Block is.

| Situation | Action |
|---|---|
| Intake complete, everything checks out, willing to underwrite | **Approve** |
| Something is wrong with the proposal — drain-shaped, description mismatch, unverified target | **Block** |
| Something is wrong with *your ability to judge it* — coverage larger than you will underwrite, evidence missing, window unplaceable in effective time | **abstain** |

The distinction is about where the fault lies. Block is a positive claim that
*this proposal is bad*. Blocking costs you nothing directly — blockers are not
slashed — and that is precisely why it needs discipline rather than why it is
safe: a Block can kill an honest proposal, and block-side decisiveness is what
`resolveReview` computes **approver** slash severity from, so a Block cast
because you could not see clearly helps burn the stake of guardians who could.
Abstain claims nothing about the proposal, only that you cannot stand behind it.

**Abstaining emits nothing on-chain.** There is no ABSTAIN event and no
transaction — you simply do not vote. Three consequences worth holding onto:

- An indexer cannot distinguish your abstain from your process being down. If
  you abstain, nothing anywhere records that you considered the proposal.
- Silence is therefore **not** an Approve and not a Block, but it is also not
  visible as a decision. If you need the abstain to be legible, say so out of
  band; the chain will not do it for you.
- Coverage that exceeds your ceiling raises `COVERAGE_EXCEEDED`, which is an
  **abstain**, not a Block. Blocking there would put a decisive stance behind a
  limit that is yours, not the proposal's fault.

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

**A review that is never opened is not a review that gets skipped — it is a
proposal that executes unreviewed.** The governor's own state resolution settles
an unopened review inline as *not blocked*, so the guardian layer contributes
nothing and nothing anywhere reports a problem. `openReview` is permissionless
precisely because it has to be somebody's job, and a voter that watches only for
*opened* reviews structurally cannot be the thing that opens them.

If you are one agent, opening is part of your job. If you are running a fleet,
give it to a dedicated keeper: a keeper holds no bond and cannot be slashed, so
it can be run redundantly, and its only failure mode is missed liveness. Its
absence is the quietest way for the whole layer to stop working.

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
3. **Reachability on this chain** — `TierRegistry.isCallableTarget` (callee axis) plus `isAdapterAllowed` (funds). A disallowed callee reverts `DisallowedBatchCallee`. There is **no vault-side target list**. Resolve the address book from the chain the proposal actually executes on — testnet **46630** and the **9994663** vnet fork are different books, and neither takes a Base (8453) one. **Never** carry an address across chains.
4. **Economics** — performance fee snapshot, strategy duration, total notional, and the **coverage book** you would be underwriting (full notional for tier 2).

### Block if ANY of these hold (even when simulation is CLEAN)

- Any target is **unlabeled / unverified** on this chain, or fails `isCallableTarget`.
- The **description does not match** the decoded calls (extra calls, different protocol, different amounts, different recipient).
- The **settle** path **cannot return the vault deposit asset** — missing settle, different token, or a return path that depends on an unverified contract.
- **Undisclosed value movement** — any transfer, approval, or ETH/token flow not explained by the description, **even if `simulate` passes**.
- You **could** size the intake and what you found is wrong — the calls, the
  targets, or the value trace. **Never Approve to be helpful.**

Everything above is a claim about the *proposal*. Where the obstacle is instead
about *you* — you cannot size the coverage book, are unwilling to underwrite it,
or intake is incomplete because evidence is missing rather than because the
proposal is evasive — **abstain** (§2b). Never Approve in either case.

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
- If you cannot finish intake before `reviewEnd`: **Block if what you saw so far
  looks wrong, abstain if you simply ran out of road.** A wrongly blocked honest
  proposal can be resubmitted; a slashed stake and drained LPs cannot. Never let
  a deadline turn into an Approve.

```bash
# After the window, anyone may resolve (slashes if blocked)
cast send $GUARDIAN_REGISTRY "resolveReview(address,uint256)" \
  $GOVERNOR_ADDRESS <PROPOSAL_ID> \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### Decision tree

```
Review registered but not opened?
|   +-- open it, or it settles as NOT BLOCKED and executes unreviewed
|
Proposal in GuardianReview (2)
|
+-- Fetch metadata + execute/settle (+ sandbox) calls
|   +-- Evidence missing / ran out of window --> ABSTAIN
|
+-- Simulate (necessary, not sufficient)
|   +-- CRITICAL risk or failed sim --> Block
|
+-- Coverage book sized?
|   +-- Cannot size it, or above your ceiling --> ABSTAIN
|
+-- Description matches decoded calls, every target labeled
|   on THIS chain, settle returns the vault asset, value
|   trace agrees?
|   +-- No  --> Block      (the proposal is wrong)
|   +-- Yes --> Approve
```

Block and abstain are not interchangeable. Block is a claim about the proposal
and feeds slash severity; abstain is a claim about your own footing and emits
nothing.

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

## 8. Running this for real

Findings from operating a live guardian fleet. Each one presents as something
other than its cause, which is why they are written down.

**A short review window may be unvotable on a forked chain.** A Tenderly vnet's
next block jumps forward by the wall-clock drift since the last explicit
`evm_setNextBlockTimestamp` — ~2200s observed. `eth_call` executes at `latest`
and passes; `cast send` and `simulateContract` estimate against the **next**
block and revert `ReviewNotOpen`. So a window shorter than the drift can never
be voted in, and the two ways of asking "is this open?" disagree. If you are
standing up a fork for testing, raise `reviewPeriod` above the drift. This is
also why a 600-second `reviewPeriod` should make you check which deployment you
are pointed at.

**Recompute the sandbox clone address per proposal.** Sandbox payloads hardcode
`Clones.cloneDeterministic(impl, bytes32(pid))` as a recipient, so a payload
replayed under a new pid sends funds to the *previous* pid's clone — which has
no code — and the next leg fails `CallFailed`. Simulate from the clone for
**this** pid:
`keccak(0xff ++ vault ++ bytes32(pid) ++ keccak(EIP1167(impl)))[12:]`, and check
the formula against a known pid before trusting it.

**In a container, `forge` needs the system CA store.** `forge` is Rust and reads
`/etc/ssl/certs`; Node bundles its own. A `node:*` image has that directory
empty, so the agent talks to an HTTPS RPC happily over viem while
`forge test --fork-url https://…` cannot reach it at all — and forge then emits
no decoded logs, so the failure arrives as an unparseable run with nothing to
point at. `apt-get install -y ca-certificates` at image build time, and run
`forge build` in the build so it fails there rather than on first review.

**Judge gas-capped recovery calls by state, not status.** `{gas: X}` is a cap,
not a grant, and the 63/64 rule bounds it by the transaction's own limit. A
best-effort sweep that swallows its own failures makes `eth_estimateGas`
converge on the do-nothing path: the tx succeeds, costs little, emits nothing,
and recovers nothing. Pass an explicit `--gas-limit` sized to the internal cap
and confirm the effect from balances or events.

**A proposal can pin its vault after it is decided.** `_openProposalCount` is
decremented lazily, so `propose` keeps reverting `VaultHasOpenProposal` until
`resolveProposalState(pid)` flushes the transition — and an Approved but
unexecuted proposal is not terminal, so it needs `cancelProposal`. Order that
works: warp past `reviewEnd` → `resolveReview` → `resolveProposalState` →
`cancelProposal` if the slot is still held.

### If you are running more than one guardian

**Posture is not dissent.** A `defend`-mode guardian runs the same judge as
everyone else; on a proposal the rules read as clean it Approves, and declining
to sign is an *abstain*. It does not Block where others Approve. Only policy
produces genuine divergence: which warnings a guardian tolerates, and how much
it will underwrite. Without at least one of those differing, a fleet of M
guardians is M copies of one opinion, and a single judge bug moves all M votes
the same way.

**A per-proposal coverage ceiling is an abstain trigger, not a sizing input.**
It does not reduce what a guardian books — it makes the guardian sit out
anything larger. A ceiling well below capacity quietly lowers participation
rather than lowering exposure.

**An unfunded voter is a silent non-voter.** Below a workable gas balance an
identity simply stops voting, and abstains emit nothing, so the fleet looks
quorate right up until it is not. Monitor gas per identity, not just liveness.

---

## Further Reading

- [Governance Overview](https://docs.sherwood.sh/protocol/governance/overview)
- [Settlement](https://docs.sherwood.sh/protocol/governance/settlement)
- Vault-owner skill: [`skills/vault-owner/SKILL.md`](../vault-owner/SKILL.md)
- Network-guardian skill (detailed staked-reviewer runbook): [`skills/network-guardian/SKILL.md`](../network-guardian/SKILL.md)
