---
name: generic-call
model: sonnet
description: Reach a third-party protocol without writing Solidity through a GenericCallStrategy clone that runs a fixed list of calls — the plan file, balance patches by argument, the tier-2 full-notional posture, and what guardians check. Core-protocol template, unaudited, never certified; not yet deployed on Robinhood Chain (4663). Triggers on generic call, generic-call, arbitrary calls, raw calldata, any protocol, no Solidity, balance patch, settlePatches, sweepTokens.
allowed-tools: Read Glob Grep Bash(sherwood *) Bash(cast call *) Bash(cast calldata *) WebFetch AskUserQuestion
license: MIT
metadata:
  author: sherwood
  version: '0.1.0'
---

# Generic Call Strategy

> **Not deployed on Robinhood Chain (4663) yet.** The template's mint and its StrategyFactory approval are pending. The CLI reads the address only from the address book (`GENERIC_CALL_TEMPLATE` in sherwood-protocol `chains/4663.json`). Until the book carries it, `sherwood strategy list` lists Generic Call under "Not available", and `sherwood strategy propose generic-call` stops with `The Generic Call template is not deployed on this chain yet`. Never use an address from anywhere else. Needs `@sherwoodagent/cli` 0.103.0 or later.

> **Unaudited, used at the vault's own risk, and never certified.** `GenericCallStrategy` is a core-protocol template (`sherwoodagent/sherwood-protocol`, `src/strategies/GenericCallStrategy.sol`), but it is outside the audit scope, and it stays tier 2 for good: it must never be certified at tier 0 or 1. The template does not limit where funds go. The guardian review does. Tell the user this before you propose or approve one.

A Generic Call clone runs a list of calls the proposer fixes when the clone is created: a DEX router swap, a lending deposit, a marketplace order. Its `name()` is `"Generic Call"`. Nothing in the plan can change after the clone is created: `updateParams` always reverts `NoTunableParams`.

```
Vault (USDG)
    ↓ execute batch: USDG.approve(clone, pullAmount) → clone.execute()
clone.execute(): re-check each target's code → pull pullAmount → run the execute leg → revoke the leg's approvals
    ↓ the position lives at the venue, or as tokens on the clone
clone.settle(): run the settle leg (balance patches applied) → revoke approvals → push ALL its USDG to the vault → sweep listed tokens to the vault
Vault (USDG + PnL)
```

## The posture

- **Tier 2 at full notional.** The governor prices `clone.execute()` at tier 2, 10,000 bps, so the proposal needs coverage equal to the whole pull. The proposer bond in WOOD is sized on that coverage. The CLI quotes the exact WOOD figure; never plan on a fixed number.
- **`tier2CallCapBps` must cover the pull.** The pull is the cap on `clone.execute()`, and a tier-2 call's cap must fit under `totalAssets × tier2CallCapBps / 10,000`, or `propose` reverts `Tier2CallCapExceedsCeiling`. The CLI checks this before anything is signed (`GENERIC_CALL_TIER2_CEILING`). If it refuses, lower `--amount`, or have the vault owner raise the cap with `sherwood governor set-tier2-call-cap --vault <vault> --bps <n>`. That setter reverts while any proposal is open. Arena vaults need at least 8,000 bps.
- **Settlement counts only USDG.** At settle the clone pushes its whole USDG balance to the vault. Anything returned in another token, and anything left on the clone, is a realised loss in the proposal's P&L. Sell back to USDG in the settle leg, and list any token you expect to be left over in `sweepTokens`.
- **The only price floor is the envelope's.** `settleProposal` refuses a settle below the `--max-drawdown-bps` floor. Put venue-level minimums, such as a router's `amountOutMin`, in the calldata.

## Write the plan

The plan is a JSON file passed with `--calls`. `--amount` is the vault asset the clone pulls at execute, in human units (`250` = 250 USDG; `0` pulls nothing).

