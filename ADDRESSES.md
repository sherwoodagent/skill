# Contract Addresses

Sherwood currently deploys on **Robinhood testnet (chain 46630)** — the CLI targets
it by default. These addresses are also available in `cli/src/lib/addresses.ts`
(resolved at runtime). This is the initial deployment target; the protocol will
expand to more chains over time.

> See also: [Deployments reference](https://docs.sherwood.sh/reference/deployments)

## Robinhood testnet (chain 46630)

V2 deployment — full stack: core contracts + guardian layer (registry + sWOOD) +
live-NAV (PriceRouter + Uniswap-compatible adapter backed by Synthra) +
StrategyFactory keyless deploy. Source of truth: `contracts/chains/46630.json`.

| Contract | Address |
|----------|---------|
| SyndicateFactory | `0xa91AA45AFF32f52b6357044B02a16EBA775feC0b` |
| GovernorBeacon | `0x3D46Ec018cd5893b685b4dfdc3921A4Eb64E11d1` |
| ProtocolConfig | `0xC104Eb6a522d6718cA28F344B2373B29d57FF2E0` |
| SyndicateVaultImpl | `0xC57e12d6e2d8Ed49316F0b69c51893CcA44151F7` |
| BatchExecutorLib | `0xF3b8db5aa41c7Ce92478A0Fa9C55a6460533eb86` |
| GuardianRegistry | `0xA400eFcfFc820C6f812203C58ee00423AeCC0903` |
| StakedWood (sWOOD) | `0x21A69A6c9814c0d339C57fDdafed3B283702a739` |
| TierRegistry | `0x99b8068Dc0F6093466964D581f72d947e3e380DB` |
| CallSandboxImpl | `0xf09f6AF7DeBB964eD731376C9Af389F2Ce3d872A` |
| WOOD token (fixture) | `0xCCb4fB59cf40de1E23083037ee81Da1DD747D8d7` |
| PriceRouter | `0xDd302ffcfA08071780eC1A2f12BccFB9ba6b6731` |
| PortfolioStrategy (template) | `0x67420Cc504d70a42Adfd8867d878afe0978C7d10` |
| StrategyFactory | `0xb683Bb8EEcBc2419BC3801df6FeA88f96657e670` |
| UniswapSwapAdapter (Synthra-backed) | `0x4fc3492117cC3bbcE0b210D22a8DC244f9d86490` |

There is **no singleton `SyndicateGovernor`**. Since PR #421 each vault has its own
governor — a `BeaconProxy` the factory deploys at creation, all sharing one
implementation via the `GovernorBeacon` above — resolved at runtime via
`factory.governorOf(vault)` (`sherwood governor show --vault <addr>` prints it; the
CLI resolves it for you). Protocol-level fees live on the shared `ProtocolConfig`.

### Tokens

| Token | Address |
|-------|---------|
| WETH (default vault asset) | `0x7943e237c7F95DA44E0301572D358911207852Fa` |
| TSLA | `0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E` |
| AMZN | `0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02` |
| PLTR | `0x1FBE1a0e43594b3455993B5dE5Fd0A7A266298d0` |
| NFLX | `0x3b8262A63d25f0477c4DDE23F83cfe22Cb768C93` |
| AMD | `0x71178BAc73cBeb415514eB542a8995b82669778d` |

There is no USDC on this chain — WETH is the default vault asset.

### External Protocols

Synthra is Uniswap-V3-compatible; the deployed `UniswapSwapAdapter` is backed by the
Synthra router plus a QuoterV2 shim. Prices come from Chainlink Data Streams via the
verifier proxy.

| Contract | Address |
|----------|---------|
| Synthra Router | `0x3Ce954107b1A675826B33bF23060Dd655e3758fE` |
| Synthra Quoter | `0x231606c321A99DE81e28fE48B07a93F1ba49e713` |
| Synthra V3 Factory | `0x911b4000D3422F482F4062a913885f7b035382Df` |
| Synthra QuoterV2 shim | `0xb3C009aECAeDd5ccC62Ec12eDAAA55F19C4A1eFb` |
| Chainlink Verifier Proxy | `0x72790f9eB82db492a7DDb6d2af22A270Dcc3Db64` |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |
| Multicall3 | `0xcA11bde05977b3631167028862bE2a173976CA11` |

## Not yet active on Robinhood testnet

The following are not deployed on the current target chain and come online as
Sherwood expands to more chains:

- **ERC-8004 agent identity** — no IdentityRegistry on this chain; `syndicate create`
  and `syndicate add` skip identity verification (registries are `address(0)`), and
  `agentId=0` is used when `--agent-id` is omitted.
- **EAS coordination attestations** (join requests / approvals) — no EAS predeploy.
- **ENS subnames (Durin)** — no registrar; `syndicate create` skips ENS registration.
- **Strategies other than Portfolio** — Moonwell (supply / wstETH), Aerodrome LP,
  Leveraged Aerodrome CL, Venice inference, Mamo yield, Hyperliquid perp/grid.

## Strategy Templates

The live strategy on Robinhood testnet is **Portfolio** — a weighted basket of
tokenized stocks/crypto with on-chain rebalancing through Synthra. Use
`sherwood strategy list` to see current deployed template addresses.

| Template | Address |
|----------|---------|
| PortfolioStrategy | `0x67420Cc504d70a42Adfd8867d878afe0978C7d10` |
| UniswapSwapAdapter (Synthra-backed) | `0x4fc3492117cC3bbcE0b210D22a8DC244f9d86490` |

Under the V2 live-NAV model the strategy is never trusted for value: it reports its
on-venue holdings via `IStrategy.positions()` and the vault prices them through the
governance-owned `PriceRouter`. Portfolio reports no priceable positions and routes
through the async-redeem queue (Lane B), settling at one frozen per-proposal price.

## Batch callees — Portfolio Strategy

There is **no vault-side target list**. The vault does not maintain an on-chain
batch-target set. Reachability is `TierRegistry.isCallableTarget` (callee axis)
plus `isAdapterAllowed` (funds). A disallowed batch callee reverts
`DisallowedBatchCallee`.

The vault `asset()` is the sole callee exemption. Everything else a governor
batch calls must pass `isCallableTarget`. Approve spenders and transfer
recipients must pass `isAdapterAllowed`.

Typical Portfolio addresses on Robinhood testnet:

| Role | Address |
|------|---------|
| WETH (vault asset) | `0x7943e237c7F95DA44E0301572D358911207852Fa` |
| UniswapSwapAdapter (Synthra) | `0x4fc3492117cC3bbcE0b210D22a8DC244f9d86490` |
| Synthra Router | `0x3Ce954107b1A675826B33bF23060Dd655e3758fE` |
| Stock tokens | e.g. TSLA / AMZN / AMD (see Tokens above) |
| Strategy clone | printed by `sherwood strategy propose` |
