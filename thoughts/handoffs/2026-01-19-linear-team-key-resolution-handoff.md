# Linear Team Key Resolution Fix

**Date:** 2026-01-19
**Branch:** `entourage-context-plugin-testing-2`
**Status:** Implementation complete, ready for testing

## Problem Summary

The Linear MCP's `team` parameter only accepts team **name** or **UUID**, but users naturally configure the team **key** (e.g., "ENT") because it's visible in issue identifiers like `ENT-51`. This caused queries to return empty results silently.

### Linear Terminology

| Term | Example | Where it appears |
|------|---------|-----------------|
| **Workspace slug** | "myentourage" | URL: `linear.app/myentourage/...` |
| **Team name** | "Entourage" | API response, display name |
| **Team key** | "ENT" | Issue IDs: `ENT-51`, `ENT-18`, etc. |
| **Team UUID** | "9a8d6764-..." | API response (`id` field) |

### What Linear MCP Accepts

| Identifier Type | Accepted by `team` param? |
|----------------|--------------------------|
| Team **name** | Yes |
| Team **UUID** | Yes |
| Team **key** | No (returns empty) |

## Solution Implemented

### 1. Skills Updated to Auto-Resolve Team Identifiers

Added team resolution logic to both skills:
- `/linear-check` - `skills/linear-check/SKILL.md`
- `/linear-sync` - `skills/linear-sync/SKILL.md`

**Resolution Flow:**
1. Call `list_teams` to get available teams
2. Match configured `teamName` against team name, key, or UUID
3. Use the matched team's `name` for all subsequent queries

### 2. Config Field Renamed for Clarity

Changed config field from `teamId` to `teamName` across:
- `README.md` - documentation and examples
- `skills/linear-check/SKILL.md` - config examples
- `skills/linear-sync/SKILL.md` - config examples
- Fixture files in `skills/*/evaluations/fixtures/*/`

**New config format:**
```json
{
  "linear": {
    "teamName": "TEAM",
    "workspace": "my-workspace"
  }
}
```

### 3. Duplicate MCP Removed

Removed the Linear MCP entry from plugin's `.mcp.json` since users should configure it at the user level (`~/.claude.json`).

### 4. CLAUDE.md Updated

Added "Key Insight: Team Identifiers" section to `~/.claude/CLAUDE.md` documenting:
- Different team identifier types
- What the MCP accepts vs rejects
- Best practices for skill development

Fixed incorrect `get_team` documentation that claimed it accepts team keys.

## Files Modified

| File | Change |
|------|--------|
| `skills/linear-check/SKILL.md` | Added team resolution step, renamed `teamId` → `teamName` |
| `skills/linear-sync/SKILL.md` | Added team resolution step, renamed `teamId` → `teamName` |
| `README.md` | Updated config examples and documentation |
| `~/.claude/CLAUDE.md` | Added team identifiers section, fixed `get_team` docs |
| `.mcp.json` | Removed Linear MCP entry |
| `skills/linear-check/evaluations/fixtures/with-config/.entourage/repos.json` | Renamed `teamId` → `teamName` |
| `skills/linear-sync/evaluations/fixtures/with-config/.entourage/repos.json` | Renamed `teamId` → `teamName` |
| `skills/linear-sync/evaluations/fixtures/upgrade-scenario/.entourage/repos.json` | Renamed `teamId` → `teamName` |

## Testing

### Verification Steps

1. Run `/linear-check authentication` with `teamName: "ENT"` in config
2. Verify it returns results (not empty)
3. Run `/project-status` and confirm Linear section shows data
4. Test with team name and UUID to ensure all formats work

### Expected Behavior

The skills should now:
1. Accept any team identifier format (name, key, UUID)
2. Automatically resolve to the correct team name via `list_teams`
3. Return actual issue data instead of empty results

## Migration Notes

Users with existing `.entourage/repos.json` files need to:
1. Rename `teamId` to `teamName`
2. No value change needed - existing values (keys, names, UUIDs) will all work

## Related

- Previous session: Token security redesign (`2026-01-19-token-security-redesign-handoff.md`)
- Plan file transcript: `e477ac98-a486-4541-8a72-26702dacc3ae.jsonl`
