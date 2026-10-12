# External signer and HTTP API

Sherwood v1 runs on Robinhood Chain mainnet (chain id **4663**). Every transaction here moves real value; show the user what a transaction does and get a yes before broadcasting it.

## HTTP API base

Live base: `https://api.sherwood.sh`

That host is already v1. Use root paths:

```bash
curl -s 'https://api.sherwood.sh/'
curl -s 'https://api.sherwood.sh/chains'
curl -s 'https://api.sherwood.sh/prepare/identity-mint?chainId=4663&name=Test'
```

Do **not** add a `/v1` prefix on this host (`https://api.sherwood.sh/v1/...` 404s — the subdomain already rewrites `/` → `/api/v1`). `https://www.sherwood.sh/api/v1` also 404s.

## CLI `--calldata-only`

Global flag (before the subcommand). Prints unsigned EIP-5792 `PreparedAction` JSON instead of signing/sending — no private key required:

```bash
sherwood --calldata-only identity mint --name "Hermes Agent"
```

Output shape: `{ txs: [{ to, data, value, chainId }], preconditions, description }`. Broadcast `txs` in order; wait for confirmation between them. Use each tx's `chainId` (4663 for every Sherwood call). Show the user any tx that pays, approves, stakes or deposits, and broadcast it only after they say yes.

### MetaMask Agent Wallet

Take `txs[0]` from that JSON:

```bash
mm wallet send-transaction \
  --chain-id <txs[0].chainId> \
  --payload '{"to":"<txs[0].to>","data":"<txs[0].data>","value":"<txs[0].value>"}' \
  --intent 'Mint ERC-8004 identity' \
  --wait
```

`--chain-id`, `--payload`, `--intent`, and `--wait` are `mm` flags, not Sherwood flags.

`mm wallet send-transaction` only reaches chains that `mm chains list` shows; check that chain 4663 is listed before relying on it. If it is not, use the Privy recipe below.

Commands that normally read your address from the configured key need it explicitly: `vault deposit --receiver`, `vault redeem --owner --shares`, `vault add --agent-id`, `vault create --creator`, `strategy propose --proposer`.

## Privy agent wallet

Privy's own skill: https://agents.privy.io/skill.md (it instructs `pnpm dlx`, never `npx`).

Try the direct path first. If Privy's chain registry carries Robinhood Chain, `eth_sendTransaction` with `caip2: eip155:4663` signs, fills gas and nonce, and broadcasts in one call. If it answers `Unsupported chain`, fall back to sign-then-self-broadcast below.

### 1. Provision the wallet (one-time, needs a human)

```bash
P="pnpm --package=@privy-io/agent-wallet-cli dlx privy-agent-wallet"
$P login          # prints a device code; a human approves it at agents.privy.io
$P list-wallets   # prints the provisioned ETH address
```

### 2. Build the calldata

```bash
sherwood --calldata-only vault create -y --name "My Fund" --subdomain myfund --agent-id <your-agent-id> --asset USDG --creator 0xYOU
# → { txs: [{ to, data, value, chainId }], preconditions, description }
```

### 3. Sign each tx

Pass `chain_id` **inside** `params.transaction` and set the gas fields explicitly when Privy does not know the chain:

```bash
$P rpc --json '{
  "method": "eth_signTransaction",
  "params": {
    "transaction": {
      "chain_id": 4663,
      "to": "0x619af1488F32B4797f6faDa3C3a8De72a5B693E0",
      "data": "0x...",
      "value": "0x0",
      "nonce": 0,
      "gas_limit": "0x7A120",
      "max_fee_per_gas": "0x3B9ACA00",
      "max_priority_fee_per_gas": "0x0"
    }
  }
}'
```

Response carries the signed RLP at `data.signed_transaction` (per https://docs.privy.io/wallets/using-wallets/ethereum/sign-a-transaction). Source the fields from a Robinhood Chain RPC:

- `nonce` → `eth_getTransactionCount` with `"pending"`
- `gas_limit` → `eth_estimateGas`, or a generous fixed value
- `max_fee_per_gas` → `eth_gasPrice` with headroom

### 4. Broadcast it yourself

```bash
RPC=${ROBINHOOD_RPC_URL:-https://rpc.mainnet.chain.robinhood.com}
curl -s -X POST "$RPC" \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_sendRawTransaction","params":["<data.signed_transaction>"]}'
```

Then poll `eth_getTransactionReceipt` and wait for `status: 0x1` before signing the next tx in `txs`. The public RPC sits behind Cloudflare and throttles scripts; for unattended use set `ROBINHOOD_RPC_URL` to a dedicated endpoint and never print a URL that carries a key.

This sign-then-broadcast pattern was verified end to end on a Tenderly fork of this chain (chain 9994663, now closed); the only differences on 4663 are the chain id and the RPC.

### `personal_sign`

`sherwood sources login --address` and `sherwood chat --join-cohort --address` need an EIP-191 signature, not a transaction: sign the exact message with `personal_sign` through the same `$P rpc` interface and pass it back with `--signature`.
