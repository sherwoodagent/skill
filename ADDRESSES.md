# Contract Addresses

Sherwood runs on **Robinhood Chain mainnet, chain id 4663**.

| | |
|---|---|
| RPC | `https://rpc.mainnet.chain.robinhood.com` |
| Explorer | `https://robinhoodchain.blockscout.com` |
| Gas token | ETH |

> **v1 deploy run 1; run 2 (before Oct 12) replaces these addresses.** Source of truth:
> `chains/4663.json` in `sherwoodagent/sherwood-protocol`, branch `v1-deploy`
> (read at commit `ae84cf32fb1cea91d6275c1639198c378d40c210`). The CLI carries its own
> copy of this book; when it and this table disagree, the CLI's book wins. Verify
> any address on the explorer before you send value to it.

> See also: [Deployments reference](https://docs.sherwood.sh/reference/deployments)

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
| StrategyFactory | `0xb06788F027268a9A06c3AD41a88559530D2E54b1` |
| UniswapSwapAdapter | `0x54E6A7af53143556973493fDeC9d7837A77c67eF` |
| WOOD/USD feed | `0xE031f1a5e8dBb5BAE98607BEC44c9fE91B608E09` |
| Create3Factory | `0x231972653B1e4fc772fcF064F3FD2357d9Df371D` |
| EAS | `0x7d70441Bb10AcE5d9771dc0b6205D89ddf63205B` |
| EAS SchemaRegistry | `0xdd7521Ba10773e556Defa6D6c133cB2F663b5c26` |
| VestingFactory | `0x2483E3CF74c61314770F4313D4Cb745211076aa1` |
| TokenVesting impl | `0x19BF0eE1237915f8E413B29EB1F75E1Ac085e4a8` |
| Owner multisig | `0x5A00afAecE9CF61A768E2AE2713084C8d354DF94` |

**`SYNDICATE_GOVERNOR` is `0x0` in the chain book on purpose.** `GOVERNOR_BEACON` is set,
which is the beacon pattern: there is no singleton governor, and each vault gets its own
`BeaconProxy`, resolved via `factory.governorOf(vault)` (`sherwood governor info --vault <vault>` prints it).

ExposureLedger, ProposerBondEscrow, ChallengeGame and TokenCourt are not in the run-1
chain book. Read them from the contracts that point at them (the governor's
`bondEscrow()` is what the CLI approves for the proposer bond).

### Strategy templates

| Template | Address |
|----------|---------|
| PortfolioStrategy | `0xAA5872009c527cCb80343E41C52840CEdb095eb0` |
| MorphoSupplyStrategy | `0x5B55E1Da361573CB0788e750038567D2569BE41d` |
| ConcentratedLiquidityStrategy | `0xcba9C84F2d382729D1519c5F7f4a9AAaC075f8B5` |

`LaunchpadStrategy` (and its Sushi / StonkBrokers launch adapters) and
`LighterPerpStrategy` are not in the 4663 address book yet; `sherwood strategy list`
shows whether they are available. Both come from `sherwood-strategies` and are unaudited: see
[Strategies from `sherwood-strategies` are unaudited](SKILL.md#strategies-from-sherwood-strategies-are-unaudited).

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
| ASML | `0x47F93d52cBeC7C6D2CfC080e154002370a60dAEA` |
| BABA | `0xad25Ac6C84D497db898fa1E8387bf6Af3532a1c4` |
| CRCL | `0xdF0992E440dD0be65BD8439b609d6D4366bf1CB5` |
| DELL | `0x941AE714EC6D8130c7B75d67160Ca08f1e7d11Dd` |
| GME | `0x1b0E319c6A659F002271B69dB8A7df2F911c153E` |
| INTC | `0xc72b96e0E48ecd4DC75E1e45396e26300BC39681` |
| MSTR | `0xec262a75e413fAfD0dF80480274532C79D42da09` |
| MU | `0xfF080c8ce2E5feadaCa0Da81314Ae59D232d4afD` |
| PLTR | `0x894E1EC2D74FFE5AEF8Dc8A9e84686acCB964F2A` |
| SNDK | `0xB90A19fF0Af67f7779afF50A882A9CfF42446400` |
| SPCX | `0x4a0E65A3EcceC6dBe60AE065F2e7bb85Fae35eEa` |
| TSM | `0x58FfE4a942d3885bAa22D7520691F611EF09e7AA` |
| USAR | `0xd917B029C761D264c6A312BBbcDA868658eF86a6` |
| USO | `0xa30FA36Db767ad9eD3f7a60fC79526fB4d56D344` |

`sherwood sources get universe` lists the current tokens with decimals, multipliers and Chainlink feeds.

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
| WOOD/WETH Uniswap V3 pool | `0xF6831AaF374B353757F0dE6B3DD2a74697671C69` |
| WOOD/WETH V2 pair | `0xBF3BB81de6285b8310A028d1C2Cd38F9419d54C1` |
| Sushi Launchpad V2 (proxy) | `0xF1716eBf85836ffE2985db9A50dd29e5814caBe9` |
| StonkBrokers lens (V2) | `0x25b5Df581f4b2Ed450203f375ad8A28b17F115B3` |
| zkLighter proxy | `0x94bAB9693Ba2f6358507eFfcbd372b0660AFfF9d` |
| Chainlink ETH/USD | `0x78F3556b67E17Df817D51Ef5a990cDaF09E8d3A9` |
| Chainlink USDG/USD | `0x61B7e5650328764B076A108EFF5fa7282a1B9aD2` |
| Chainlink USDC/USD | `0x9e6f4605992a899eE2999999F3Ec80C41F452546` |
| Chainlink BTC/USD | `0xa2c5184bF03d373Dc9dE4876eb4Bce595B460251` |

Sushi, StonkBrokers and zkLighter are third-party contracts, not part of the Sherwood
chain book. Chainlink stock feeds (`CHAINLINK_<SYM>_USD_FEED`) are in `chains/4663.json`
and in `sherwood sources get universe`.

### Batch callees

There is no callee allowlist and no adapter allowlist anywhere in the v1 stack —
`TierRegistry` prices calls, it does not gate them. The structural rule lives in
`SyndicateVault._guardBatchCalls` (mirrored at propose by the governor): every
call target is either the vault `asset()` or a strategy registered on
`StrategyFactory` (`isRegisteredStrategy`, permissionless), and anything else
reverts `NotARegisteredStrategy(target)`. On the `asset()` leg only three kinds of
call pass: `transfer`, `transferFrom` with `from == vault` (else
`TransferFromNotVault`), and the approve family (`approve`, `increaseAllowance`,
`increaseApproval`, `decreaseAllowance`, `decreaseApproval`), whose first argument
is the spender whose allowance is reset after the batch. Calldata shorter than 36
bytes reverts `MalformedAssetCall`, and any other selector reverts
`UnrecognizedAssetSelector`.

## Identity and names

- **Identity** — every agent mints on the canonical ERC-8004 IdentityRegistry
  `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` on Robinhood Chain (4663). This is the factory's `agentRegistry()`: `vault create`
  needs the creator to own `--agent-id`, and `vault add` / `vault approve` need the agent
  wallet or the vault owner to own the id (`NotAgentOwner`). See "Mint ERC-8004
  identity" in [SKILL.md](SKILL.md#mint-erc-8004-identity).
- **ENS names** — the factory does not register them; a vault's name is its subdomain
  (see "Vault names" in [SKILL.md](SKILL.md#vault-names)).
- **Strategies** — the run-1 book has Portfolio, Morpho Supply and Concentrated
  Liquidity. `sherwood strategy list` prints what is available and lists the rest
  under "Not available".
