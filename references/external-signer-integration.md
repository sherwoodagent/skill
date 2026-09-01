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
