# Research Reference

Before proposing or executing a strategy, agents should research the target assets. Research queries are paid per call via x402 in **USDC on Base (chain 8453)** from the agent's wallet — no API keys, no vault funds, nothing on 4663. Fund the paying wallet with USDC on Base; it needs no ETH there.

**Owner approval before each spend.** Show the cost, provider and paying wallet, and wait for the owner's yes before every call. `--yes` skips only the CLI's prompt, and only for spend the owner already approved.

## Sign-only wallets: the two-step

x402 signs EIP-712 typed data (EIP-3009 `TransferWithAuthorization`), so the wallet must support `eth_signTypedData_v4`: Privy does (`$P rpc`), and the MetaMask Agent Wallet does through `{{MM_SIGN_TYPED_DATA}}`. No private key is needed.

```bash
# Step 1: confirms cost, catches the 402, prints the typed data, then waits (default 600s, --timeout <s>)
sherwood research token TSLA --provider messari --address <wallet> --yes --json > /tmp/x402.log 2>&1 &
jq '.x402_signature_request' /tmp/x402.log
#   { wallet, provider, cost_usdc, chain_id: 8453, typed_data: {domain,types,primaryType,message}, deadline }
#   also at ~/.sherwood/x402-signing/<wallet, lowercase>.request.json
#   sign typed_data unchanged: MetaMask {{MM_SIGN_TYPED_DATA}}; Privy eth_signTypedData_v4
# Step 2: hands the signature to step 1, which pays, retries and prints the result
sherwood research complete --signature 0x… [--address <wallet>]
```

Step 2 exits 1 with the reason when no step 1 is waiting or the deadline has passed. Under `--calldata-only` without `--address`, `research` refuses and names this two-step. A configured private key pays in one step (the commands below).

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

Add `--yes` to skip the cost confirmation prompt, only for spend the owner has already approved.

## Signal-Based Trading (not available on Robinhood chains)

The `sherwood trade` commands (`scan` / `buy` / `sell` / `positions` / `monitor`) compose research providers with Venice inference for signal-driven memecoin trading via the Uniswap Trading API, which covers Base only. Sherwood runs on Robinhood Chain (4663), which is not Base, so every `trade` subcommand exits with an error. Do not use them. The full workflow (documented in the `strategies/memecoin-alpha` skill) is parked until Sherwood deploys on a chain the Trading API covers.

## Providers & x402 pricing

`sherwood providers` lists the providers the CLI can execute, including the two research providers below (chain-agnostic). Vault swaps on 4663 go through the PortfolioStrategy's Uniswap adapter, not a provider.

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