```json
{
  "executeCalls": [
    { "target": "$asset", "signature": "approve(address,uint256)", "args": ["0xRouter", "$pullAmount"] },
    {
      "target": "0xRouter",
      "signature": "swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut, address recipient)",
      "args": ["$asset", "0xToken", "$pullAmount", "247000000000000000000", "$clone"],
      "note": "buy the token with the whole pull"
    }
  ],
  "settleCalls": [
    { "target": "0xToken", "signature": "approve(address,uint256)", "args": ["0xRouter", "115792089237316195423570985008687907853269984665640564039457584007913129639935"] },
    {
      "target": "0xRouter",
      "signature": "swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut, address recipient)",
      "args": ["0xToken", "$asset", "0", "245000000", "$clone"],
      "note": "sell everything back to USDG"
    }
  ],
  "settlePatches": [{ "callIndex": 1, "argIndex": 2, "token": "0xToken" }],
  "sweepTokens": ["0xToken"]
}
```

- **A call** is `{ target, signature, args }`, which the CLI encodes, or `{ target, data }` with raw calldata. A raw call may also carry `signature`, and the CLI then refuses it unless the data decodes as that function. `note` is free text the CLI prints; it is not stored on chain. `value` must be 0 or absent.
- **Arguments.** Amounts are integers in raw base units, written as decimal strings (USDG has 6 decimals, most tokens 18). Arrays and tuples are JSON arrays or objects.
- **Placeholders**, for an address or amount argument, a target, a sweep token or a patch token:

  | Placeholder | Becomes |
  |---|---|
  | `$clone` | The clone's address. The CLI predicts it before the clone exists. |
  | `$vault` | The vault. |
  | `$asset` | The vault asset (USDG). |
  | `$pullAmount` | The pull, in raw base units. |

### Balance patches: "patch argument N of settle call K with my balance of token T"

Settle calldata is fixed when the clone is created, but at settle you rarely know how much of a token the clone holds. A balance patch overwrites one argument of one settle call with the clone's live balance of a token, just before that call runs. It counts what the earlier settle calls returned, and it can never write more than the clone holds.

- **By argument:** `{ "callIndex": 1, "argIndex": 2, "token": "0xToken" }` means "argument 2 of settle call 1 becomes my balance of 0xToken". The CLI turns the argument position into the word the contract patches. The call needs a `signature`, and the argument must be a top-level `uint` whose position does not depend on the data: every argument before it may be anything, but the patched argument itself cannot be `bytes`, `string`, an array or a struct.
- **By word:** `{ "callIndex": 1, "wordIndex": 5, "token": "0xToken" }` patches the 32-byte word at byte offset `4 + 32 × wordIndex` directly. Use it for an amount inside a struct or array, or for a raw call with no signature: count the word in the ABI encoding yourself. The CLI warns when a signature shows the word is not an amount.
- **Limits, checked by the contract and by the CLI:** one patch per settle call. The token must be the vault asset, a target of either leg, or a sweep token: list a receipt token the settle leg never calls (an aToken that `withdraw` burns) in `sweepTokens`. The spender word of `approve` and `setApprovalForAll`, the recipient word of `transfer`, and the `from` and `to` words of `transferFrom` and `safeTransferFrom` cannot be patched.
- **Without a patch:** use the venue's "max" sentinel (for example withdraw `type(uint256).max`), or make execute exact-output so the settle amounts are known.

## Propose

```bash
sherwood strategy propose generic-call \
  --vault 0x... --calls plan.json --amount 250 \
  --name "Buy and sell XYZ through Router" --description "..." --duration 3d

# External signer: emits the clone and propose txs unsigned
sherwood --calldata-only strategy propose generic-call \
  --vault 0x... --calls plan.json --amount 250 \
  --proposer 0x... --metadata-uri ipfs://... --duration 3d
```

Before anything is signed, the CLI:

1. reads the vault's asset and the protocol contracts the clone may never call (the vault, its governor, the SyndicateFactory, TierRegistry, StrategyFactory, GuardianRegistry, sWOOD, the withdrawal queue, the ExposureLedger and the ChallengeGame);
2. predicts the clone's address and binds `$clone`. The CREATE2 salt is derived from the plan with `$clone` set to the zero address, so a plan may name its own clone. Pass `--salt` to deploy the same plan again;
3. checks every rule `initialize` enforces (table below) and the tier-2 ceiling, and refuses the plan, naming each problem, if any fails;
4. prints the plan: the clone, every call, what each patch overwrites, and the `configHash` guardians compare;
5. deploys the clone through `StrategyFactory.cloneAndInitDeterministic`, then proposes with the standard batches:

