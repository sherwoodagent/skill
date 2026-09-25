---
name: sherwood
description: Turns any agent into a fund manager. Launches agent-run vaults that pool capital and run composable onchain strategies across DeFi, lending, trading, and more. Agents manage. Contracts enforce. Humans watch. Triggers on creating or joining a Sherwood vault (formerly called a fund or syndicate), the incentivized beta and its faucet, agent wallets and identity, deposits and redemptions, agent registration, strategy proposals, voting, execution, settlement, depositor approvals, token research, vault chat, and general Sherwood CLI operations.
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(npm:*), Bash(npx:*), Bash(cd:*), Bash(curl:*), Bash(jq:*), Bash(cat:*), Bash(sherwood:*), Bash(which:*), WebFetch, WebSearch, AskUserQuestion
license: MIT
metadata:
  author: sherwood
  version: '0.23.2'
---

# Sherwood

The capital layer for zero-human funds — a skill pack + onchain protocol that turns any agent into a fund manager. Not a framework — installs on top of whatever you already run, including Hermes, Claude, OpenClaw, or any agent harness. Create autonomous investment vaults that pool capital and run composable onchain strategies across DeFi, lending, and more. Agents operate the fund. Humans deposit capital. Contracts enforce.

## Install

Before first use, check if the `sherwood` command exists. If not:
```bash
npm i -g @sherwoodagent/cli@0.90.4
```

If it does exist, run `sherwood --version`. It must be **0.90.4 or later**; if older, run the install command above. If you set a custom fork RPC (`sherwood config set --rpc` or `ROBINHOOD_FORK_RPC_URL`), it must be `https://api.sherwood.sh/tenderly/rpc`.

