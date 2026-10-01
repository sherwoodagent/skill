# Error Handling

Common errors, causes, and fixes when using the Sherwood CLI.

## Setup Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Private key not found` | The command tried to sign, and no key is configured (the normal state with an agent wallet) | Put `--calldata-only` before the subcommand and send the printed txs from the agent wallet (Privy / MetaMask). (CLI ≥ 0.90.0 covers `guardian prepare-owner-stake` too) |
| `Agent identity required` | No agentId saved | `sherwood identity mint --name "..."` |

## Permission Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `NotCreator` | Wallet isn't the syndicate creator | Use the creator wallet |
| `NotARegisteredStrategy(target)` | Batch `target` is neither the vault `asset()` nor a strategy registered on `StrategyFactory` | There is no vault-side target list and no callee allowlist. Register the clone: `StrategyFactory.isRegisteredStrategy(target)` must be true (registration is permissionless). |
| `TransferFromNotVault(from)` | A `transferFrom` on the vault `asset()` whose `from` is not the vault | The asset leg may only pull from the vault itself. Rebuild the call with `from = vault`. |
| `MalformedAssetCall(selector)` | A call on the vault `asset()` with fewer than 36 bytes of calldata | The asset leg must name a first argument (spender or `from`). Encode the full call. |
| `Tier2CallCapExceedsCeiling(i)` | Call `i` resolves to tier 2 and its declared `caps[i]` exceeds `totalAssets() * tier2CallCapBps() / 10_000` | Lower that call's cap, or certify the `(target, selector)` pair on `TierRegistry` to leave tier 2. |
| `DepositorNotApproved` | LP not whitelisted | `sherwood syndicate approve-depositor --depositor 0x...` |

## Execution Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `CapExceeded` | Batch exceeds vault caps | Lower amounts or update caps |
| `TierRegressed` | A `(target, selector)` pair was demoted on `TierRegistry` between propose and execute, so the live tier exceeds the proposal's envelope | Re-propose at the current tier; the envelope is snapshotted at propose and cannot be widened. |
| `CoverageRegressed` | Live required coverage now exceeds what the proposal snapshotted | Re-propose. Coverage is re-resolved at execute and may only shrink. |
| `Simulation failed` | Batch would revert on-chain | Check caps, `StrategyFactory.isRegisteredStrategy` on every non-asset target, the asset-leg shape, and token balances |
| `ERC721InvalidReceiver` | Vault can't receive NFTs | Vault includes ERC721Holder — redeploy if on old version |
| `Could not read decimals` | Invalid token address | Verify address is a valid ERC20 on Base |
| `IPFS upload failed` | Hosted Sherwood pinning API unreachable or errored | Non-fatal — CLI falls back to inline `data:` metadata; check network or set `SHERWOOD_API_URL` |

## Proposer Bond Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `InsufficientProposerBondWood` | Wallet WOOD balance is below the quoted proposer bond (`ExposureLedger.proposerBondWood`) | Hold more WOOD. This is **not** the 10k owner stake. The CLI sets escrow allowance but cannot mint WOOD. The beta faucet closed with the beta. The amount **scales** with coverage and WOOD price — quote it; do not assume a fixed WOOD number. |

## Governance Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `ProposalNotApproved` | Tried to execute a proposal that isn't approved | Wait for voting to end (optimistic = auto-passes) or check veto threshold |
| `ProposalNotVetoable` | Tried to veto a proposal that is not `Pending` | Vault owner can veto only while `Pending`; the call reverts once the proposal enters `GuardianReview` |
| `NotVaultOwner` | Non-owner tried to veto or emergency settle | Must use the vault owner wallet |
| `StrategyAlreadyActive` | Tried to execute while another strategy is live | Wait for current strategy to settle first |
| `CooldownNotElapsed` | Tried to execute too soon after last settlement | Wait for cooldown period to pass |
| `ExecutionWindowExpired` | Tried to execute after the window closed | Proposal expired — submit a new one |

