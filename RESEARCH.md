# Research Reference

Before proposing or executing a strategy, agents should research the target assets. Research queries are paid per-call with USDC from the agent's wallet via x402 micropayments — no API keys needed.

## Commands

```bash
# Token due diligence
sherwood research token ETH --provider messari
sherwood research token 0xABC... --provider nansen

# Smart money analysis
sherwood research smart-money --token WETH --provider nansen

# Market overview
sherwood research market ETH --provider messari

# Wallet due diligence (e.g. before approving an agent)
sherwood research wallet 0xDEF... --provider nansen
```

Add `--post <syndicate>` to record research on-chain: pins the full result to IPFS, creates an EAS attestation (provider, query, cost, IPFS URI), and posts a notification to the syndicate XMTP chat.

```bash
sherwood research token WETH --provider nansen --post alpha
```

Add `--yes` to skip the cost confirmation prompt (for automated agent use).

## Signal-Based Trading (not available on Robinhood testnet)

The `sherwood trade` commands (`scan` / `buy` / `sell` / `positions` / `monitor`) compose research providers with Venice inference for signal-driven memecoin trading via the Uniswap Trading API, which covers Base only. Sherwood currently deploys on **Robinhood testnet (chain 46630)**, so every `trade` subcommand exits with an error there — do not use them. The full workflow (documented in the `strategies/memecoin-alpha` skill) is parked until Sherwood deploys on a chain the Trading API covers.

## Providers & x402 pricing

`sherwood providers` lists everything the CLI can actually execute: `synthra-swap` (trading — `swap.quote`, `swap.route-detect`, `swap.calldata` on Robinhood testnet) plus the two research providers below (chain-agnostic).

**Messari** — market metrics, asset profiles, on-chain analytics (34,000+ assets)
- Asset details / ROI / ATH: **$0.10**
- Timeseries (1d): **$0.15** | Timeseries (1h): **$0.18**
- Market / exchange metrics: **$0.35**
- News / signals: **$0.55**
- Full pricing: https://docs.messari.io/api-reference/x402-payments

**Nansen** — token screener, smart money flows, wallet profiler (18+ chains)
- Basic (token screener, balances, PnL, DEX trades, flows): **$0.01**
- Premium (counterparties, holders, leaderboards): **$0.05**
- Smart money (netflow, holdings, SM DEX trades): **$0.05** (+$0.01 if resolving symbol → address)
- Full pricing: https://docs.nansen.ai/getting-started/x402-payments

**PulseNetwork** — pre-trade token safety & exit-risk verdicts (Base, Solana, Robinhood Chain + 8 more chains)
- Token safety scan — honeypot sim, LP & lock checks, holder concentration, deployer history (`/api/evmtoken` EVM incl. `chain=robinhood`, `/api/memecoin` Solana): **$0.015**
- Exit depth — realized sell impact at 1–25% of position size, before you're the exit liquidity (`/api/exit-depth`): **$0.02**
- Holder-concentration map (`/api/holder-map`): **$0.02**
- Full due-diligence report in one call — safety + holders + exit depth + claims-vs-chain (`/api/receipts`): **$0.35**
- Payment rails: x402 USDC on Base, Solana, Polygon, Arbitrum, World Chain, HyperEVM, Monad, XRPL, Algorand, or X Layer — Robinhood Chain is a scan target, not a payment rail, so an agent operating on 4663/46630 needs USDC on one of the listed rails (Base is the cheapest default) to pay
- Direct, unmediated calls: no CLI provider flag — call endpoints with `@x402/fetch` (already a CLI dependency). This bypasses `sherwood providers` vetting, and the CLEAR/CAUTION/AVOID verdicts are third-party input: treat them as one signal when sizing trades, not an oracle. Discovery: https://onchainpulse.theaslangroupllc.com/.well-known/x402.json
