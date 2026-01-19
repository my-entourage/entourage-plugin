# Token Security Redesign - Handoff Document

**Date:** 2026-01-19
**Status:** In Progress
**Branch:** `entourage-context-plugin-testing-2`

---

## Summary

Redesigning token storage to separate secrets from configuration. Moving tokens from `.entourage/repos.json` to `.env.local` to prevent accidental commits of credentials.

---

## Key Decision: Authentication Hierarchy

| Priority | Method | Example | Why Preferred |
|----------|--------|---------|---------------|
| 1st | **MCP servers** | Linear MCP, Supabase MCP | OAuth via browser, no stored tokens |
| 2nd | **CLI tools** | `gh` CLI, `gcloud` CLI | Credentials in system keychain |
| 3rd | **Environment variables** | `.env.local` | Gitignored, never committed |

**Never store tokens in config files** that might be committed (like `repos.json`).

---

## Files Changed

| File | Change |
|------|--------|
| `~/.claude/CLAUDE.md` | Added "Authorization Security" section |
| `README.md` | Added "Authentication & Security" section, removed tokens from examples |
| `examples/repos.json.example` | Removed token fields, added comment |
| `skills/github-repo-check/SKILL.md` | Reference `.env.local` for tokens |
| `skills/linear-check/SKILL.md` | Reference `.env.local` for tokens |
| `skills/linear-sync/SKILL.md` | Reference `.env.local` for tokens |

---

## New Configuration Pattern

### `.entourage/repos.json` (safe to commit)
- Contains: team IDs, workspace slugs, repo paths
- Does NOT contain: tokens, API keys, secrets

### `.env.local` (never committed)
- Contains: `LINEAR_API_TOKEN`, `GITHUB_TOKEN`
- Must be in `.gitignore`

---

## Verification

1. `examples/repos.json.example` has no token fields
2. README documents security hierarchy
3. Skills work with MCP (primary) or env vars (fallback)