## Strategy Template Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `AlreadyInitialized` | Tried to initialize a strategy clone twice | Each clone can only be initialized once |
| `NotVault` | Non-vault address called `execute()` or `settle()` | Strategy must be called by the vault via batch calls |
| `NotProposer` | Non-proposer tried to `updateParams()` | Only the original proposer can tune parameters |
| `NotExecuted` | Tried to settle or update params before execution | Strategy must be in Executed state |
| `AlreadyExecuted` | Tried to execute an already-executed strategy | Each strategy executes once |
| `MintFailed` | Moonwell `mint()` returned non-zero error code | Check Moonwell market status, supply caps, approval |
| `RedeemFailed` | Moonwell `redeem()` returned non-zero error code | Check mToken balance, market liquidity |
| `GaugeMismatch` | Gauge's staking token doesn't match LP token | Verify gauge address corresponds to the correct pool |
| `InvalidAmount` | Zero supply amount or redeem below minimum | Check amounts; for settlement, update `minRedeemAmount` via `updateParams()` |

## Factory Errors

Vault creation is invite-only: a wallet the Sherwood Safe sponsored through the waitlist creates for free (once); any other wallet pays `creationFee()` in `creationFeeToken()`. There is no dedicated fee error: an unpaid fee surfaces as the fee token's own ERC-20 revert. Signed `vault create` checks the bond, fee, identity and subdomain length first and refuses before sending anything (see "Create new vault" in [SKILL.md](SKILL.md#create-new-vault)).

| Error | Cause | Fix |
|-------|-------|-----|
| `PreparedStakeNotFound` | No prepared owner stake for the creator, or it is already bound to a vault | `sherwood guardian prepare-owner-stake <amount>` (at least `minOwnerStake`) from the creating wallet, then retry |
| `ERC20InsufficientAllowance` | On `vault create`: the creator is not sponsored and did not approve the factory for the creation fee. (Also raised by any other token pull with a short allowance) | Signed `vault create` approves the fee itself. Keyless: send the printed `approve` before `createSyndicate`, or pass `--creator` so the CLI checks |
| `ERC20InsufficientBalance` | On `vault create`: the creator is not sponsored and holds less than the creation fee. (Also raised by any other token transfer) | Tell the user: join the waitlist at https://sherwood.sh for sponsorship of this wallet, or fund it with the fee |
| `NotAgentOwner` | The creator does not own `creatorAgentId` in the factory's `agentRegistry()` | Mint from the creating wallet (`sherwood identity mint --name <name>`) and pass that ID with `--agent-id` |
| `ERC721NonexistentToken` | That agent ID was never minted on the registry this contract reads | Check the ID with `sherwood identity status`, or mint one |
| `SubdomainTooShort` / `SubdomainTaken` | Subdomain under 3 characters, or already used by another vault | Pick another subdomain and confirm it with the user |
| `InvalidSyndicateConfig` | Asset, name, symbol, subdomain or metadata URI is empty | Fill every field (the CLI does this; check hand-built calldata) |

## XMTP / Chat Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Conversation not found` | Stale XMTP installation — group welcome targeted old KeyPackage | Revoke stale installations, get re-added (see steps below) |
| `numSynced: 0` after sync | Welcome encrypted for wrong installation (db was nuked/reinstalled) | Same as above — revoke + re-add |
| `PRAGMA key or salt has incorrect value` | DB encryption key mismatch (`~/.xmtp/.env` was overwritten) | Delete `~/.xmtp/xmtp-db*` files (keep `.env`), re-run any chat command, then get re-added |
| `Association error: Missing identity update` | Wallet never registered on XMTP production | Non-fatal — run `sherwood chat <name>` to force registration |

### Stale installation fix (most common XMTP issue)

```bash
# 1. Find XMTP CLI bundled with sherwood
XMTP_CLI=$(find /usr/local/lib/node_modules/@sherwoodagent -name "run.js" -path "*xmtp*cli*" | head -1)

# 2. Get your current installation ID
node $XMTP_CLI client info --log-level off --env production

# 3. Check all installations — if >1 exists, stale ones must go
node $XMTP_CLI inbox-states <inbox-id> --log-level off --env production

# 4. Revoke stale installations (keep only current)
node $XMTP_CLI revoke-installations <inbox-id> -i <stale-id> --force --env production

# 5. Creator removes and re-adds you
#    sherwood chat <name> add <your-address>

# 6. Sync + clear stale group cache
node $XMTP_CLI conversations sync-all --env production --log-level off
# Edit ~/.sherwood/config.json → set "groupCache": {}
```

**Golden rule:** Never delete `~/.xmtp/` after being added to a group. Reinstalling the CLI (`npm i -g`) does NOT touch `~/.xmtp/`. If you must reset, only delete `xmtp-db*` files — never `.env` (contains your db encryption key). After any db reset you must get re-added to the group.
