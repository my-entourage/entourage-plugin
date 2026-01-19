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
| `README.md` | Added "Authentication & Security" section, documented split configuration |
| `examples/repos.json.example` | Removed token fields and path fields |
| `examples/paths.local.json.example` | NEW - template for local path mappings |
| `skills/github-repo-check/SKILL.md` | Reference `.env.local` for tokens |
| `skills/linear-check/SKILL.md` | Reference `.env.local` for tokens |
| `skills/linear-sync/SKILL.md` | Reference `.env.local` for tokens |
| `skills/local-repo-check/SKILL.md` | Updated to read both repos.json and paths.local.json |
| Test fixtures (11 files) | Split `path` into separate `paths.local.json` files |

---

## New Configuration Pattern

### `.entourage/repos.json` (safe to commit)
- Contains: team IDs, workspace slugs, repo names, GitHub identifiers
- Does NOT contain: tokens, API keys, secrets, or local filesystem paths

### `.entourage/paths.local.json` (never committed)
- Contains: mapping of repo names to local filesystem paths
- Must be in `.gitignore`

### `.env.local` (never committed)
- Contains: `LINEAR_API_TOKEN`, `GITHUB_TOKEN`
- Must be in `.gitignore`

---

## Additional Change: Split Configuration

Separated shared config from personal paths:

| File | Contains | Committed? |
|------|----------|------------|
| `repos.json` | GitHub repos, Linear team, repo names | Yes |
| `paths.local.json` | Local filesystem paths | No |

This allows teams to share project configuration while each member customizes local paths.

**Files updated:**
- `examples/repos.json.example` - removed `path` field from repos
- `examples/paths.local.json.example` - new file for local path mappings
- `README.md` - documented split configuration pattern
- `skills/local-repo-check/SKILL.md` - updated to read both config files
- All test fixtures - split `path` into separate `paths.local.json`

---

## Verification

1. `examples/repos.json.example` has no token fields
2. `examples/repos.json.example` has no `path` fields in repos
3. `examples/paths.local.json.example` exists with path mappings
4. README documents both security hierarchy and split configuration
5. Skills work with MCP (primary) or env vars (fallback)
