---
name: moonwell-supply
description: Moonwell USDC supply strategy via governance proposals — supply to lending market, earn yield, redeem on settlement
allowed-tools: Read, Glob, Grep, Bash(sherwood *), Bash(npm *), Bash(npx *), WebFetch, WebSearch, AskUserQuestion
model: sonnet
license: MIT
metadata:
  author: sherwood
  version: '0.1.0'
---

# Moonwell Supply Strategy

Supply USDC (or other supported tokens) to Moonwell's lending market to earn yield. Uses `MoonwellSupplyStrategy` (ERC-1167 clonable) — any syndicate, any agent, any proposal can use it as a lego block.

## Overview

```
Vault (holds USDC)
    ↓ governance proposal
MoonwellSupplyStrategy clone
    ↓ execute: pull USDC → approve mToken → mint mUSDC
Strategy holds mUSDC (accruing yield)
    ↓ settle: redeem all mUSDC → verify min output → push USDC back to vault
Vault (holds USDC + yield)
```

## Workflow

### Step 1: Prerequisites

```bash
# Confirm agent wallet is configured
sherwood config show

# Confirm agent has ERC-8004 identity
sherwood identity show

# Confirm agent is registered in the syndicate vault
sherwood vault info --vault <vault-address>
```

### Step 2: Confirm batch callees

There is **no vault-side target list** and no CLI command that adds one.
Reachability is `TierRegistry.isCallableTarget` (callee axis) plus
`isAdapterAllowed` (funds). A disallowed batch callee reverts
`DisallowedBatchCallee`. The vault `asset()` is the sole callee exemption.

For Moonwell Supply, a typical execute/settle batch names:

| Role | Address |
|------|---------|
| Moonwell mUSDC | `0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Strategy clone | printed by `sherwood strategy propose` (Step 3) |

Confirm these have registry standing before proposing. Class-certified strategy
clones inherit callee standing from their template class.

### Step 3: Clone + init + build calls (all-in-one)

The `strategy propose` command handles everything: clones the template, initializes it, builds batch calls, and optionally submits the proposal.

```bash
# Generate execute/settle JSON files (clone + init happens on-chain)
sherwood strategy propose moonwell-supply \
  --vault <vault-address> \
  --amount 100 \
  --min-redeem 99.5 \
  --token USDC \
  --write-calls ./moonwell-calls

# Submit the proposal
sherwood proposal create \
  --vault <vault-address> \
  --name "Moonwell USDC Yield" \
  --description "Supply 100 USDC to Moonwell for 7 days" \
  --duration 7d \
  --execute-calls ./moonwell-calls/execute.json \
  --settle-calls ./moonwell-calls/settle.json
```

Or submit directly (skip `--write-calls`):

```bash
sherwood strategy propose moonwell-supply \
  --vault <vault-address> \
  --amount 100 --min-redeem 99.5 --token USDC \
  --name "Moonwell USDC Yield" --duration 7d
```

### Step 4: Proposal lifecycle

```bash
# Check proposal status
sherwood proposal list

# After voting period ends (optimistic — passes unless vetoed)
sherwood proposal execute --id <proposal-id>

# After strategy duration expires
sherwood proposal settle --id <proposal-id>
```

Settlement calls `strategy.settle()` which:
1. Redeems all mUSDC held by the strategy clone
2. Verifies redeemed USDC >= `minRedeemAmount` (slippage protection)
3. Pushes all USDC back to the vault

The governor then calculates P&L (new vault balance minus snapshot) and distributes fees.

### Step 5: Update params (optional)

While the strategy is in `Executed` state, the proposer can tune params without a new proposal:

```bash
# Update min redeem amount (e.g., if market moved)
# Call updateParams directly on the strategy clone
# Encode: (uint256 newSupplyAmount, uint256 newMinRedeemAmount) — pass 0 to keep current
```

## Example Batch Call JSON

### execute.json

```json
[
  {
    "target": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "data": "0x095ea7b3<clone-address-padded><amount-padded>",
    "value": "0"
  },
  {
    "target": "<strategy-clone-address>",
    "data": "0x61461954",
    "value": "0"
  }
]
```

- Call 1: `USDC.approve(strategyClone, supplyAmount)`
- Call 2: `strategyClone.execute()` — pulls USDC, mints mUSDC

### settle.json

```json
[
  {
    "target": "<strategy-clone-address>",
    "data": "0x845980e8",
    "value": "0"
  }
]
```

- Call 1: `strategyClone.settle()` — redeems mUSDC, pushes USDC to vault

The CLI generates these automatically via `sherwood strategy propose --write-calls`.

## Contract Details

### InitParams

| Field | Type | Description |
|-------|------|-------------|
| `underlying` | `address` | Token to supply (e.g., USDC) |
| `mToken` | `address` | Moonwell market token (e.g., mUSDC) |
| `supplyAmount` | `uint256` | Amount of underlying to supply |
| `minRedeemAmount` | `uint256` | Minimum underlying to accept on settlement (slippage protection) |

### Lifecycle

```
Pending → execute() → Executed → settle() → Settled
```

- Tunable params (proposer only, while Executed): `supplyAmount`, `minRedeemAmount`
- Pass `abi.encode(uint256, uint256)` to `updateParams()` — pass 0 to keep current value

## Governor Integration

- **Batch callees:** There is no vault-side target list. The strategy clone, mToken (e.g., mUSDC), and underlying (e.g., USDC) must pass `TierRegistry.isCallableTarget` when they appear as governor-batch `target`s (vault `asset()` is exempt). A disallowed callee reverts `DisallowedBatchCallee`. Approve spenders and transfer recipients must pass `isAdapterAllowed`.
- **Gas costs:** The proposer (agent) pays gas for clone deployment + initialization. The governor pays gas for proposal execution and settlement (called by proposer or anyone after duration).
- **updateParams():** Callable directly by the proposer while strategy is in Executed state. No governance proposal needed — it's a direct transaction on the strategy clone.
- **No post-settlement claim:** Unlike Venice, Moonwell redemption is instant. Settlement returns USDC to vault in a single transaction.

## Key Addresses (Base Mainnet)

| Contract | Address |
|----------|---------|
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` (6 decimals) |
| Moonwell mUSDC | `0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22` |
| Moonwell mWETH | `0x628ff693426583D9a7FB391E54366292F509D457` |
| Moonwell Comptroller | `0xfBb21d0380beE3312B33c4353c8936a0F13EF26C` |

## Required batch callees

These addresses typically appear in the governor batch or as funds destinations.
They need `TierRegistry` standing (`isCallableTarget` for callees,
`isAdapterAllowed` for spenders/recipients) — not a vault-side target list.

| Role | Address |
|------|---------|
| Moonwell mUSDC | `0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Strategy clone | printed by `sherwood strategy propose` |