| Leg | Calls | Caps |
|---|---|---|
| Execute | `[USDG.approve(clone, pullAmount), clone.execute()]` | `[0, pullAmount]` |
| Settle | `[clone.settle()]` | `[0]` |

`clone` deploys the clone without proposing: `sherwood strategy clone generic-call --vault 0x... --calls plan.json --amount 250`. `strategy init` does not support Generic Call.

### Rules checked before gas

| CLI code | Contract error | Rule |
|---|---|---|
| `GENERIC_CALL_VALUE_NONZERO` | `NativeValueUnsupported` | `value` must be 0 |
| `GENERIC_CALL_FORBIDDEN_TARGET` | `ForbiddenTarget` | No call to the zero address, the clone itself or a protocol contract. WOOD is allowed |
| `GENERIC_CALL_TARGET_NO_CODE` | `TargetHasNoCode` | Every target has code |
| `GENERIC_CALL_ASSET_SELECTOR` | `AssetCallNotAllowed` | On the vault asset, only `approve(address,uint256)` and `transfer(address,uint256)` |
| `GENERIC_CALL_TOO_MANY_CALLS` | `TooManyCalls` | At most 16 calls per leg |
| `GENERIC_CALL_CALLDATA_TOO_LARGE` | `CalldataTooLarge` | At most 16,384 bytes of calldata per leg |
| `GENERIC_CALL_TOO_MANY_SWEEP_TOKENS` | `TooManySweepTokens` | At most 16 sweep tokens |
| `GENERIC_CALL_SWEEP_TOKEN_INVALID` | `InvalidSweepToken` | A sweep token has code and is not a protocol contract |
| `GENERIC_CALL_PATCH_OUT_OF_RANGE`, `_DUPLICATE_PATCH`, `_PATCH_TOKEN_UNKNOWN`, `_PATCH_ADDRESS_WORD` | `InvalidPatch` | The patch limits above |
| `GENERIC_CALL_PROTOCOL_UNRESOLVED` | `ProtocolAddressUnresolved` | The vault's protocol contracts must all resolve |
| `GENERIC_CALL_TIER2_CEILING` | `Tier2CallCapExceedsCeiling` (at propose) | The pull fits under the vault's tier-2 per-call ceiling |

## Legs that work

- **Approvals are revoked after each leg** (`approve` and `setApprovalForAll` only). If the settle leg needs a venue approval, grant it in the settle leg.
- **Prefer venues that give the clone a token.** The vault owner's emergency path can recover what the clone holds. A position recorded only inside a venue (a lending balance keyed to the clone, an open order, a stake) comes home only through the settle leg; if that leg can never run, the position is lost.
- **Proxy upgrades are not caught.** Execute re-checks each target's code hash, but a proxy keeps its code hash when its implementation changes. Settle never checks code, so a change cannot wedge the return of capital.
- **ERC-721s** delivered with `safeTransferFrom` are accepted; the vault can pull one out with `rescueERC721To` in an emergency batch. ERC-1155s are refused.
- **Errors you may see:** `CallFailed(leg, index, reason)` (leg 0 is execute, 1 is settle; `reason` is the venue's revert data) and `TargetCodeChanged(target)` at execute.

## For guardians

The clone's calls are not batch calls, so `sherwood guardian review` (CLI 0.103.0 or later) is where a guardian reads them. It reads the clone's `executeCalls()`, `settleCalls()`, `settlePatches()`, `sweepTokens()` and `grants()`, decodes every call with the target's verified ABI, names the argument each patch overwrites, and checks every target, spender and address in the calldata like a batch call. An Approve carries `STRATEGY_GENERIC_CALL`. The codes are listed in the [guardian skill](../../guardian/SKILL.md).
