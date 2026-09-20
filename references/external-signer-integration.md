# External signer and HTTP API

## HTTP API base

Live base: `https://api.sherwood.sh`

That host is already v1. Use root paths:

```bash
curl -s 'https://api.sherwood.sh/'
curl -s 'https://api.sherwood.sh/chains'
curl -s 'https://api.sherwood.sh/prepare/identity-mint?chainId=8453&name=Test'
```

Do **not** add a `/v1` prefix on this host (`https://api.sherwood.sh/v1/...` 404s — the subdomain already rewrites `/` → `/api/v1`). `https://www.sherwood.sh/api/v1` also 404s.

## CLI `--calldata-only`

Global flag (before the subcommand). Prints unsigned EIP-5792 `PreparedAction` JSON instead of signing/sending — no private key required:

```bash
sherwood --calldata-only identity mint --name "Hermes Agent"
```

Output shape: `{ txs: [{ to, data, value, chainId }], preconditions, description }`. Broadcast `txs` in order; wait for confirmation between them. Use each tx's `chainId` (CLI default is robinhood-fork `9994663`).

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

Commands that normally read your address from the configured key need it explicitly: `vault deposit --receiver`, `vault redeem --owner --shares`, `syndicate add --agent-id`, `strategy propose --proposer`.

## Privy agent wallet (Robinhood fork)

The only wallet API verified to work on chain 9994663. MetaMask Agent Wallet, MoonPay and OKX agent wallets reject the custom chain ID / RPC. Privy's own skill: https://agents.privy.io/skill.md (it instructs `pnpm dlx`, never `npx`).

Privy **cannot broadcast** to this fork, so the pattern is sign-then-self-broadcast.

### 1. Provision the wallet (one-time, needs a human)

```bash
P="pnpm --package=@privy-io/agent-wallet-cli dlx privy-agent-wallet"
$P login          # prints a device code; a human approves it at agents.privy.io
$P list-wallets   # prints the provisioned ETH address
```

### 2. Build the calldata

```bash
sherwood --calldata-only syndicate create -y --name "My Fund" --subdomain myfund --agent-id 0
# → { txs: [{ to, data, value, chainId }], preconditions, description }
```

### 3. Sign each tx

Pass `chain_id` **inside** `params.transaction` and set the gas fields explicitly. Privy auto-fills gas and nonce only for chains it knows, and 9994663 is not one of them:

```bash
$P rpc --json '{
  "method": "eth_signTransaction",
  "params": {
    "transaction": {
      "chain_id": 9994663,
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

Response carries the signed RLP at `data.signed_transaction` (per https://docs.privy.io/wallets/using-wallets/ethereum/sign-a-transaction). Source the fields from the fork RPC:

- `nonce` → `eth_getTransactionCount` with `"pending"`
- `gas_limit` → `eth_estimateGas`, or a generous fixed value
- `max_fee_per_gas` → `eth_gasPrice` with headroom

### 4. Broadcast it yourself

```bash
curl -s -X POST https://virtual.robinhood-chain.eu.rpc.tenderly.co/moonwell/wormhole-bridge/f509bc-4fdefe \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_sendRawTransaction","params":["<data.signed_transaction>"]}'
```

Then poll `eth_getTransactionReceipt` and wait for `status: 0x1` before signing the next tx in `txs`.

Proof the pattern works: dust self-send `0xb3e608fe664b51126e9ec0b421a0b6d1341afc1cbb0738780593a63f40d9299d` on the fork (status 1, 21k gas).

### Do not use `eth_sendTransaction` here

```bash
# FAILS: {"error":"Unsupported chain"}
$P rpc --json '{"method":"eth_sendTransaction","caip2":"eip155:9994663","params":{"transaction":{...}}}'
```

Privy's chain registry does not carry 9994663, so the `caip2` send path is unavailable on this fork. `personal_sign` works normally.

### Identity mint on Robinhood mainnet (4663)

`sherwood identity mint` is the one step that touches Robinhood **mainnet** and needs a small amount of **real** ETH. The signing shape is the same, with `chain_id: 4663` and the broadcast pointed at `https://rpc.mainnet.chain.robinhood.com`. **This path was not separately smoke-tested** — only the 9994663 fork flow above was verified end to end.
