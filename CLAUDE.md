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

Sherwood's launch target is **Robinhood Chain mainnet (4663)**. `SKILL.md` and the sub-skills are written for it. Until the mainnet deploy is done, say plainly that Sherwood is not live there yet, and never publish a Sherwood mainnet address that is not in the protocol's `chains/4663.json`.

The Robinhood mainnet fork (a Tenderly vnet, chain 9994663) hosted the beta, which has ended. Do not present it as the default chain or add new instructions for it. Robinhood testnet (46630) runs pre-v1 contracts the CLI cannot talk to — do not document it.

Do not re-add Base / Base Sepolia / HyperEVM / hyperevm-testnet as deployment targets without an explicit decision in the PR. Frame it as "Sherwood deploys on Robinhood chains", never "Base/HyperEVM support removed".