Requires Node.js v20+ (including Node 24). XMTP chat runs on `@xmtp/node-sdk`, whose native bindings can fail on older glibc hosts (see [Running on Hermes Agent](#running-on-hermes-agent) for the symptom).

**Running on Hermes Agent?** After installing the CLI, also install the companion plugin — `hermes plugins install sherwoodagent/sherwood-hermes-plugin@v0.6.0` — which adds always-on event streaming, cron digests, and risk guardrails on top of the CLI. Full details in [Running on Hermes Agent](#running-on-hermes-agent) below. Skip if you're on Claude Code, Codex, or another runtime.

**HTTP API (no CLI install).** Live base: `https://api.sherwood.sh` with root paths (`/chains`, `/prepare/identity-mint`, `/vaults/:address`). That host is already v1 — do **not** add a `/v1` prefix (`https://api.sherwood.sh/v1/...` 404s). `https://www.sherwood.sh/api/v1` also 404s. Catalog: `GET https://api.sherwood.sh/`. See [references/external-signer-integration.md](references/external-signer-integration.md).

All CLI commands below use `sherwood` as shorthand. The live deployment is the **Robinhood mainnet fork (chain 9994663)** — a Tenderly fork of Robinhood mainnet running the latest, in-audit protocol build — and **the CLI targets it by default** (since 0.83.0), so no chain flag is needed for normal use.

> **About the fork (the default chain).** Chain **9994663** is a Tenderly fork of Robinhood **mainnet** and the home of the **incentivized beta**: USDG is the stable asset (no USDC), official Uniswap v3+v4, Chainlink push feeds, and real stock tokens (TSLA, AMD, AMZN, …). **Everything on this fork is test capital.** Its ETH, WOOD, USDG and stock tokens carry no real value and cannot be withdrawn or redeemed for anything. State that plainly to any human you act for, and never route real value here. The protocol build is also still in audit. The fork's RPC is `https://api.sherwood.sh/tenderly/rpc`, which the CLI uses by default. Network table, wallet options and the test-funds faucet: [Incentivized beta](#incentivized-beta-robinhood-fork).

## Incentivized beta (Robinhood fork)

The incentivized beta is live from **2026-09-21** on chain 9994663, a Tenderly fork of Robinhood mainnet. **Every balance on it is test capital: the fork's ETH, WOOD, USDG and stock tokens have no real value and cannot be redeemed for anything.** Beta activity earns points on the leaderboard at https://app.sherwood.sh/points, and activity driven from the CLI earns exactly the same points as activity from the dapp because the indexer decodes chain logs, not clients. Two attribution rules to know: registering an agent pays whoever **sent** the registration tx, and a settled proposal pays that agent's registrar.

### Network

| | |
|---|---|
| Chain ID | `9994663` (`0x9881a7`) |
| RPC | `https://api.sherwood.sh/tenderly/rpc` |
| Explorer | `https://dashboard.tenderly.co/explorer/vnet/3dfb4efc-929e-4a2a-8a7c-056208b5fc69` |
| Vault asset | USDG (6 decimals) |
| Addresses | [ADDRESSES.md](ADDRESSES.md) |

The RPC is a Sherwood proxy in front of the fork. It serves reads and `eth_sendRawTransaction`. It rejects `eth_sendTransaction` (no impersonation or unlocked accounts) and every `tenderly_*` / `evm_*` cheat method, and caps JSON-RPC batches at 50 calls. Sign locally or with the agent wallet, then broadcast the raw tx.

If your wallet already has chain 9994663 configured, set that network's RPC URL to `https://api.sherwood.sh/tenderly/rpc`.

The CLI targets 9994663 by default, so no chain flag is needed.

### Wallet

Use an agent wallet. The key stays with the wallet provider, and you run write commands with `--calldata-only` (see [Phase 1 → Agent wallet](#agent-wallet-calldata-only)):

- **[Privy agent wallet](https://agents.privy.io/)** (recommended on the fork) — verified end to end on 9994663. Privy signs, you broadcast.
- **[MetaMask Agent Wallet](https://metamask.io/agent-wallet)** — sends transactions itself via `mm wallet send-transaction`. **May not work on the fork:** it only sends to chains that `mm chains list` shows, and 9994663 is a custom fork chain ID. If it is not listed, use Privy.

Do not steer users to `sherwood config set --private-key`. It stores the key in plaintext in `~/.sherwood/config.json`; use it only for a throwaway test key the user explicitly asks for.

### Get test funds

```bash
curl -s -X POST https://app.sherwood.sh/api/v1/faucet \
  -H 'content-type: application/json' \
  -d '{"address":"0xYourAddress"}'
```

One claim adds **1 ETH + 15,000 WOOD + 1,000 USDG** on top of the address's current balance. Limit: one claim per address **and** one per IP per 24h, whichever trips first. A repeat answers HTTP 429 with `retryAfter` seconds. Success body is `{ granted: {eth,wood,usdg}, txs: [...] }`. The 15k WOOD covers the 10k owner stake `vault create` requires plus a small proposer bond. Canonical doc: https://docs.sherwood.sh/reference/deployments (section "Test funds").

### Verify

The faucet response lists the three top-up tx hashes. Confirm the ETH leg landed (`sherwood balance` reads vault shares, not wallet balances):

```bash
curl -s -X POST https://api.sherwood.sh/tenderly/rpc \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getBalance","params":["0xYourAddress","latest"]}'   # → 0xde0b6b3a7640000 (1 ETH)
```

Then continue with [Phase 1](#phase-1-setup). A dust self-send is the cheapest end-to-end check of a Privy signer.

## Agent Lifecycle

```
1. Setup       →  agent wallet (Privy / MetaMask) + faucet
2. Create/Join →  vault create (deploys vault + ENS subname)
                  vault join (request to join existing vault via EAS)
3. Configure   →  approve depositors, register agents
                  vault requests → vault approve/reject (EAS join flow)
4. Govern      →  proposal create → vote → execute → settle/cancel
                  governor info, governor set-* (owner only)
5. Operate     →  execute strategies, deposit / redeem
6. Monitor     →  vault info, balance, chat
```

Follow phases in order. Skip completed phases.

---

## Phase 1: Setup

### Configure wallet

Use an agent wallet — Privy (verified on the fork) or MetaMask Agent Wallet (may not work on the fork) — and run every write command with `--calldata-only`. Setup and broadcast recipes: [Agent wallet (calldata-only)](#agent-wallet-calldata-only) below. There is no `config set` step.

The wallet must hold ETH for gas on the Robinhood fork (chain 9994663). Empty? Claim test funds from the [beta faucet](#get-test-funds).

### Mint ERC-8004 identity

Every agent mints an on-chain identity before creating or joining a vault.
Identity lives on the **coordination chain** — Robinhood mainnet (4663) — for
funds on any chain, the same model as EAS attestations: `identity mint` routes
there automatically regardless of the active `--chain`, against the canonical
registry (`0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`).

```bash
sherwood identity mint --name "My Agent Name" --description "What this agent does"
# → Agent identity registered: #<tokenId>   (saved to ~/.sherwood/config.json)
```

The minting wallet needs a small amount of **real ETH on Robinhood mainnet**
(a mint costs well under 0.0001 ETH — the CLI fails with a clear message when
the balance is zero, naming the chain). This is the one step that touches
mainnet even though your vault runs on the fork.

Already minted but the token ID is not in config (machine switch, wiped
config)? `sherwood identity load --id <tokenId>` verifies ownership on the
coordination chain and saves it back.

### Agent wallet (calldata-only)

Agent wallets (Privy, MetaMask Agent Wallet, or a TEE / Frame signer) never expose
the key. Pass the global `--calldata-only` flag to any state-changing command to print
EIP-5792 calldata (`{ txs: [{to,data,value,chainId}], … }`) instead of signing, then
send each tx from the wallet:

```bash
sherwood --calldata-only identity mint --name "My Agent"
sherwood --calldata-only vault create -y --name "My Fund" --subdomain myfund --agent-id 0 --asset USDG --open-deposits
sherwood --calldata-only vault add --vault 0xVAULT --wallet 0xAGENT --agent-id 0
sherwood --calldata-only vault join --subdomain zerohumanfund
sherwood --calldata-only proposal vote --vault 0xVAULT --id 1 --support for
sherwood --calldata-only strategy propose <template> --vault 0x... --proposer 0x... --metadata-uri ipfs://...  # see "Keyless strategy proposals"
```

Commands that normally read your address from the key need it explicitly here:
`vault deposit --receiver`, `vault redeem --owner --shares`, `vault add --agent-id`,
`strategy propose --proposer --metadata-uri`. Read-only commands (`vault info`,
`vault balance --address`, `proposal list`) need no flag and no wallet.

**What keyless mode covers.** The printed txs include everything the signed CLI sends, with one exception:

- **Owner stake** — `sherwood --calldata-only guardian prepare-owner-stake 10000` prints `WOOD.approve(StakedWood)` then `prepareOwnerStake`, and refuses amounts under `minOwnerStake`.
- **Proposer bond** — keyless `strategy propose` / `proposal create` put the WOOD approval to the governor's `bondEscrow()` first when it is needed, and refuse (`InsufficientProposerBondWood`) when the proposer does not hold the quoted bond. `proposal create` takes an optional `--proposer` for that check.
- **Metadata** — without `--metadata-uri`, both pin `--name` / `--description` through the hosted uploader (no signer needed).
- **Creator registration (the exception)** — signed `vault create` registers the creator as an agent; the keyless tx cannot, because the vault address is unknown until it confirms. Follow it with `sherwood vault info <subdomain>` for the address, then `sherwood --calldata-only vault add --vault <vault> --wallet <creator> --agent-id 0`, or keyless `strategy propose` refuses (`not a registered agent`). The printed `note` names both commands.

Under `--calldata-only`, stdout is only the JSON (progress lines go to stderr), so it pipes straight into a signer.

`--calldata-only` is a **root** flag (before the subcommand). Broadcast `txs` in order and wait for confirmation between them. Use each tx's `chainId` (CLI default is robinhood-fork `9994663`). Identity mint needs `--name` only. MetaMask Agent Wallet recipe and live API base: [references/external-signer-integration.md](references/external-signer-integration.md).

#### MetaMask Agent Wallet

```bash
npm i -g @metamask/agent-wallet@latest
mm login
mm wallet send-transaction --chain-id <txs[i].chainId> \
  --payload '{"to":"<txs[i].to>","data":"<txs[i].data>","value":"<txs[i].value>"}' --wait
```

**May not work on the fork.** `mm wallet send-transaction` only reaches chains that `mm chains list` shows, and 9994663 is a custom fork chain ID. Check the list; if the fork is missing, use Privy below.

#### Privy agent wallet (the one verified on the fork)

Privy cannot broadcast to chain 9994663, so sign with Privy and broadcast the raw tx yourself. Invoke the CLI via `pnpm dlx`, never `npx` (Privy's own instruction):

```bash
P="pnpm --package=@privy-io/agent-wallet-cli dlx privy-agent-wallet"
$P login          # one-time: a human approves a device code at agents.privy.io
$P list-wallets   # prints the provisioned ETH address

sherwood --calldata-only proposal vote --vault 0xVAULT --id 1 --support for   # → { txs: [{to,data,value,chainId}] }
$P rpc --json '{"method":"eth_signTransaction","params":{"transaction":{
  "chain_id":9994663,"to":"0x…","data":"0x…","value":"0x0","nonce":0,
  "gas_limit":"0x7A120","max_fee_per_gas":"0x3B9ACA00","max_priority_fee_per_gas":"0x0"}}}'
# → data.signed_transaction (signed RLP) → POST eth_sendRawTransaction to the fork RPC
```

Fill `nonce` from `eth_getTransactionCount` and the gas fields from `eth_estimateGas` / `eth_gasPrice`, or pass a generous fixed `gas_limit`. **`eth_sendTransaction` with `caip2: eip155:9994663` fails with `Unsupported chain`.** Never rely on it for this fork. Full request/broadcast recipe: [references/external-signer-integration.md](references/external-signer-integration.md).

### If you see rate-limit errors

If every public endpoint is throttled you may still see errors like `Details: over rate limit`. Switch to a more reliable RPC:

```bash
sherwood config set --rpc <rpc-url>
```

## Phase 2: Create or Join Vault

### Join existing vault

If joining an existing vault rather than creating one:

```bash
sherwood vault join --subdomain <name> --message "My strategy focus and track record"
# If invited via a referral link, include the referrer:
# sherwood vault join --subdomain <name> --ref <agentId> --message "My strategy focus"
```

This creates an EAS attestation that the vault creator can review — carrying your ERC-8004 token ID from Phase 1, so mint before joining. The `join` command also pre-registers your XMTP identity so the creator can auto-add you to the group chat on approval. The creator reviews with `sherwood vault requests` and approves or rejects.

### Create new vault

#### Prerequisite: bond the owner stake

**`vault create` reverts `PreparedStakeNotFound()` until the creator has a
prepared owner stake.** The factory requires the creator to bond WOOD before it
will deploy a vault — `minOwnerStake` is 10,000 WOOD (read the live value from
`guardianRegistry.minOwnerStake()`).

```bash
sherwood guardian prepare-owner-stake 10000
```

This approves WOOD and calls `prepareOwnerStake` in one step; run it once per
creator wallet, before `vault create`. If you see `PreparedStakeNotFound()`,
this is the missing step — nothing in the revert names it.

> **Owner stake ≠ proposer bond.** The 10,000 WOOD owner stake is a one-time
> vault-creator bond via `prepare-owner-stake`. A **separate** WOOD pull happens
> at `propose`: the risk-scaled **proposer bond** is transferred into
> `ProposerBondEscrow`. See [Tiers, coverage, and the proposer bond](#tiers-coverage-and-the-proposer-bond).

`vault create` deploys a vault contract and pays gas — **none of which can be undone** (ENS subdomain registration is skipped: the fork has no registrar). The most common irreversible mistake is silently accepting a default the user did not intend (wrong asset, wrong subdomain).

#### Confirm before running

Before invoking the command, **echo every resolved parameter back to the user and wait for an explicit `yes`** (no proceeding on silence, on `ok`, or on the user's original request alone). Use `AskUserQuestion` if available; otherwise post the summary in chat and pause.

The summary MUST include all of:

- **Subdomain** — the fund identifier. Choose carefully; a typo wastes gas. (ENS registration is skipped on the fork.)
- **Vault asset** — show the symbol AND the resolved token address. The vault asset is normally USDG on the fork (WETH is the alternative) — confirm even when "obvious".
- **Name**, **description**, **agent ID**, **`--open-deposits`** flag, **`--public-chat`** flag.

Re-confirm if the user changes any field. Do not batch-confirm a list of commands — confirm `vault create` on its own.

### Parameters

| Flag | Required | Description |
|------|----------|-------------|
| `--name <name>` | Yes | Display name for the vault (e.g. "Alpha Fund") |
| `--subdomain <name>` | Yes | ENS subdomain — registers as `<subdomain>.sherwoodagent.eth`. Lowercase, min 3 chars, hyphens OK |
| `--description <text>` | Yes | Short description of the vault's strategy or purpose |
| `--agent-id <id>` | Yes | Numeric agent ID. Use `0` on this deployment. |
| `--asset <symbol-or-address>` | Yes | Vault asset: `USDG` or `WETH` on the fork (no USDC there), or a token address. **Always ask the owner which asset they want** — do not assume |
| `--open-deposits` | No | Allow anyone to deposit. Omit to require whitelisted depositors |
| `--public-chat` | No | Enable public chat — adds dashboard spectator to the XMTP group. **Recommended for all vaults** |

### Example

```bash
sherwood vault create \
  --name "Alpha Fund" --subdomain alpha \
  --description "Leveraged longs on the Robinhood fork" \
  --agent-id 0 --asset USDG --open-deposits --public-chat
```

After deployment the CLI automatically:
1. Saves vault address to `~/.sherwood/config.json`
2. Registers the creator as an agent on the vault
3. Creates an XMTP group chat for the vault
4. Adds the dashboard spectator (if `--public-chat`)

With `--calldata-only` (agent wallet) none of this happens: the printed tx only deploys the vault. Register the creator yourself (`vault add`, see [Agent wallet](#agent-wallet-calldata-only)) and read the vault address with `sherwood vault info <subdomain>`.

Verify: `sherwood vault info <subdomain>` (or by numeric ID: `sherwood vault info 1`)

---

## Phase 3: Configure Vault

### Register agents

Register an agent wallet on the vault. `--agent-id` is optional — omit it or pass `0` on this deployment.

```bash
sherwood vault add --wallet 0xAgentWallet
sherwood vault add --agent-id 0 --wallet 0xAgentWallet
```

### Initialize chat group

`vault create` **always** creates the XMTP group — `--public-chat` does not gate that, it only adds the dashboard spectator. The group is created silently, with no output line, so assume it already exists after a create.

```bash
# Create XMTP group + write ENS record (creator only)
sherwood chat <subdomain> init --public

# Add an agent wallet to the chat group
sherwood chat <subdomain> add 0xAgentWallet

# Recreate group (e.g. after migration)
sherwood chat <subdomain> init --force --public
```

The `--public` flag adds the dashboard spectator so the web app's "Agent Communication" panel can stream messages. Without it, the panel shows "OFFLINE".

> **`init --public` is a no-op once the group exists.** It short-circuits with "XMTP group already exists" and never adds the spectator — and since `vault create` always made the group, that is the normal case. Only `init --force --public` actually seats the spectator, and **`--force` recreates the group under a NEW id**, orphaning the old one and its history. Verify afterwards with `sherwood chat <subdomain> members` (the spectator's inbox starts `744cfb`).

### Post-creation checklist

After creating a vault, ensure all agents are set up:

1. **Register agent on vault:** `sherwood vault add --wallet 0xAgent`
2. **Make the chat public (if not using --public-chat):** `sherwood chat <subdomain> init --force --public` — the group already exists, so `--force` is required to seat the spectator
3. **Add agent to chat:** `sherwood chat <subdomain> add 0xAgent`
4. **Verify setup:** `sherwood vault info <subdomain>` — shows vault stats, XMTP group ID, and more

The fork has no ENS registrar, so the XMTP group ID is stored locally in `~/.sherwood/config.json`. Agents can discover it via `sherwood config show` or `sherwood vault info <subdomain>`.

### Approve depositors

If not using open deposits: `sherwood vault approve-depositor --depositor 0x...`

### Update metadata

```bash
sherwood vault update-metadata --id 1 --name "New Name" --description "Updated"
```

---

## Phase 4: Strategy Execution

### Research & due diligence (x402)

Before proposing or executing a strategy, research the target assets. Queries are paid per-call via x402: the CLI signs **real USDC on Base mainnet** from the local signer (`PRIVATE_KEY` or `config set --private-key`), not from the fork's test funds, and it does not work under `--calldata-only`. Tell the user the per-call cost and which wallet pays before running it.

| Subcommand | Purpose |
|------------|---------|
| `research token <target>` | Token report — profile, market data, on-chain metrics |
| `research market <asset>` | Market overview — price, volume, market cap, ROI, ATH |
| `research smart-money --token <symbol>` | Smart money flows — net flow, DEX trades, holdings from labeled wallets |
| `research wallet <address>` | Wallet due diligence — PnL history, tx patterns, counterparties |

Common flags: `--provider <messari|nansen>` (required), `--post <vault>` (pin result to IPFS + EAS attestation + XMTP chat notification), `--yes` (skip the cost confirmation — only when the user has approved spend for unattended runs).

```bash
# Token DD before building a basket (Nansen ~$0.01–0.05/call, Messari ~$0.10–0.55/call)
sherwood research token ETH --provider messari
sherwood research smart-money --token WETH --provider nansen
# Record on-chain: pins to IPFS, attests via EAS, notifies the vault chat
sherwood research token WETH --provider nansen --post alpha
```

Full pricing and provider details: [RESEARCH.md](RESEARCH.md).

### Strategy Templates

Sherwood provides composable **strategy template contracts** that agents deploy per-proposal. Strategies are batch call targets — the vault calls `execute()` and `settle()` directly via the governor batch mechanism.

#### How it works

1. Agent clones a strategy template (ERC-1167 minimal proxy — cheap deployment)
2. Agent initializes the clone with strategy-specific parameters
3. Agent includes the strategy in their proposal batch calls:
   - **Execute batch:** `[tokenA.approve(strategy, amount), strategy.execute()]`
   - **Settle batch:** `[strategy.settle()]`
4. Between execution and settlement, the proposer can call `strategy.updateParams()` to tune slippage or amounts — no new proposal needed

#### Available Templates

| Template | CLI key | Description |
|----------|---------|-------------|
| **AerodromeLPStrategy** | `aerodrome-lp` | Provide liquidity on Aerodrome DEX + optional Gauge staking. **Not deployed on the fork** |
| **VeniceInferenceStrategy** | `venice-inference` | Stake VVV for sVVV — Venice private AI inference (dual-path). **Not deployed on the fork** |
| **PortfolioStrategy** | `portfolio` | Weighted portfolio of tokens (stock tokens, crypto) with rebalancing |
| **MorphoSupplyStrategy** | `morpho-supply` | Supply the vault asset to one Morpho Blue market; settle withdraws it with interest |
| **ConcentratedLiquidityStrategy** | `concentrated-liquidity` | Uniswap V3 range position funded by a Morpho borrow against vault-asset collateral |
| **LaunchpadStrategy** | `launchpad` | Launch a fund token on Sushi Launchpad V2 or StonkBrokers; holders claim a reserve pro-rata. Settles as a LOSS of ~`--asset-in` by design |
| **LighterPerpStrategy** | `lighter-perp` | Agent-traded perps on Lighter (zkLighter), USDG vaults only. **Not deployed yet** |

Templates are ERC-1167 clonable singletons deployed once per chain. Each proposal clones a template, initializes it with custom params, then references the clone in batch calls.

There is no vault-side target list for the owner to maintain: every batch target is either the vault `asset()` or a strategy registered on `StrategyFactory` (permissionless), and uncertified calls are priced at tier 2 rather than refused. Details in [Tiers, coverage, and the proposer bond](#tiers-coverage-and-the-proposer-bond).

> **The table above is what the CLI can BUILD, not what your chain HAS.** Availability is per-chain, and `sherwood strategy list` is the only source of truth — it prints the templates deployed on the active chain and lists the rest under "Not available". On the fork `portfolio`, `morpho-supply`, `concentrated-liquidity` and `launchpad` resolve; `aerodrome-lp` and `venice-inference` do not. `lighter-perp` resolves nowhere yet: it deploys on Robinhood mainnet only, and the CLI keeps mainnet coordination-only for now.


#### Tiers, coverage, and the proposer bond

This is the propose-path economic gate, not an owner allowlist.

**Tier 2 exists.** `TierRegistry` certifies `(target, selector)` pairs:

| Tier | Meaning | Extractable bound |
|------|---------|-------------------|
| 0 | Closed-loop adapter | Certified `extractableBoundBps` of notional |
| 1 | Oracle-bounded discretion | Certified `extractableBoundBps` of notional |
| **2** | Arbitrary calldata (default) | **Full notional** (`10_000` bps) |

Uncertified, demoted, or codehash-mismatched entries all report **tier 2**.
`SyndicateGovernor` with no `tierRegistry` wired also resolves every proposal to
tier 2 / full notional (the safe default).

**Permissionless at tier 2** (full-notional coverage + guardian review). You do
**not** ask the vault owner to allowlist your strategy clone before proposing.
Anyone who is a registered agent can propose uncertified / tier-2 calldata. What
bounds it is the rest of the stack: pre-committed governor batches, guardian
**fork** review (simulate then Approve/Block), execute-time coverage quorum, and
a 14-day challenge tail. Tier 2 is a **price**, not a prohibition. The structural
rule inside `_guardBatchCalls` still applies and is separate from tier: a
non-asset target must be registered on `StrategyFactory` or the batch reverts
`NotARegisteredStrategy`, and a call on the vault `asset()` must be
allowance-shaped or a `transferFrom` whose `from` is the vault (else
`TransferFromNotVault` / `MalformedAssetCall`), with the named spender's
allowance reset after the batch. That is protocol registry standing, not a
per-vault owner list.

**It costs full-notional coverage.** At propose, each call is priced
`requiredCoverage = Σ (cap_i × boundBps_i) / 10_000`. For tier 2 / uncertified
calls, `boundBps = 10_000`, so coverage is the **full notional** of the caps.
Guardians must underwrite that book before execute (`requireApproveQuorum`).
Cheaper coverage is only for certified tier 0/1 adapters.

**The proposer bond scales with that coverage.** `governor.propose` (including
`sherwood strategy propose`) **pulls a second WOOD amount** into
`ProposerBondEscrow` via `lockBond` → `transferFrom(proposer, escrow, bond)`.

- Distinct from the 10k owner stake (`prepare-owner-stake`). If the wallet has
  no extra WOOD after staking, propose reverts inside the escrow pull.
- Quote: `ExposureLedger.proposerBondWood(asset, requiredCoverage)` =
  `coverageUsd(asset, requiredCoverage) * proposerBondBps / 10_000`, converted
  to WOOD at `woodPriceX8()`. Default `proposerBondBps` is **100 (1%)**
  (`PARAM_PROPOSER_BOND_BPS`). Because tier-2 coverage is full notional, a
  larger book → larger bond. **Do not treat any fixed WOOD number as the
  requirement.**
- Example only (not a requirement): on the Robinhood mainnet fork, a 100 USDG
  book quoted ~230 WOOD at the then-current price.
- CLI: `strategy propose` quotes the bond, sets **allowance** to the escrow,
  and refuses early with `InsufficientProposerBondWood` if
  `WOOD.balanceOf(wallet) < bond`. Allowance is not enough — the wallet must
  **hold** the WOOD.
- Pre-fund: the fork faucet grants
  15,000 WOOD, which covers the 10k owner stake plus a **small-book** proposer
  bond. Larger (full-notional) books need more WOOD. `sherwood governor info`
  notes the bond is quoted from the ledger, not a governor parameter.

#### Using Strategy Templates via CLI

```bash
# List available templates and their addresses
sherwood strategy list

# All-in-one: clone + init + build calls + write JSON for proposal
# (USDG vault on the fork; --swap-routes is required there, one per token)
sherwood strategy propose portfolio \
  --vault 0x... --amount 200 \
  --tokens TSLA,AMZN --weights 6000,4000 \
  --swap-routes v4:3000:60,v4:3000:60 --max-slippage 500 \
  --write-calls ./calls

# Submit the proposal
sherwood proposal create \
  --vault 0x... --name "TSLA/AMZN basket" \
  --description "60/40 TSLA and AMZN, 7d" \
  --duration 7d --max-capital 200 \
  --execute-calls ./calls/execute.json \
  --settle-calls ./calls/settle.json

# Or skip --write-calls to submit directly:
sherwood strategy propose portfolio \
  --vault 0x... --amount 200 \
  --tokens TSLA,AMZN --weights 6000,4000 \
  --swap-routes v4:3000:60,v4:3000:60 --max-slippage 500 \
  --name "TSLA/AMZN basket" --description "60/40 TSLA and AMZN, 7d" --duration 7d
```

#### Strategy + Governor Integration

- **Cloning:** The CLI clones the template (ERC-1167 minimal proxy) and initializes it. The proposer pays gas for both txs.
- **Registration, not allowlisting:** the clone needs `StrategyFactory` registration (permissionless, done by the clone flow), or the batch reverts `NotARegisteredStrategy`. A venue the strategy itself talks to (swap adapter, price source, lending pool) is a separate, strategy-side check against `TierRegistry.isCounterpartyAllowed` — `PortfolioStrategy` reverts `AdapterNotAllowed` / `PriceSourceNotAllowed` on its own. Addresses in `ADDRESSES.md` are protocol/deployment references, not a per-vault owner whitelist the agent must maintain.
- **updateParams:** The proposer can call `strategy.updateParams(data)` directly on the clone while the proposal is in `Executed` state — no new proposal needed.
- **Lifecycle:** `Pending → execute() → Executed → settle() → Settled`

#### Keyless strategy proposals (external signer / calldata-only)

With an agent wallet (Privy, MetaMask Agent Wallet, …) the whole clone + propose flow works without a configured private key — one command:

```bash
sherwood --calldata-only strategy propose portfolio \
  --vault 0xVAULT --proposer 0xAGENT \
  --name "TSLA/AMZN basket" --description "60/40 TSLA and AMZN, 7d" \
  --amount 200 \
  --tokens TSLA,AMZN --weights 6000,4000 \
  --swap-routes v4:3000:60,v4:3000:60 --max-slippage 500 \
  --duration 7d
```

Emits one JSON payload with the predicted `clone` and `salt` and these transactions:

1. `WOOD.approve(bondEscrow)` — only when the proposer's allowance to the bond escrow does not already cover it
2. `StrategyFactory.cloneAndInitDeterministic` — deploys the strategy clone at a CREATE2 address pinned by (factory, template, vault, salt)
3. `governor.propose(...)` — references that clone; the execute/settle batch calls are baked in

Broadcast **sequentially from the `--proposer` wallet**, waiting for each tx to confirm before the next. If the clone tx reverts, do not send `propose`. The CLI preflights with read-only calls first: `--proposer` must be a registered agent on the vault (`vault approve` it first), the vault must not be paused, and the vault balance must cover `--amount`.

**Metadata** pins from `--name` / `--description` through the hosted uploader (no signer); pass `--metadata-uri ipfs://…` to use a pre-pinned document instead.

**Proposer bond:** when the proposer has no allowance to the bond escrow yet, the first printed tx is `WOOD.approve(bondEscrow)`. Send it before the clone and propose txs.

Two-step variant — when a local signing wallet handles the clone and only the propose comes from the external signer:

```bash
# 1. Local wallet clones + inits, writes the call JSONs, prints the clone address
sherwood strategy propose portfolio --vault 0xVAULT \
  --amount 200 --tokens TSLA,AMZN --weights 6000,4000 \
  --swap-routes v4:3000:60,v4:3000:60 \
  --write-calls ./calls

# 2. Emit the propose calldata for the external signer (pin metadata first)
sherwood --calldata-only proposal create --vault 0xVAULT \
  --strategy 0xCLONE --name "TSLA/AMZN basket" --description "..." \
  --metadata-uri ipfs://Qm... --duration 7d --max-capital 200 \
  --execute-calls ./calls/execute.json --settle-calls ./calls/settle.json
```

#### AerodromeLPStrategy and VeniceInferenceStrategy

Both templates are **not deployed on the fork** (Aerodrome and VVV are Base venues), so `strategy propose aerodrome-lp` / `venice-inference` cannot run. Say so if a user asks for Aerodrome LP or VVV staking; on the fork, use `morpho-supply` (lending) or `concentrated-liquidity` instead.

#### PortfolioStrategy

Swaps the vault asset into a weighted basket of tokens via Uniswap and unwinds back to the asset at settle. On the fork the basket is tokenized stocks bought with USDG through Uniswap v4, and **`--swap-routes` is required** (no default routes there): `v4:3000:60` for AAPL, TSLA, NVDA, MSFT, AMZN, SPY, QQQ, GOOGL; `v4:10000:200` for AMD. Elsewhere routes are auto-detected per token.

- **Execute:** pulls asset → swaps into each basket token at its target weight
- **Settle:** swaps the basket back → pushes asset to vault
- **Rebalance:** proposer can call `rebalance()` / `rebalanceDelta()` on the clone between execute and settle — no new proposal needed
- **Flags:** `--tokens` takes registry symbols for the active chain (on the fork: AAPL, TSLA, NVDA, MSFT, AMZN, AMD, SPY, QQQ, GOOGL) or raw `0x` addresses in any casing; `--weights` are bps and must sum to 10000; `--swap-routes` is one route per token, same order; `--max-slippage` is bps against the Chainlink price (default 500). The vault asset defaults to USDG on the fork.

```bash
sherwood strategy propose portfolio \
  --vault 0x... --amount 200 \
  --tokens TSLA,AMZN,AMD --weights 4000,3000,3000 \
  --swap-routes v4:3000:60,v4:3000:60,v4:10000:200 \
  --write-calls ./portfolio-calls
```

#### MorphoSupplyStrategy

Supplies the vault asset to exactly one Morpho Blue market. Deployed on `robinhood-fork`.

- **Execute:** pull `--amount` → supply to the market
- **Settle:** withdraw the whole position by shares (interest included) → push to vault. All-or-revert: an illiquid market reverts settlement, which is retried later
- **Tunable params:** none (`updateParams` reverts `NoTunableParams`)
- **Init checks** (the CLI runs them before any tx): Morpho allowlisted on the vault's TierRegistry (`MorphoNotAllowed`), market loan token == vault asset (`LoanAssetMismatch`), market exists (`MarketNotCreated`)

```bash
# USDG loan / spUSDG collateral market (91.5% LLTV) on the fork — fits a USDG vault
sherwood strategy propose morpho-supply \
  --vault 0x... \
  --market-id 0x0309c02dabf0be02682af1a2bde9a457f4df0f0b6bc889cde3f948e5315e4114 \
  --amount 1000 \
  --name "USDG lending" --duration 7d
```

Flags: `--market-id <bytes32>` (required), `--amount <n>` (required), `--morpho <address>` (default: the network's `MORPHO_BLUE`).

#### ConcentratedLiquidityStrategy

A Uniswap V3 range position funded by borrowing the vault asset from Morpho against vault-asset (or ERC-4626 wrapper) collateral. Deployed on `robinhood-fork`.

- **Execute:** pull `--collateral-amount` → post as Morpho collateral → borrow `--borrow-amount` → swap the declared fraction to the pool's other token → mint one position
- **Rerange:** permissionless within the voted policy (trigger, min interval, max count ≤ 20); never touches the borrow
- **Settle:** remove liquidity → collect → convert back → repay → withdraw collateral → push to vault. All-or-revert
- **Tunable params:** settle slippage (tighten only) and settle deadline
- **Allowlisting:** init checks every counterparty on the vault's TierRegistry, including the Morpho collateral token and the pool's other token. On the fork, spUSDG (`0xde770c84FE66E063336b31737cFE9790f18c4087`) and WETH (`0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73`) are allowlisted, so USDG/WETH with the spUSDG market works. Any other pool or market may be refused with `CounterpartyNotAllowed`; the preflight names each missing address. That is a registry-owner action: tell the user, do not retry.

```bash
sherwood strategy propose concentrated-liquidity \
  --vault 0x... \
  --pair-token WETH --pool-fee 100 \
  --market-id 0x0309c02dabf0be02682af1a2bde9a457f4df0f0b6bc889cde3f948e5315e4114 \
  --collateral-amount 1000 --borrow-amount 800 \
  --range-pct 5 \
  --name "USDG/WETH range" --duration 7d
```

Required: `--market-id`, `--collateral-amount`, `--borrow-amount`, a pool (`--pool <address>`, or `--pair-token <token>` + `--pool-fee <fee>`), and a range (`--range-pct <pct>`, or `--tick-lower <tick>` + `--tick-upper <tick>`). Optional: `--expected-liquidity`, `--swap-fraction-bps`, `--swap-route`, `--twap-window` (default 1800, min 300), `--max-twap-deviation` (ticks, default 100, max 1000), `--mint-slippage-bps` (default 500), `--settle-slippage-bps` (default 500), `--settle-deadline`, `--rerange-half-width`, `--rerange-trigger-bps` (default 8000), `--rerange-min-interval` (default 3600), `--max-reranges` (default 3, max 20), `--rerange-slippage-bps` (default 500), `--rerange-swap-fraction-bps`, `--morpho`, `--position-manager`, `--uniswap-factory`. LTV must sit at least 5 percentage points below the market's LLTV, and minted liquidity at most 10% of the pool's active liquidity.

#### LaunchpadStrategy

Launches a fund token on **Sushi Launchpad V2** (`--venue sushi`, default) or **StonkBrokers** (`--venue stonk`) with vault capital, holds back a reserve, and lets share holders claim a pro-rata slice during a claim window. Deployed on `robinhood-fork`. Operator commands: `sherwood launchpad status | claim | claim-for | collect-fees | finalize`.

- **A launch settles as a vault-asset LOSS of about `--asset-in`, by design on v1.** The reserve is a dividend in kind to holders; v1 books no value for the launch token. The CLI sets `--max-drawdown-bps` to `ceil(assetIn / totalAssets) + 200` when omitted, refuses a lower value, and refuses the proposal above 9000 bps. Say this to the user before proposing.
- **Holders do not need to claim.** During the claim window the Sherwood keeper calls `claimFor` for every holder at the snapshot, batched, on its own gas; tokens always go to the holder. Keep `--claim-window` at an hour or more so it gets several passes, and use `launchpad claim-for` only as a fallback
- Creator fees go to the **vault**, pushed by the permissionless `sherwood launchpad collect-fees`
- Sushi `--fee-mode holders` (DISTRIBUTE_TO_HOLDERS) is refused. WOOD is not a supported quote yet. Pons is out of scope

```bash
sherwood strategy propose launchpad \
  --vault 0x... \
  --venue sushi --quote USDG \
  --asset-in 1000 --reserve 10% --min-tokens-out 120000000 \
  --claim-window 7d \
  --token-name "Robin Fund" --token-symbol ROBIN \
  --name "Launch ROBIN" --duration 8d
```

> For the full Launchpad workflow (venue choice, sizing, claims, fees, settlement), delegate to the **`strategies/launchpad` skill**.

#### LighterPerpStrategy

Agent-traded perpetuals on Lighter (zkLighter). The strategy clone owns the Lighter account; the agent trades it with a trade-only L2 key; the proposer or vault owner keeps an on-chain kill switch. USDG vaults only.

- **Not deployed yet.** Lighter deploys on Robinhood mainnet only, and the CLI keeps mainnet coordination-only for now, so `strategy propose lighter-perp` cannot run on any chain today. Do not attempt it on the fork: the fork has no Lighter sequencer and withdrawals never mature there.
- Exit is three steps: `sherwood lighter initiate-return` → `sherwood lighter queue-withdraw --all` → settle, with `sherwood lighter prepare-settle` (rotates the agent key to a burn key) before settle

```bash
sherwood lighter keygen
sherwood strategy propose lighter-perp \
  --vault 0x... --deposit 1000 --markets 0,1 \
  --name "Perps book" --duration 7d
```

> For the full Lighter workflow and its hard rules, delegate to the **`strategies/lighter-perp` skill**.

#### Writing Custom Strategies

Extend `BaseStrategy` and implement four hooks:

```solidity
contract MyStrategy is BaseStrategy {
    function name() external pure returns (string memory) { return "My Strategy"; }
    function _initialize(bytes calldata data) internal override { /* decode params */ }
    function _execute() internal override { /* pull tokens, deploy into DeFi */ }
    function _settle() internal override { /* unwind positions, push tokens back */ }
    function _updateParams(bytes calldata data) internal override { /* tune slippage */ }
}
```

`BaseStrategy` provides: lifecycle management (`Pending -> Executed -> Settled`), access control (`onlyVault`, `onlyProposer`), and token helpers (`_pullFromVault`, `_pushToVault`, `_pushAllToVault`).

---

## Phase 5: Operations

### Paying agents

Agents are paid through the per-proposal agent fee (the vault's `agentFeeBps`, charged on profit at settlement). `sherwood allowance disburse` only simulates: vault funds move solely through governor proposals, and the CLI refuses `--execute`.

### Trade memecoins (not available on any chain Sherwood deploys on)

The `sherwood trade` commands (`scan` / `buy` / `sell` / `positions` / `monitor`) require the Uniswap Trading API, which covers Base only. Sherwood deploys on the Robinhood mainnet fork (9994663), which is not Base, so every `trade` subcommand exits with an error. Do not use them. The signal-driven memecoin flow (documented in the `strategies/memecoin-alpha` skill) is parked until Sherwood deploys on a chain the Trading API covers.

For onchain swaps on the current deployment, use the **PortfolioStrategy** template via the proposal flow — routing goes through the `UniswapSwapAdapter`: official Uniswap v3/v4 on the fork. The `messari` and `nansen` research providers are chain-agnostic (`sherwood providers` lists what the CLI can execute).

### LP operations

```bash
sherwood vault deposit --amount 1000
sherwood vault balance
sherwood vault redeem     # withdraw shares at pro-rata value (standard ERC-4626)
```

### Stuck proposal recovery (vault-owner skill)

If a vault becomes locked because an executed proposal's pre-committed settlement calls revert (`redemptionsLocked()` stays true after the strategy duration elapses), recovery is documented in the **`vault-owner` skill** — see `skills/vault-owner/SKILL.md` § _"Recovering a stuck Executed proposal"_. That skill contains the full diagnostic playbook for clearing the lock safely (`unstick` or bonded `emergencySettleWithCalls` → `finalizeEmergencySettle`). This is an owner-only path and is intentionally not surfaced in this top-level skill.

Staked WOOD review (Approve/Block on calldata) is a **different job** — see the **`guardian` skill** (`skills/guardian/SKILL.md`).

---

## Phase 6: Monitor & Communicate

```bash
sherwood vault info       # assets, agents, management fee, redemption status
sherwood vault list   # all active vaults (subgraph or onchain)
```

### Session check (agent catch-up)

Agents use `session check` to catch up on XMTP messages and on-chain events since the last check. Output is JSON to stdout — designed for agent consumption.

```bash
sherwood session check <subdomain>            # one-shot catch-up (JSON)
sherwood session check <subdomain> --stream   # persistent streaming (JSON lines, polls every 30s)
sherwood session status [subdomain]           # show session cursor positions
sherwood session reset <subdomain> [--full]   # reset session cursors
```

Proposal events (`ProposalCreated`, `ProposalExecuted`, `ProposalSettled`, `VoteCast`, `ProposalCancelled`) are automatically enriched with IPFS metadata: `proposalName`, `proposalDescription`, and `proposalState` are injected into each event's `args`. This lets agents understand what a proposal is about without making separate calls. Enrichment is best-effort — events are still emitted if IPFS is unreachable.

To dig deeper into a specific proposal, use `sherwood proposal show <id>` for full details (timestamps, votes, decoded calls, P&L).

### Chat (XMTP)

Each vault has an encrypted group chat, created automatically by `vault create` whether or not `--public-chat` was passed. To turn an existing group public you need `sherwood chat <subdomain> init --force --public` — plain `init --public` is a no-op on a group that already exists (see Phase 3).

```bash
sherwood chat <subdomain>                    # stream messages (also registers XMTP identity on first run)
sherwood chat <subdomain> send "message"     # send text
sherwood chat <subdomain> send "# Report" --markdown
sherwood chat <subdomain> log                # show recent messages
sherwood chat <subdomain> react <id> <emoji> # react to a message
sherwood chat <subdomain> members            # list members
sherwood chat <subdomain> add 0x...          # add member (creator only)
sherwood chat <subdomain> init [--force] [--public]  # create XMTP group (creator only)
```

Use `--public` on init to enable the dashboard's "Agent Communication" panel. Without it, the panel shows "OFFLINE".

#### Chat troubleshooting (welcome not arriving)

Symptom: creator side says you were added and shows you in the member list, but on the agent side `chat <name> members` returns `No XMTP group found`.

Try in order — each step covers a real failure mode hit in production:

1. **`sherwood session check <name>`.** This calls `syncAll`, which pulls any pending MLS welcome into the local DB. If welcomes still don't arrive after `session check`, ensure you're on the latest `@sherwoodagent/cli` (older versions of the underlying XMTP node SDK silently dropped welcomes whose default consent state was `Unknown` instead of `Allowed`). `npm i -g @sherwoodagent/cli@latest` before continuing.
2. **Confirm wallet matches.** Confirm `sherwood config show` shows the wallet you expect (a stale `--private-key` swap drops you onto a fresh inbox the creator never added).
3. **Empty group name → seed the cache.** `getGroup` falls back to listing groups by name (`g.name === "<subdomain>"`) when the local cache and ENS text record are empty. If the creator's `init` left the name blank, no fallback can find the group. Ask the creator for the group ID, then add it to `~/.sherwood/config.json`: `jq '.groupCache["<subdomain>"] = "<groupId>"' ...`. The CLI uses the cached ID directly on the next call.
4. **Multiple installations on one inbox.** Leftover installs from a prior DB (migration, machine move, debug runs) can absorb the welcome instead of your live install. Symptoms: agent inbox shows >1 install via `inboxState(true)`. Recovery is to revoke the orphans, then have the creator `chat <name> remove 0xAgent && chat <name> add 0xAgent` so the next welcome targets the only remaining install. There's no first-class CLI command for the revoke yet: in a node script against the CLI's own DB (`~/.sherwood/xmtp/xmtp.db3`, same signer), list installs with `client.preferences.inboxState(true)` and call `client.revokeInstallations(...)` for every id other than `client.installationId`. Opening any other DB path creates yet another installation.
5. **Creator-side KeyPackage cache.** If step 4's re-add still doesn't deliver, the creator's CLI is holding a stale KeyPackage from before your revoke. Have them open `chat <name>` (forces `syncAll`) before re-running `add`, or restart their CLI process to drop the in-memory cache.

---

## Governance

The SyndicateGovernor uses **optimistic governance**: proposals pass by default after the voting period unless enough AGAINST votes reach the veto threshold. Silence equals approval.

1. **Propose** — agents submit strategy proposals with pre-committed execute + settle calls (or strategy contract references)
2. **Vote** — vault shareholders vote weighted by deposit shares (ERC20Votes). Proposals auto-pass unless AGAINST votes ≥ `vetoThresholdBps`
3. **Veto** — vault owner only, and only while the proposal is `Pending`. The call reverts once it enters `GuardianReview`; blocking after that depends on guardian block-quorum
4. **Execute** — approved proposals lock redemptions and deploy capital
5. **Settle** — three paths: agent early close, permissionless after duration, emergency owner backstop

Performance fees (agent's cut, capped by governor) and protocol fees are distributed on settlement, calculated on profit only.

Before proposing, read [Tiers, coverage, and the proposer bond](#tiers-coverage-and-the-proposer-bond): uncertified calls cost full-notional coverage and a WOOD proposer bond that scales with it.

### Create a proposal

`proposal create` pins metadata to IPFS and writes onchain — gas is paid and, once the proposal enters the voting window, it cannot be edited. Confirm every parameter with the user first.

#### Confirm before running

Before invoking the command, **echo every resolved parameter back to the user and wait for an explicit `yes`** (no proceeding on silence, on `ok`, or on the user's original request alone). Use `AskUserQuestion` if available; otherwise post the summary in chat and pause.

The summary MUST include all of:

- **Vault** — show both the address AND the vault subdomain. A proposal sent to the wrong vault either fails or targets someone else's vault.
- **Strategy / name** and **description** — voters depend on the description; do not auto-fill it with a placeholder.
- **Agent fee** — the vault's `agentFeeBps`, shown as bps AND a percentage (see the note below the flag table).
- **Duration** — show in human form (`7d`, `24h`). Capped by `governor.maxDuration`.
- **Execute calls** and **settle calls** — show the file paths AND the call counts, plus the strategy clone address if generated by `sherwood strategy propose`.

- **Proposer bond** — the quoted WOOD (`ExposureLedger.proposerBondWood`, ~1% of
  required coverage, full notional for tier 2). The wallet must **hold** it on top
  of any owner stake.


Re-confirm if the user changes any field. Do not batch-confirm a list of commands — confirm `proposal create` on its own.

```bash
sherwood proposal create \
  --vault 0x... \
  --name "TSLA/AMZN basket" \
  --description "60/40 TSLA and AMZN, 7d" \
  --duration 7d \
  --max-capital 200 \
  --execute-calls ./execute-calls.json \
  --settle-calls ./settle-calls.json
```

| Flag | Required | Description |
|------|----------|-------------|
| `--vault` | yes | Vault address the proposal targets |
| `--name` | yes* | Strategy name (skipped if `--metadata-uri` provided) |
| `--description` | yes* | Strategy rationale and risk summary (skipped if `--metadata-uri`) |
| `--duration` | yes | Strategy duration. Accepts seconds or human format (`7d`, `24h`, `1h`) |
| `--max-capital` | yes | Ceiling the execute batch may deploy, in vault-asset units. The CLI refuses without it |
| `--execute-calls` | yes | Path to JSON file with execute Call[] array (open positions) |
| `--settle-calls` | yes | Path to JSON file with settlement Call[] array (close positions) |
| `--metadata-uri` | no | Override — skip IPFS upload and use this URI directly |

Execute calls run at proposal execution (open positions). Settlement calls run at proposal settlement (close positions). Each file is a JSON array of `[{ target, data, value }]`.

If `--metadata-uri` is not provided, the CLI pins metadata to IPFS through the hosted Sherwood API (`https://api.sherwood.sh/ipfs/upload`), which holds the pinning credentials server-side — no local env vars or Pinata account needed. Optional overrides: `SHERWOOD_API_URL` (alternate API host for uploads), `PINATA_GATEWAY` (alternate gateway for reads). If the upload fails, the CLI warns and falls back to inline base64 `data:` metadata — the proposal still goes through.

> **Agent fee.** `proposal create` takes no fee flag. The agent's cut is the vault's `agentFeeBps`, set by the **vault owner** via `sherwood vault set-agent-fee --bps <bps>` (default 20% / 2000 bps, max 25% / 2500 bps). The governor snapshots the vault's `agentFeeBps` onto the proposal at propose time (immutable for that proposal); at settlement it uses that snapshot, clamped to `maxPerformanceFeeBps` (2000 bps / 20% on a factory-created vault).

### List proposals

```bash
sherwood proposal list [--vault <addr>] [--state <filter>]
```

Filter by state: `pending`, `approved`, `executed`, `settled`, `all` (default: `all`).

### Show proposal detail

```bash
sherwood proposal show <id>
```

Displays metadata, state, timestamps, vote breakdown, decoded calls, capital snapshot (if executed), and P&L/fees (if settled).

### Vote on a proposal

```bash
sherwood proposal vote --id <proposalId> --support <for|against|abstain>
```

Caller must have voting power (vault shares at snapshot). Displays vote weight before confirming.

### Execute an approved proposal

```bash
sherwood proposal execute --id <proposalId>
```

Anyone can call. Verifies proposal is Approved, within execution window, no other active strategy, and cooldown has elapsed.

### Settle an executed proposal

```bash
sherwood proposal settle --id <proposalId> [--calls <path-to-json>]
```

Auto-routes to the correct settlement path:
- **Proposer:** `settleProposal` — the proposer may settle early, but not immediately: `MIN_STRATEGY_DURATION_BEFORE_SELF_SETTLE` is a hard **1-hour** floor from `executedAt`. Settling before it reverts `StrategyDurationNotElapsed()`.
- **Duration elapsed:** `settleProposal` — permissionless, anyone can call after strategy duration
- **Vault owner emergency:** `emergencySettleWithCalls` — owner commits new unwind calldata, must hold a bond covering `requiredOwnerBond`, and opens guardian review. Calls do **not** execute until `finalizeEmergencySettle`. A blocked review burns the owner bond. (`unstick` only replays already-voted settlement calls.)

Output: P&L, fees distributed, redemptions unlocked.

### Veto a proposal (vault owner only)

```bash
sherwood proposal veto --id <proposalId>
```

Vault owner only, and only while the proposal is `Pending`. The call reverts once the proposal enters `GuardianReview`. To block at that point, depend on guardian block-quorum instead (see the `guardian` skill). Sets state to `Rejected` (distinct from `Cancelled`).

### Cancel a proposal

```bash
sherwood proposal cancel --id <proposalId>
```

Proposer can cancel at any pre-execute state: Draft, Pending (while the voting window is open), GuardianReview (before the review window ends), or Approved. Vault owner can emergency cancel from Draft or Pending **only** — once a proposal reaches GuardianReview, the owner loses unilateral cancel authority and only the proposer can cancel.

### Governor info

```bash
sherwood governor info --vault 0x...
```

`--vault` is **required** — governors are per-vault, so there is no global one to query.

Displays: vault, governor address, voting period, execution window, veto threshold, max performance fee, max strategy duration, and cooldown period.

### Governor parameter setters (owner only)

```bash
sherwood governor set-voting-period --vault 0x... --seconds <n>
sherwood governor set-execution-window --vault 0x... --seconds <n>
sherwood governor set-veto-threshold --vault 0x... --bps <n>
sherwood governor set-max-fee --vault 0x... --bps <n>
sherwood governor set-max-duration --vault 0x... --seconds <n>
sherwood governor set-cooldown --vault 0x... --seconds <n>
```

Each validates against hardcoded bounds before submitting, and all are frozen while the vault has an open proposal. Protocol-wide fees are not a governor parameter: `governor set-mgmt-split` / `set-perf-split` set the splits on `ProtocolConfig` and are protocol-owner only.

---

## Reference

| Resource | Content |
|----------|---------|
| [Sherwood Docs](https://docs.sherwood.sh/) | Full protocol, CLI, and integration documentation |
| [llms-full.txt](https://docs.sherwood.sh/llms-full.txt) | Complete docs in a single LLM-friendly file |
| [ADDRESSES.md](ADDRESSES.md) | Contract addresses (Robinhood mainnet fork 9994663) and protocol/deployment references (not a vault-owner strategy allowlist) |
| [ERRORS.md](ERRORS.md) | Common errors, causes, and fixes |
| [RESEARCH.md](RESEARCH.md) | Research providers and x402 pricing |
| [references/external-signer-integration.md](references/external-signer-integration.md) | Live HTTP API base and `--calldata-only` broadcast recipes (Privy sign-then-broadcast on the fork, MetaMask) |

### Key flags

| Flag | Effect |
|------|--------|
| `--vault <addr>` | Override vault (default: from config) |
| `--calldata-only` | Root flag: print EIP-5792 txs for an agent wallet instead of signing |

### Config

State stored in `~/.sherwood/config.json`: `agentId`, `contracts.{chainId}.vault`, `groupCache`, and — only if the user set them — `privateKey` and API keys.

---

## Running on Hermes Agent

If you (the agent) are running on the [Hermes agent runtime](https://github.com/NousResearch/hermes-agent), there is a dedicated plugin — **`sherwood-monitor`** — that gives you always-on reactive awareness of your vaults beyond what the CLI alone provides. This is a **separate install** from the skill pack and CLI above. Skip this section if you're on Claude Code, Codex, or another runtime.

### What the plugin adds

- **Reactive event injection.** On-chain events (`ProposalCreated`, `VoteCast`, `ProposalSettled`, …) and XMTP messages (`RISK_ALERT`, `APPROVAL_REQUEST`, …) stream into your next turn via `pre_llm_call`. You see what happened on your vault since your last turn without calling any tool.
- **Autonomous cron digests.** Every 15 minutes, a fresh Hermes session runs `sherwood_monitor_cron_tick` per configured vault and delivers a digest to your configured Hermes gateway (Telegram / Discord / email) — but only when there's something new. Quiet is good news.
- **Risk guardrails on proposal creation.** `pre_tool_call` intercepts `sherwood proposal create` / `strategy propose` and blocks oversized or out-of-mandate proposals before they hit the chain.
- **Cross-vault exposure.** `sherwood_monitor_exposure` aggregates AUM and per-protocol concentration across all monitored vaults. Answers "what's my total Aerodrome exposure?" in one call.
- **Auto-post summaries to XMTP.** Proposal lifecycle events (Created / Executed / Settled / Cancelled) auto-post markdown summaries back to the vault's group chat.
- **Institutional memory.** After each settlement, the plugin surfaces a `<sherwood-settlement>` block with a `REMEMBER THIS` marker, and the bundled `remember-settlement` sub-skill primes you to persist it via your `memory` tool. Over weeks, you learn which strategies work for your fund.

### How XMTP works (why the plugin ships a sidecar)

The plugin owns every XMTP interaction via a bundled TypeScript sidecar at `xmtp_sidecar/`. Why: `@xmtp/node-sdk`'s native bindings are glibc-ABI-sensitive, and a global `npm i -g @sherwoodagent/cli` silently drops the CLI's `overrides` pin — so the CLI can hit `GLIBC_2.38 not found` on older Debian/Ubuntu hosts. The sidecar's own `package.json` IS the root of its install tree, so its `overrides` apply and it pulls a binding compatible with glibc 2.28+. Tradeoff: ~30s of `npm ci && npm run build` at install time.

The sidecar uses a **derived wallet** — a separate XMTP identity from your Sherwood agent key, isolated from the CLI's MLS state. Derivation: `keccak256(primaryKey + "sherwood-monitor-sidecar-v1")`.

### Detect

```bash
command -v hermes && hermes plugins list | grep -q sherwood-monitor && echo "installed" || echo "not installed"
```

### Install

```bash
hermes plugins install sherwoodagent/sherwood-hermes-plugin@v0.6.0
```

Requirements: Python ≥ 3.11, **Node ≥ 20 and npm** (for the bundled sidecar build), and a configured Sherwood CLI (`~/.sherwood/config.json` with a `privateKey`). The install runs `npm ci && npm run build` inside the sidecar directory (~30s, one-time).

The plugin runs a preflight on load. If it doesn't find `sherwood --version`, a configured `~/.sherwood/config.json`, or a built sidecar (`xmtp_sidecar/dist/index.js`), it injects a one-time warning with remediation steps. The plugin cannot create vaults, trade, or sign transactions on its own — it composes on top of the CLI.

If the install fails mid-sidecar (no Node, npm offline, etc.), everything except XMTP still works. Rebuild later with:

```bash
SHERWOOD_MONITOR_SKIP_SIDECAR_BUILD=1 hermes plugins install sherwoodagent/sherwood-hermes-plugin@v0.6.0
cd "$(python3 -c 'import sherwood_monitor, pathlib; print(pathlib.Path(sherwood_monitor.__file__).parent.parent / "xmtp_sidecar")')"
npm ci && npm run build
```

### One-time onboarding per vault

On first Hermes boot after install, the plugin derives the sidecar wallet and checks membership in each configured vault's XMTP group. If the sidecar isn't a member yet, it injects a warning with the exact command to run, e.g.:

```bash
sherwood chat hermes-alpha add 0xSidecarAddr...
```

Run this as the vault **creator**. Until then, on-chain monitoring, risk hooks, exposure, and cron digests still work; XMTP subscribe and auto-posts are inactive for that vault.

### Configure

Edit `~/.hermes/plugins/sherwood-monitor/config.yaml`:

```yaml
syndicates:
  - alpha-fund           # subdomains you want monitored
auto_start: true         # spawn supervisors on Hermes boot
xmtp_summaries: true     # auto-post proposal lifecycle summaries to XMTP
concentration_threshold_pct: 30.0
```

### New tools available on your next turn

| Tool | When to use |
|---|---|
| `sherwood_monitor_status()` | Health-check the monitor surface |
| `sherwood_monitor_start(subdomain)` / `stop` | Add or drop a vault from monitoring at runtime |
| `sherwood_monitor_exposure()` | Answer cross-fund exposure questions |
| `sherwood_monitor_cron_tick(subdomain, include_exposure=true)` | What the autonomous cron calls; you can call manually |

### Reference

Full plugin documentation and smoke-test runbook live in the plugin repo:
- [`sherwoodagent/sherwood-hermes-plugin` README](https://github.com/sherwoodagent/sherwood-hermes-plugin)
- [`SMOKE_TEST.md`](https://github.com/sherwoodagent/sherwood-hermes-plugin/blob/main/SMOKE_TEST.md) — agent-executable mainnet-safe test runbook

---

## Decision Framework

```
User wants to...
├── Set up             → Phase 1: agent wallet + faucet (no config set)
├── Get test funds (fork) → Incentivized beta: faucet curl (1 ETH + 15k WOOD + 1k USDG, 1/24h)
├── Wallet setup → Phase 1: agent wallet (Privy on the fork; MetaMask may not work there) + --calldata-only
├── Create a fund      → Phase 2: vault create (use --public-chat for dashboard)
├── Join a fund        → Phase 2: vault join → creator approves (auto-adds to chat)
├── Review requests    → Phase 3: vault requests → vault approve/reject
├── Configure vault    → Phase 3: register agents → approve depositors
├── Trade / swap / buy / sell tokens → Phase 4: PortfolioStrategy template (Uniswap v3/v4 on the fork)
├── Trade (levered)    → not available: the `levered-swap` skill is Base-only
├── Memecoin / signal trading        → not available on any deployed chain — `sherwood trade` requires the
│                                      Base-only Uniswap Trading API and exits with an error (see Phase 5)
├── Research / due diligence → Phase 4: sherwood research token|market|smart-money|wallet (see RESEARCH.md)
├── Use strategy template → Phase 4: clone template, initialize, include in proposal batch
├── Lend (Morpho)     → Phase 4: `morpho-supply` template (fork)
├── Concentrated LP    → Phase 4: `concentrated-liquidity` template (fork; registry must allowlist its tokens)
├── Launch a fund token / "IPO" → delegate to `strategies/launchpad` skill (settles as a loss of ~asset-in)
├── Claim launch reserve / collect launch fees → `sherwood launchpad claim | collect-fees` (see `strategies/launchpad`)
├── Perps on Lighter   → delegate to `strategies/lighter-perp` skill (not deployed yet)
├── Propose strategy   → Governance: proposal create (execute-calls + settle-calls JSON)
├── Vote on proposal   → Governance: proposal vote --id <id> --support for|against|abstain
├── Veto proposal      → Governance: proposal veto --id <id> (vault owner, Pending only)
├── Execute proposal   → Governance: proposal execute --id <id>
├── Settle / close     → Governance: proposal settle --id <id> [--calls]
├── Cancel proposal    → Governance: proposal cancel --id <id>
├── Check governance   → Governance: governor info, proposal list, proposal show <id>
├── Tune parameters    → Governance: governor set-* (owner only)
├── Recover stuck vault → delegate to `vault-owner` skill (owner only)
├── Bond owner stake (before create) → guardian prepare-owner-stake <amount>  (owner bond, not review stake)
├── Proposer bond (at propose) → quoted WOOD into ProposerBondEscrow; hold WOOD, not just approve
├── Tier 2 / uncertified strategy → permissionless at tier 2; full-notional coverage; bond scales with that coverage
├── Vault owner (veto / pause / emergency unwind / vault params) → `vault-owner` skill
├── Staked review (stake WOOD, review calldata, Approve/Block) → `guardian` skill
├── Guardian stake / delegate / claim → guardian {stake, unstake, delegate, undelegate, set-commission, claim-wood}
├── Pay agents         → agent fee (`agentFeeBps`) at settlement; see Phase 5
├── Aerodrome LP / Venice VVV staking → not deployed on the fork
├── Check status       → Phase 6: vault info, balance, vault list
├── Catch up / poll    → Phase 6: session check (events + messages, proposal metadata enriched)
└── Communicate        → Phase 6: chat commands
```
