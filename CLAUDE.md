# CLAUDE.md — Sherwood Skill

This file is for any agent (Claude Code, Codex, etc.) that opens a PR against this repo.

## What this repo is

The Sherwood agent skill pack — installed by users via `npx skills install sherwoodagent/skill` (Claude Code) or via the bundled hermes-plugin's skill bundle. Source of truth for the agent-facing behavior of every Sherwood CLI command.

## Version-bump checklist (REQUIRED on every release-bumping PR)

When bumping any of:
- `.claude-plugin/plugin.json` `version` field (this skill's own version)
- The pinned Sherwood CLI version (`@sherwoodagent/cli@X.Y.Z` in `SKILL.md`)
- The pinned Hermes plugin version (`sherwoodagent/sherwood-hermes-plugin@vX.Y.Z` in `SKILL.md`)

…the PR MUST also touch every spot the version is referenced. Today those are:

| File | Pin | What it controls |
|---|---|---|
| `.claude-plugin/plugin.json` | `version` | Skill plugin manifest |
| `SKILL.md` install section (Option A) | `@sherwoodagent/cli@X.Y.Z` | npm install command for the CLI |
| `SKILL.md` "Running on Hermes Agent" → Install | `sherwood-hermes-plugin@vX.Y.Z` | Hermes plugin install command |

Sub-skills under `skills/*/SKILL.md` carry their OWN `version` frontmatter — bump those independently when their behavior changes.

## When to bump the CLI pin in this repo

After a CLI release lands on `main` of `sherwoodagent/sherwood` and is published to npm. Pull the version from `cli/package.json` in that repo. Do NOT track `@latest` — agents need a deterministic install for reproducibility.

## When to bump the Hermes plugin pin in this repo

After a release lands on `main` of `sherwoodagent/sherwood-hermes-plugin` and a git tag (e.g. `v0.5.0`) exists. Pull the version from `plugin.yaml` in that repo.

## Chain: Robinhood Chain mainnet (4663)

Sherwood runs on **Robinhood Chain mainnet (4663)**, the CLI's default and only network. `SKILL.md` and the sub-skills are written for it. Never publish a Sherwood address that is not in the protocol's `chains/4663.json` (branch `v1-deploy` until it merges), and label the address book with the deploy run it came from.

Do not add instructions for any other chain id, a fork or a testnet. Do not re-add Base / Base Sepolia / HyperEVM as deployment targets without an explicit decision in the PR. Base appears only as the chain x402 research payments settle on (USDC on Base).

Wallets: the MetaMask Agent Wallet is the first choice, Privy the second; both are sign-only (`--calldata-only`).
