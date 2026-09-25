# Contract Addresses

Sherwood's chain of record is the **Robinhood mainnet fork — a Tenderly vnet, chain
9994663**, and the CLI targets it by default. The CLI resolves the same book at
runtime. The vnet is ephemeral and carries no real value.

> See also: [Deployments reference](https://docs.sherwood.sh/reference/deployments)

> **Robinhood mainnet (chain 4663) is not listed here.** No Sherwood core address
> exists on it yet — the addresses land after the deployment ceremony. Do not reuse
> this table on 4663. The one thing that
> *is* live on 4663 is the canonical ERC-8004 IdentityRegistry, which is not a
> Sherwood contract — see "Not active on the fork" below.

## Robinhood mainnet fork — Tenderly vnet (chain 9994663)

> **An ephemeral test network, not a public chain.** This vnet is a Tenderly fork of
> Robinhood mainnet, reachable only through its own RPC URL. Every address below dies
> when the vnet is re-minted, and a fresh fork gets a whole new table. Do not stake,
> fund, or route real value here, and never treat these as Robinhood mainnet (4663)
> addresses. Source of truth: `chains/9994663.json` in `sherwoodagent/sherwood-protocol`.

Public RPC (a Sherwood proxy: reads and `eth_sendRawTransaction` only, no
impersonation or cheat methods, batches capped at 50):
`https://api.sherwood.sh/tenderly/rpc`

Need test ETH / WOOD / USDG? Claim from the beta faucet, documented under
"Get test funds" in [SKILL.md](SKILL.md#get-test-funds).

Fork of Robinhood *mainnet*, so the venues and tokens are the real ones: USDG as the
vault asset, official Uniswap v3/v4, Morpho Blue, Chainlink **push** feeds
(`VERIFIER_PROXY = 0`, so PortfolioStrategy runs in push-feed mode and feed ids are
AggregatorV3 proxy addresses). The WOOD/USD source is a **fork fixture** priced off
the fork's own WOOD/WETH reserves times the live ETH/USD answer — not a market feed.

### Core

| Contract | Address |
|----------|---------|
| SyndicateFactory | `0x619af1488F32B4797f6faDa3C3a8De72a5B693E0` |
| GovernorBeacon | `0x3CF45eFE9fBDdd6cB749384Bf5c1bA5Ec96af05d` |
| ProtocolConfig | `0x8aDb5810B5bF8B9149BE3Ca45Cb441818a9679bB` |
| SyndicateVaultImpl | `0xdaB4707c9997a84e931FE98F4688adaFc70b6B95` |
| BatchExecutorLib | `0x899FC2Cac572F64A233344115b488E71E0044f34` |
| GuardianRegistry | `0xD8F9E7446E6d6c02198AAaF674A0C5e3d5D1BF72` |
| StakedWood (sWOOD) | `0xdDf2B4C52B9575e0e6D03a3A57D75D06a4a9e203` |
| TierRegistry | `0x4614f058920941A0a9a852e62485fbDE692D75E1` |
| ExposureLedger | `0x99D789E7C8E65dB5597dCa692F082B47BE30AB33` |
| ChallengeGame | `0x7046FececcA6c0f5E66Cc998099593ae71A1bbee` |
| TokenCourt | `0xC30bA62727be65fd867385Ce27Ff7C78bd66A897` |
| ProposerBondEscrow | `0x7d25058c891d3AC5C8bc8Da6aA937DFeE648B5cF` |
| StrategyFactory | `0xb06788F027268a9A06c3AD41a88559530D2E54b1` |
| UniswapSwapAdapter | `0x54E6A7af53143556973493fDeC9d7837A77c67eF` |
| WOOD/USD feed (fork fixture) | `0x0C2dA5FD01e42AE11CeB1d3149867b1896e23B6B` |
| Create3Factory | `0x231972653B1e4fc772fcF064F3FD2357d9Df371D` |

As on every chain, there is no singleton `SyndicateGovernor`: each vault gets its own
`BeaconProxy`, resolved via `factory.governorOf(vault)`.

### Strategy templates

| Template | Address |
|----------|---------|
| PortfolioStrategy | `0xAA5872009c527cCb80343E41C52840CEdb095eb0` |
| MorphoSupplyStrategy | `0x5B55E1Da361573CB0788e750038567D2569BE41d` |
| ConcentratedLiquidityStrategy | `0xcba9C84F2d382729D1519c5F7f4a9AAaC075f8B5` |
| LaunchpadStrategy | `0x4435Aae199907f60588902Bcd7c4363a13Bb2951` |
| SushiLaunchAdapter | `0x20348e428050031647d671F0e24752C01D4b7379` |
| StonkLaunchAdapter | `0x36C45dC52FbC267d8536E8456ADe5255eC83A5ab` |

The Launchpad template and adapters come from sherwood-strategies
`deployments/9994663.json`. `LighterPerpStrategy` is not deployed on any chain yet.

### Tokens

| Token | Address |
|-------|---------|
| USDG (vault asset, 6-dec) | `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` |
| WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` |
| WOOD | `0xF8BC08092C06dB6148114DCf82AF881F1085f92b` |
| AAPL | `0xaF3D76f1834A1d425780943C99Ea8A608f8a93f9` |
| TSLA | `0x322F0929c4625eD5bAd873c95208D54E1c003b2d` |
| NVDA | `0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC` |
| MSFT | `0xe93237C50D904957Cf27E7B1133b510C669c2e74` |
| AMZN | `0x12f190a9F9d7D37a250758b26824B97CE941bF54` |
| META | `0xc0D6457C16Cc70d6790Dd43521C899C87ce02f35` |
| GOOGL | `0x2e0847E8910a9732eB3fb1bb4b70a580ADAD4FE3` |
| AMD | `0x86923f96303D656E4aa86D9d42D1e57ad2023fdC` |
| SPY | `0x117cc2133c37B721F49dE2A7a74833232B3B4C0C` |
| QQQ | `0xD5f3879160bc7c32ebb4dC785F8a4F505888de68` |
| SLV | `0x411eFb0E7f985935DAec3D4C3ebaEa0d0AD7D89f` |

### External protocols

| Contract | Address |
|----------|---------|
| Uniswap V3 Factory | `0x1f7d7550b1b028f7571e69a784071f0205fd2efa` |
| Uniswap V3 PositionManager | `0x73991a25C818Bf1f1128dEAaB1492D45638DE0D3` |
| Uniswap SwapRouter | `0xcaf681a66d020601342297493863e78c959e5cb2` |
| Uniswap QuoterV2 | `0x33e885ed0ec9bf04ecfb19341582aadcb4c8a9e7` |
| Uniswap V4 PoolManager | `0x8366a39cc670b4001a1121b8f6a443a643e40951` |
| Uniswap V4 Quoter | `0x8dc178efb8111bb0973dd9d722ebeff267c98f94` |
| Morpho Blue | `0x9D53d5E3bd5E8d4Cbfa6DB1ca238AEA02E651010` |
| Sushi Launchpad V2 (proxy) | `0xF1716eBf85836ffE2985db9A50dd29e5814caBe9` |
| StonkBrokers lens (V2) | `0x25b5Df581f4b2Ed450203f375ad8A28b17F115B3` |
| zkLighter proxy (mainnet 4663; the fork has no sequencer) | `0x94bAB9693Ba2f6358507eFfcbd372b0660AFfF9d` |
| Chainlink ETH/USD | `0x78F3556b67E17Df817D51Ef5a990cDaF09E8d3A9` |
| Chainlink USDG/USD | `0x61B7e5650328764B076A108EFF5fa7282a1B9aD2` |

### Batch callees

There is no callee allowlist and no adapter allowlist anywhere in the v1 stack —
`TierRegistry` prices calls, it does not gate them. The structural rule lives in
`SyndicateVault._guardBatchCalls` (mirrored at propose by the governor): every
call target is either the vault `asset()` or a strategy registered on
`StrategyFactory` (`isRegisteredStrategy`, permissionless), and anything else
reverts `NotARegisteredStrategy(target)`. On the `asset()` leg, `transferFrom`
must have `from == vault` (else `TransferFromNotVault`), calldata shorter than 36
bytes reverts `MalformedAssetCall`, and any other selector's first argument is
read as the spender whose allowance is reset after the batch.

## Not active on the fork

- **On-chain identity gating** — identity itself IS live: every agent mints on the
  canonical ERC-8004 IdentityRegistry `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` on
  Robinhood mainnet (4663), the coordination chain. What is off is the factory-side
  check: `agentRegistry` is `address(0)` at v1, so `vault create` / `vault add` do not
  verify NFT ownership on-chain, and `agentId=0` is accepted when `--agent-id` is omitted.
- **ENS subnames** — no registrar; `vault create` skips ENS registration.
- **Strategies other than Portfolio, Morpho Supply, Concentrated Liquidity and
  Launchpad** — `sherwood strategy list` shows the rest under "Not available".
