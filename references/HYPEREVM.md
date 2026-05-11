# HyperEVM ↔ HyperCore Reference

When moving funds, deploying strategy clones, or debugging Hyperliquid integrations, this is the canonical reference. Grep here first when an EVM→spot transfer or `sendSpotSend` reverts.

## The four capital locations

Capital on Hyperliquid lives in one of four distinct places. Each pair of locations bridges via a specific mechanism.

| Location | Holds | Bridges to |
|---|---|---|
| HyperEVM ERC-20 | USDC, USDH, HYPE, … | HC spot (aligned tokens only) |
| HyperCore spot | USDH, USDC0, HYPE, outcome contracts | HyperEVM (aligned only); HC perp; other spot accounts |
| HyperCore perp | margin USDC0 | HC spot via `sendUsdClassTransfer` |
| Arbitrum L1 | canonical USDC | HC spot via [app.hyperliquid.xyz/bridge2](https://app.hyperliquid.xyz/bridge2) |

`L1Read.spotBalance(user, tokenIndex)` reads spot balances on-chain. The HL info API (`POST /info {"type":"spotClearinghouseState","user":...}`) is the off-chain mirror.

## Aligned vs non-aligned tokens

The HL system mints/burns matching HC spot balance when an **aligned** ERC-20 is sent to its **system address**:

```
sysAddr(tokenIndex) = 0x2000000000000000000000000000000000000000 + tokenIndex
```

| Token | HC index | EVM contract | System address | Aligned? |
|---|---|---|---|---|
| USDH | 360 | `0x111111a1a0667d36bd57c0a9f569b98057111111` | `0x2000…0168` | yes |
| HYPE | 150 (verify) | (verify on-chain) | `0x2000…0096` | yes |
| USDC (bridged Circle) | — | `0xb88339CB7199b77E23DB6E890353E22632Ba630f` | — | **NO** (Circle blacklist) |
| USDC0 (HC-native) | 0 | — (HC-only) | `0x2000…0000` | n/a (lives on spot) |

**Sending a non-aligned ERC-20 to its system address reverts.** The bridged Circle USDC on HyperEVM has Circle's blacklist on the `0x2000…0000` sentinel, so `USDC.transfer(0x2000…0000, …)` always fails. The only path from HyperEVM USDC to HC spot is via swap-then-bridge (next section).

To re-verify a token's HC index live: `curl -X POST https://api.hyperliquid.xyz/info -H 'content-type: application/json' -d '{"type":"spotMeta"}' | jq '.tokens[]|select(.name=="USDH")'`.

## Routing: get USDC to HC spot

| Source | Route | Steps |
|---|---|---|
| HyperEVM USDC | swap-then-bridge | `USDC → USDH` on HyperSwap V3, then `USDH.transfer(0x2000…0168, amt)` |
| Arbitrum L1 USDC | canonical (free) | [app.hyperliquid.xyz/bridge2](https://app.hyperliquid.xyz/bridge2), manual UI |
| HC spot (already there) | none | confirm via `spotClearinghouseState` |

Cost of swap-then-bridge: ~5–10 bps + L1 gas. Slippage clamp: 0.5%.

## Routing: get USDH or HYPE to HC spot

| Source | Route | Steps |
|---|---|---|
| HyperEVM USDH | direct | `USDH.transfer(0x2000…0168, amt)` |
| HyperEVM HYPE | direct | `HYPE.transfer(0x2000…0096, amt)` (verify token index) |
| HC spot (already there) | none | done |

## Routing: spot → EVM (withdraw)

| Asset | Steps |
|---|---|
| USDH | from HL UI, or `CoreWriter.sendSpotSend(0x2000…0168, 360, amt)` from a contract that holds spot |
| USDC0 | from HL UI to Arbitrum (canonical), or swap on HC spot pair 230 → USDH → withdraw |
| Outcome contract | settle the strategy first (HL auto-resolves at expiry); proceeds land as USDH on spot |

`sendSpotSend` is in `contracts/src/hyperliquid/L1Write.sol`. Calls take effect at the next HC block (usually <1s).

## Strategy clone gotchas

These traps blocked the HIP-4 beta cycle on 2026-05-08 and 2026-05-10 (proposals #8, #10, #11). Burn them into long-term memory.

### 0. **`finalizeForHyperCore` only works for aligned tokens** — DO NOT use it as a USDC bridge

> ⚠️ **LIVE-CONFIRMED 2026-05-10 on proposal #11.** This is the most expensive misconception caught so far. Read this before adding `finalizeForHyperCore` to any new code path.
>
> ✅ **Gate landed in this PR (S-C7 option A).** `HyperliquidOutcomeStrategy._initialize` now reverts with `UsdcVaultModeUnsupported` when `swapPairAssetId != 0`. Operators on USDC must bridge USDC→USDH off-chain (HyperSwap UI) before depositing. The USDH-vault path is soak-tested end-to-end on a mainnet fork by `HyperliquidOutcomeForkTest::test_fullLifecycle_usdhMode_executesAndSettlesCleanly`. Option B (in-strategy HyperSwap V3 swap) deferred to V1.5.

`finalizeForHyperCore(token, FinalizeVariant.Create, deployerNonce)` registers an EVM contract address with HC's auto-mirror system. **It only mirrors tokens that have an HC mapping** — the aligned set: USDH, HYPE, USDC0 (HC-native), and other HL-recognized tokens.

The bridged Circle USDC on HyperEVM at `0xb88339CB7199b77E23DB6E890353E22632Ba630f` is **non-aligned** — it has no HC counterpart, no HC token index, no auto-credit path. Calling `finalizeForHyperCore(0, Create, nonce)` on a clone holding bridged USDC is a **no-op for the bridging purpose**: the storage flag `hyperCoreFinalized` flips to `true` and the RawAction emits, but **HC will never auto-credit bridged USDC to the clone's spot wallet** because token 0 (USDC0) ≠ bridged Circle USDC.

**Symptom (live-observed):**
- `cast call clone "hyperCoreFinalized()(bool)" → true` ✓ (looks healthy)
- `clone.balanceOf(USDC) on EVM = 5_000_000` (full deposit, untouched after execute)
- `spotClearinghouseState{user: clone}.balances = []` (empty)
- `coreUserExists(clone) = 0` (this looks like the cause, but it's actually downstream of "no auto-credit path → no mirror tx → no HC user creation")
- IOC swap-in fired via CoreWriter, spent 0/0 USDC (no spot funds → no fill, silent no-op)
- 5 USDC stranded on clone EVM until `_settle()` sweeps it back

**The fix that DOESN'T work:**
- Adding `finalizeForHyperCore` to the strategy. Done in commit `5c7d2f8`. Doesn't help because the underlying token is non-aligned.

**The fixes that work:**
1. **Use USDH as the vault asset** (cleanest). USDH is aligned → `finalizeForHyperCore(360, …)` actually mirrors → auto-credit fires → IOC outcome buy works. Operator must pre-convert any USDC to USDH on EVM (HyperSwap UI). Sherwood's CLI already supports this via `--token USDH` (skips the swap-in leg in `_execute`).
2. **Add an EVM-side `USDC → USDH` swap inside `_execute()`** via HyperSwap V3 router, then USDH auto-credits (since it's aligned). Contract change, ~30-50 lines.
3. **Operator pre-funds the clone's spot manually** with USDH before execute. Doesn't scale.

### 1. Clone must call `finalizeForHyperCore` before holding spot (aligned tokens only)

Before a strategy clone address can hold any HC spot balance **of an aligned token**, the proposer calls:

```solidity
clone.finalizeForHyperCore(360, FinalizeVariant.Create, deployerNonce);  // 360 = USDH
```

`deployerNonce` is the deployer EOA's nonce **at the moment the clone was created** via the `CREATE` opcode — recoverable from the deploy tx receipt.

The Sherwood CLI's `strategy propose hyperliquid-*` paths auto-call this immediately after the `clone` step (`cli/src/commands/strategy-template.ts`). Manual deployments must do it explicitly. **The CLI currently passes `token=0` (USDC0) — this is correct only when the strategy will actually receive USDC0 on its spot, which only happens for USDH-vault mode after an HC-side swap on pair 230.** For USDC-vault mode (bridged Circle USDC) the CLI's auto-call doesn't help; see §0.

**Symptom if skipped (for an aligned token):** the clone's `L1Read.spotBalance(clone, alignedTokenIdx)` reads as 0 forever even after a successful EVM→spot transfer to the clone, and `sendSpotSend` from the clone reverts.

### 2. HC user existence (warm-up requirement)

A never-touched EOA — or a fresh strategy clone — may need a one-time small transfer to bootstrap its HC account.

**Symptom:** first `sendSpotSend` from the address reverts with `CoreUserExistsPrecompileCallFailed`, or silent no-op (the call enters the HC mempool but never lands). `coreUserExists(addr)` returns `0`.

**Important nuance — `coreUserExists = 0` is a symptom, not always the root cause.** When you observe it on a strategy clone that's been finalized, check first whether the underlying token is aligned (§0). If the token is non-aligned, the clone's HC user account never gets created because no incoming transfer ever lands. Fixing the user-existence symptom (e.g. by sending a dust spotSend from a warmed wallet) won't help unless the token alignment problem is also solved.

**Fix (when the token IS aligned):** bridge ≥0.01 USDH from a warmed-up wallet first to seed the account. Subsequent transfers from the warmed wallet succeed.

`L1Read.coreUserExists(user)` (`contracts/src/hyperliquid/L1Read.sol::coreUserExists`) reads the existence flag if you need to gate a contract on it.

### 3. EVM→spot bridges are async

EVM→spot bridge transfers settle on HC after the next few HC blocks (~1–3s in practice, but no guarantee). Don't submit orders that depend on the deposited balance until you've polled `L1Read.spotBalance` and confirmed the deposit landed.

**Polling timeout heuristic:** after 60s of zero balance, stop assuming async lag — you've probably hit §0 (non-aligned token) or §2 (no HC user). 2026-05-10 proposal #11 confirmed: when auto-credit can't fire, no amount of waiting helps.

## Spot pair 230 (USDH/USDC) — internal swap reference

> ⚠️ **As of 2026-05-10, USDC-vault mode for `HyperliquidOutcomeStrategy` is gated off** (see §0) — `_initialize` reverts with `UsdcVaultModeUnsupported` if `swapPairAssetId != 0`. Use USDH-vault mode (`--token USDH`, `swapPairAssetId = 0`). The on-HC pair-230 swap leg remains in the contract for the day option B (EVM-side HyperSwap V3 leg) ships and unlocks it, but is currently unreachable.

Used by `HyperliquidOutcomeStrategy` and `HyperliquidGridStrategy` when the vault asset is USDC and the strategy needs to round-trip into USDH for HIP-4 outcome trades.

| Field | Value |
|---|---|
| Asset ID | 10230 |
| Base | USDH (`szDecimals=2` → `pxDecimals=6`) |
| Quote | USDC0 (HC-native) |
| Daily volume | $8M+ |
| Spread | ~0.5 bps mid |

Encoding: `limitPx = price × 10^6`. e.g. 1.003 USDC per USDH → `limitPx = 1_003_000`.

Strategy template constant: `SWAP_PAIR_USDH_USDC = 10_230` in `cli/src/strategies/hyperliquid-outcome-template.ts`.

## Code references

| Need | Where |
|---|---|
| HyperEVM USDH address constant | `cli/src/lib/addresses.ts` (`HYPEREVM_TOKENS.USDH`) |
| `L1Read.spotBalance` | `contracts/src/hyperliquid/L1Read.sol` |
| `L1Read.coreUserExists` | `contracts/src/hyperliquid/L1Read.sol` |
| `L1Write.sendSpotSend` | `contracts/src/hyperliquid/L1Write.sol` |
| `finalizeForHyperCore` (outcome) | `contracts/src/strategies/HyperliquidOutcomeStrategy.sol` |
| `finalizeForHyperCore` (grid) | `contracts/src/strategies/HyperliquidGridStrategy.sol` |
| Auto-finalize after clone (CLI) | `cli/src/commands/strategy-template.ts` |
| HL info API client | `cli/src/providers/data/hyperliquid.ts` |
| HIP-4 design spec | `docs/superpowers/specs/2026-05-02-hyperliquid-hip4-integration-design.md` |

## Manual recovery — get USDC on EVM to HC spot today

There is no `sherwood bridge` subcommand. The route is rare enough and the manual path is short enough that it lives here as a five-step playbook instead.

```bash
# 1. Read EVM USDC balance.
cast call 0xb88339CB7199b77E23DB6E890353E22632Ba630f \
  "balanceOf(address)(uint256)" \
  $WALLET --rpc-url $HYPEREVM_RPC_URL

# 2. Open https://app.hyperswap.exchange/, connect wallet, swap USDC → USDH at 0.5% slippage.

# 3. Bridge USDH to spot. (1_000_000 = 1 USDH at 6 decimals.)
cast send 0x111111a1a0667d36bd57c0a9f569b98057111111 \
  "transfer(address,uint256)" \
  0x2000000000000000000000000000000000000168 1000000 \
  --rpc-url $HYPEREVM_RPC_URL --private-key $PK

# 4. Poll until USDH appears on spot.
curl -s -X POST https://api.hyperliquid.xyz/info \
  -H 'content-type: application/json' \
  -d "{\"type\":\"spotClearinghouseState\",\"user\":\"$WALLET\"}" \
  | jq '.balances[] | select(.coin=="USDH")'

# 5. (Optional) Swap USDH → USDC0 on HC spot pair 230 if the strategy expects USDC0.
#    Use HL UI or `sherwood strategy propose hyperliquid-outcome … --token USDC` (the
#    template builds the swap leg automatically when --token=USDC).
```

If running a strategy clone, you also need to fund the **clone's** spot wallet (not just the operator EOA). After step 4, send some USDH from your operator spot to the clone's address with `sendSpotSend`. The clone must have already called `finalizeForHyperCore` (gotcha #1 above) before this works.

## References

- HIP-4 spec: <https://hip.hyperliquid.xyz/HIP-4>
- HyperSwap docs: <https://docs.hyperswap.exchange/>
- HL info API: <https://api.hyperliquid.xyz/info>
- HL bridge UI (Arbitrum): <https://app.hyperliquid.xyz/bridge2>
- Project design spec: `docs/superpowers/specs/2026-05-02-hyperliquid-hip4-integration-design.md`
