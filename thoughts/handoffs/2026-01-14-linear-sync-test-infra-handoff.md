# Linear Sync Test Infrastructure Handoff

**Date:** 2026-01-14
**Branch:** `linear-status-update-skill`
**Status:** Implementation Complete - Write Tests Added

## Objective

Add comprehensive test infrastructure for `/linear-sync` skill to verify Linear MCP write operations (create, update, comment).

## Problem Statement

The existing linear-sync tests verified workflow logic but didn't test actual MCP write operations:
- Create an issue
- Update issue status
- Add explanatory comment
- Assign team member
- Set due date

## Solution: AUTO_CONFIRM Environment Variable

Added `LINEAR_SYNC_AUTO_CONFIRM=1` environment variable that:
- **When set:** Shows one-time warning, then skips per-operation confirmations
- **When unset:** Normal interactive flow with user confirmation (production use)

### Safety Warning (Auto-Confirm Mode)

When enabled, the skill displays:
```
⚠️  AUTO-CONFIRM MODE ENABLED

This will create, modify, and cancel temporary issues in your configured
Linear workspace. All test issues will be:
- Prefixed with [TEST]
- Set to Canceled status after testing
- Auto-archived by Linear after the configured period

Workspace: {workspace_name}
Team: {team_id}

Consider creating a dedicated test workspace if you're concerned about
affecting your production workspace.

Proceed with automated write tests? (y/n)
```

## Implementation Summary

### Files Modified

| File | Changes |
|------|---------|
| `skills/linear-sync/SKILL.md` | Added auto-confirm mode logic in Step 6, environment variables table |
| `skills/linear-sync/evaluations/evaluation.json` | Added 5 write operation test cases |
| `tests/lib/graders.sh` | Added `check_calls()` grader function |
| `tests/run.sh` | Set `LINEAR_SYNC_AUTO_CONFIRM=1` for linear-sync tests |
| `.gitignore` | Added exception for `local-example/` template |

### Files Created

| File | Purpose |
|------|---------|
| `tests/integration/linear-mcp-writes.md` | Manual integration test checklist |
| `skills/linear-sync/evaluations/fixtures/local-example/README.md` | Template setup instructions with warnings |
| `skills/linear-sync/evaluations/fixtures/local-example/.entourage/repos.json` | Config template |

### New Test Cases (evaluation.json)

| Test ID | Purpose | MCP Calls |
|---------|---------|-----------|
| `write-create-issue` | Create [TEST] issue in Triage | `create_issue` |
| `write-update-status` | Update status Backlog → In Progress | `create_issue`, `update_issue` |
| `write-add-comment` | Add explanatory comment | `create_issue`, `create_comment` |
| `write-assign-member` | Assign team member | `create_issue`, `update_issue` |
| `write-set-due-date` | Set due date | `create_issue` |

All tests are marked `status: "pending"` because they require a `local-*` fixture with real Linear workspace configuration.

### check_calls() Grader

New grader function that verifies MCP tool invocations by checking output evidence:

```bash
# Matches for each tool type:
create_issue  → "created.*ENT-|issue.*created|[TEST]"
update_issue  → "updated|status.*changed|→.*Done"
create_comment → "added.*comment|comment.*added"
```

## Test Results

```
$ ./tests/run.sh --dry-run linear-sync

Skills tested:  1
Total cases:    18
Passed:         0
Failed:         0
Skipped:        5 (write tests pending local fixture)
```

## How to Run Write Tests

### Step 1: Create Local Fixture

```bash
cp -r skills/linear-sync/evaluations/fixtures/local-example \
      skills/linear-sync/evaluations/fixtures/local-myteam
```

### Step 2: Configure Workspace

Edit `.entourage/repos.json` with your Linear team:
```json
{
  "linear": {
    "teamId": "YOUR_TEAM_KEY",
    "workspace": "your-workspace-slug"
  }
}
```

### Step 3: Change Test Status

In `evaluation.json`, change `"status": "pending"` to `"status": "active"` for the write tests.

### Step 4: Run Tests

```bash
./tests/run.sh linear-sync
```

## Manual Integration Testing

For interactive testing with confirmation prompts, use:
```
tests/integration/linear-mcp-writes.md
```

This checklist verifies:
- Issue creation with identifier
- Status updates
- Member assignment
- Due date setting
- Comment creation
- Cleanup via Cancel status

## Current Branch Status

- [x] PR #7 created for linear-sync skill
- [x] Test fixtures for linear-sync added
- [x] Write operation test infrastructure implemented
- [x] Manual integration checklist created
- [x] Local fixture template with warnings created

## Next Steps

1. **Activate write tests locally** - Copy `local-example` and configure for your workspace
2. **Run write tests** - Verify MCP operations work via test harness
3. **Complete PR review** - Merge linear-sync to main
4. **Test skill invocation** - Restart Claude Code and test `/linear-sync`

## References

- Plan file: `/Users/jaredsisk/.claude/plans/polymorphic-wibbling-kitten.md`
- Previous handoff: `2026-01-14-linear-check-skill-handoff.md`
- SKILL.md: `skills/linear-sync/SKILL.md`
