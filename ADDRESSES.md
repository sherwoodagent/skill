# Contract Addresses

These are also available in `cli/src/lib/addresses.ts` (resolved at runtime based on `--chain`).

> See also: [Deployments reference](https://docs.sherwood.sh/reference/deployments)

## Base Mainnet

| Contract | Address |
|----------|---------|
| SyndicateFactory | `0xAC74EC56858d7F1f7618c8e77F65Fc26aDf33c82` |
| SyndicateGovernor | `0x9Fd3c87B34F254e3c5652A0394B9780c2F05d367` |
| GuardianRegistry | `0x49E4163b5e4b23F8f3d469Cf6fa197FB6b06A26E` |
| BatchExecutorLib | `0xbC79FbD5036C1Cc4A9d10BDf8628BF09a558496E` |
| SyndicateVaultImpl | `0xfce4bcE08E9C047E4736f75C2B8557e2754Ce36A` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` (6 decimals) |
| WETH | `0x4200000000000000000000000000000000000006` |
| Moonwell Comptroller | `0xfBb21d0380beE3312B33c4353c8936a0F13EF26C` |
| Moonwell mUSDC | `0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22` |
| Moonwell mWETH | `0x628ff693426583D9a7FB391E54366292F509D457` |
| Aerodrome Router | `0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43` |
| Aerodrome Default Factory | `0x420DD381b31aEf6683db6B902084cB0FFECe40Da` |
| AERO Token | `0x940181a94A35A4569E4529A3CDfB74e38FD98631` |
| Uniswap SwapRouter | `0x2626664c2603336E57B271c5C0b26F421741e481` |
| Uniswap QuoterV2 | `0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a` |
| VVV | `0xacfe6019ed1a7dc6f7b508c02d1b04ec88cc21bf` |
| VVV Staking (sVVV) | `0x321b7ff75154472b18edb199033ff4d116f340ff` |

## Robinhood L2 Testnet (chain 46630)

V2 redeploy — full stack: core contracts + guardian layer (registry + sWOOD) +
live-NAV (PriceRouter + Uniswap-compatible adapter backed by Synthra) +
StrategyFactory keyless deploy. Source of truth: `contracts/chains/46630.json`.

| Contract | Address |
|----------|---------|
| SyndicateFactory | `0x81F785E31B9f31BC437978B5E7dEe8006F43dd8b` |
| SyndicateGovernor | `0xdAB22196ac2c6C5C33445f3125C28aF98E0cA2d0` |
| SyndicateVaultImpl | `0xB21b3af1E9f99222d136517363d0d185AF2449cd` |
| BatchExecutorLib | `0xB869dF634679C6a36D6C82D47D1793486F4cba3a` |
| GuardianRegistry | `0x2fe810666E673Fbd87cA00f95EBf82a19A5b543F` |
| StakedWood (sWOOD) | `0x320911DEF7Ec4c0C435B9cCEE3fAfE9EEad171C9` |
| WOOD token (fixture) | `0x4435Aae199907f60588902Bcd7c4363a13Bb2951` |
| PriceRouter | `0x7Cc36bcc6a1f0F2607BacC8692fe2aD52eB14fd7` |
| PortfolioStrategy | `0x3a6121371D51B59De3A14Bc401EfBd3fb726E109` |
| StrategyFactory | `0xBBb2884dEAD8235d75a0405ecC3c9F5713cBE904` |
| UniswapSwapAdapter (Synthra-backed) | `0x2e8aB422Db9127F1a70d8C38A15903f22B51DA97` |
| Synthra Router | `0x3Ce954107b1A675826B33bF23060Dd655e3758fE` |
| Synthra QuoterV2 shim | `0xC703139b5C7EA26D906fcd6d335798d2EC9A1262` |
| Chainlink Verifier Proxy | `0x72790f9eB82db492a7DDb6d2af22A270Dcc3Db64` |

## Robinhood Chain Mainnet (chain 4663)

Sherwood protocol contracts are **pending deploy** — only externals are wired.
USDG is the canonical stable (no USDC on this chain). Chainlink **push feeds**
(AggregatorV3, 8 decimals) price the portfolio.

| Contract | Address |
|----------|---------|
| USDG (canonical stable, 6 decimals) | `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` |
| WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` |
| Uniswap V3 Factory | `0x1f7d7550b1b028f7571e69a784071f0205fd2efa` |
| Uniswap V3 SwapRouter02 | `0xcaf681a66d020601342297493863e78c959e5cb2` |
| Uniswap V3 QuoterV2 | `0x33e885ed0ec9bf04ecfb19341582aadcb4c8a9e7` |
| Uniswap V4 PoolManager | `0x8366a39cc670b4001a1121b8f6a443a643e40951` |
| Uniswap V4 Quoter | `0x8dc178efb8111bb0973dd9d722ebeff267c98f94` |
| Chainlink ETH/USD feed | `0x78F3556b67E17Df817D51Ef5a990cDaF09E8d3A9` |
| Chainlink USDG/USD feed | `0x61B7e5650328764B076A108EFF5fa7282a1B9aD2` |

Tokenized stocks (AAPL/TSLA/NVDA/AMD have verified default v4 routes; others need
`--swap-routes`) and their Chainlink push feeds are wired in
`cli/src/lib/addresses.ts` (`ROBINHOOD_TOKENS` / `ROBINHOOD_CHAINLINK`).

## HyperEVM Mainnet

| Contract | Address |
|----------|---------|
| SyndicateFactory | `0xd05Ae0E8bcf13075C29817c805d6Cc14F214393a` |
| SyndicateGovernor | `0x67AD3D5F3d127Ef923Fd6f67b178633c408D3fd3` |
| GuardianRegistry (stub, beta) | `0x8b5710EB4e2fA639F364Dcc3F3B30c8f12F460b9` |
| BatchExecutorLib | `0x2c454bEF1b09c8a306a7058b8B510bF0DfF7179D` |
| SyndicateVaultImpl | `0x2cbBe36Cf907A2BB410bacB0e4Fd632C7b012846` |
| USDC | `0xb88339CB7199b77E23DB6E890353E22632Ba630f` (6 decimals) |
| HyperliquidPerpStrategy | `0xC0fA169fdbBb3638AdE917A5B8A9A87caf90d91e` |
| HyperliquidGridStrategy | `0x20348e428050031647d671F0e24752C01D4b7379` |

HyperEVM has no Moonwell, Uniswap, Venice, Aerodrome, ENS, or ERC-8004 — the factory accepts `address(0)` for `ensRegistrar` and `agentRegistry`. Beta-mode deploy uses `MinimalGuardianRegistry` (no WOOD, no review/slashing) — full GuardianRegistry will replace it via owner-only `setGuardianRegistry()` once WOOD ships.

V1.5 redeploy (PR #282 / `chore/redeploy-beta-v1.5`): old proxies (factory `0x7e7F…48d3`, governor `0x915F…7C21`, registry `0x121A…4069`, vault impl `0xB454…ECba`, executor `0xbEDa…9F5E`) remain on-chain for historical / settle-out access but are no longer surfaced through the CLI or dashboard.

## ERC-8004 Agent Identity (for hand-built calldata)

Minted on **Base only**; HyperEVM / Robinhood syndicates reference the
Base-minted token id.

| Contract | Base Mainnet |
|----------|--------------|
| IdentityRegistry | `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` |
| ReputationRegistry | `0x8004BAa17C55a88189AE136b182e5fdA19dE9b63` |

A mint is a single `register(string agentURI, (string metadataKey, bytes metadataValue)[] metadata)`
(selector `0x8ea42286`) with `metadata = []` and `agentURI` a base64
`data:application/json;base64,…` URI carrying the ERC-8004 registration JSON
(`{ "type": "https://eips.ethereum.org/EIPS/eip-8004#registration-v1", "name", "description", "services": [], "active": true, "x402Support": false }`).
`sherwood --calldata-only identity mint` or `GET /prepare/identity-mint` emit it for you.

## EAS (Ethereum Attestation Service)

Base predeploys:

| Contract | Address |
|----------|---------|
| EAS | `0x4200000000000000000000000000000000000021` |
| SchemaRegistry | `0x4200000000000000000000000000000000000020` |

Coordination attestations (join requests / approvals) always live on **Base**,
even for syndicates on another chain. `attest` selector is `0xf17325e7`.

Base mainnet schema UIDs (also in `cli/src/lib/addresses.ts`; register via `cli/scripts/register-eas-schemas.ts`):

| Schema | UID | Data |
|--------|-----|------|
| SYNDICATE_JOIN_REQUEST | `0x1e7ce17b16233977ba913b156033e98f52029f4bee273a4abefe6c15ce11d5ef` | `uint256 syndicateId, uint256 agentId, address vault, string message` |
| AGENT_APPROVED | `0x1013f7b38f433b2a93fc5ac162482813081c64edd67cea9b5a90698531ddb607` | `uint256 syndicateId, uint256 agentId, address vault` |

`sherwood --calldata-only syndicate join` / `… approve` and `GET /prepare/join` /
`/prepare/approve-agent` emit these so you never ABI-encode `attest` by hand.
Resolve a `syndicateId` from a vault or subdomain with
`GET /syndicates/resolve?chain=8453&vault=0x...` — the vault has no
`syndicateId()` getter, so resolution goes through the factory.

## Strategy Templates (Base Mainnet)

ERC-1167 clonable singletons. Use `sherwood strategy list` to see current addresses.

| Template | Address |
|----------|---------|
| MoonwellSupplyStrategy | `0xb9Cd6d6720fc224508A07f0e43254A3cD65770E0` |
| AerodromeLPStrategy | `0x6fba9a6D3F40AA1848Ad196564B27a430D29FdB0` |
| VeniceInferenceStrategy | `0x0dDFf301F8AeB9B95627277f70bb6824CEFf5dF3` |
| WstETHMoonwellStrategy | `0x23d145Bd100599C7418164FEae235bcE391Ae032` |
| MamoYieldStrategy | `0x73b9cdC8cAf8853AfE299E144A40e3D51E399463` |
| PortfolioStrategy | `0x42069e51c415f4BF4442D80F1532Bd38140Bd135` |
| UniswapSwapAdapter | `0x679400a781A66d801C20DfD9E0020704e21e9d54` |

These V1.5 templates implement `IStrategy.onLiveDeposit` + `_positionValue`. MoonwellSupply, WstETHMoonwell, and the Hyperliquid templates report live NAV (`valid=true`) — the vault stays unlocked at fair NAV during their active proposals. Aerodrome / Venice / Mamo report `valid=false` and route through the async-redeem queue (live NAV deferred per pre-mainnet punchlist).

Old V1 addresses (kept on-chain for in-flight settle-out only): MoonwellSupply `0x649f…9F00`, AerodromeLP `0x6ccd…26CE`, VeniceInference `0x49BF…E41b`, WstETHMoonwell `0xA318…D1e6`, MamoYield `0x9ca8…DF42`, Portfolio `0x7865…3f64`.

## Uniswap Trading API

The `sherwood trade` commands use the hosted Uniswap Trading API (not direct contract calls):

| Resource | Value |
|----------|-------|
| API Base URL | `https://trade-api.gateway.uniswap.org/v1` |
| Developer Portal | https://developers.uniswap.org/ |
| Auth Header | `x-api-key: <your-key>` |
| Router Version Header | `x-universal-router-version: 2.0` |

Configure via: `sherwood config set --uniswap-api-key <key>` or `UNISWAP_API_KEY` env var.

The API routes through Uniswap V2/V3/V4 pools and UniswapX (PRIORITY on Base for MEV protection). No manual pool/fee selection needed.

## Allowlist Targets by Strategy

### Levered Swap (Moonwell + Uniswap)

```bash
sherwood vault add-target --target 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913  # USDC
sherwood vault add-target --target 0x4200000000000000000000000000000000000006  # WETH
sherwood vault add-target --target 0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22  # Moonwell mUSDC
sherwood vault add-target --target 0x628ff693426583D9a7FB391E54366292F509D457  # Moonwell mWETH
sherwood vault add-target --target 0xfBb21d0380beE3312B33c4353c8936a0F13EF26C  # Moonwell Comptroller
sherwood vault add-target --target 0x2626664c2603336E57B271c5C0b26F421741e481  # Uniswap SwapRouter
```

### Aerodrome LP (Strategy Template)

```bash
sherwood vault add-target --target 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43  # Aerodrome Router
sherwood vault add-target --target 0x940181a94A35A4569E4529A3CDfB74e38FD98631  # AERO Token
sherwood vault add-target --target <strategy-clone-address>                      # Your strategy contract
sherwood vault add-target --target <gauge-address>                               # Pool-specific gauge
sherwood vault add-target --target <lp-token-address>                            # Pool LP token
```

### Moonwell Supply (Strategy Template)

```bash
sherwood vault add-target --target 0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22  # Moonwell mUSDC
sherwood vault add-target --target 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913  # USDC
sherwood vault add-target --target <strategy-clone-address>                      # Your strategy contract
```

### Venice Inference (Strategy Template)

```bash
sherwood vault add-target --target 0xacfe6019ed1a7dc6f7b508c02d1b04ec88cc21bf  # VVV token
sherwood vault add-target --target 0x321b7ff75154472b18edb199033ff4d116f340ff  # VVV Staking (sVVV)
sherwood vault add-target --target 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43  # Aerodrome Router (swap path only)
sherwood vault add-target --target <strategy-clone-address>                      # Your strategy contract
```
