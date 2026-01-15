# Linear MCP Write Operations - Integration Test

## Purpose

Verify actual MCP write operations work in an interactive Claude session.
Run manually to test the full user flow with confirmation prompts.

## Prerequisites

- [ ] Linear MCP authenticated (`claude /mcp` shows linear)
- [ ] Access to a test team (or use your workspace with caution)
- [ ] Note: Tests create real issues - use `[TEST]` prefix for easy identification

## Test 1: Create Issue

```
Create a Linear issue titled "[TEST] Integration - $(date +%s)"
in team Entourage with status Triage
```

Expected:
- [ ] Issue created with identifier returned (e.g., ENT-XXX)
- [ ] Status is Triage
- [ ] Can view in Linear UI

## Test 2: Update Status

```
Update the test issue to "In Progress" status
```

Expected:
- [ ] Status changed in Linear
- [ ] Output confirms update

## Test 3: Assign Member

```
Assign the test issue to me
```

Expected:
- [ ] Assignee field shows current user
- [ ] Output confirms assignment

## Test 4: Set Due Date

```
Set the test issue due date to tomorrow
```

Expected:
- [ ] Due date visible in Linear
- [ ] Output confirms due date set

## Test 5: Add Comment

```
Add comment to test issue: "Integration test verification"
```

Expected:
- [ ] Comment visible in Linear issue activity
- [ ] Output confirms comment added

## Cleanup

```
Set the test issue status to Canceled
```

- [ ] Issue marked Canceled (auto-archives later based on Linear settings)

## Results

| Test | Pass/Fail | Notes |
|------|-----------|-------|
| Create Issue | | |
| Update Status | | |
| Assign Member | | |
| Set Due Date | | |
| Add Comment | | |
| Cleanup | | |

**Tested by:** ________________
**Date:** ________________
**Linear Workspace:** ________________
