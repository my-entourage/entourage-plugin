---
name: linear-sync
description: Updates Linear issues based on project-status evidence. Use when asked to sync Linear with code evidence or update issue status.
---

## Purpose

Synchronize Linear issue status with implementation evidence from code repositories. Updates issues to reflect actual development progress based on evidence from `/project-status`.

## When to Use

Apply when user asks:
- "Sync Linear with actual status"
- "Update Linear based on code"
- "Linear issues are out of date"
- "Mark Linear issues as done/in progress"

**Important:** Only invoke when user explicitly asks to update Linear. This skill modifies Linear data.

## Prerequisites

- Linear MCP configured or API token in `.entourage/repos.json`
- At least one evidence source configured (local repo, GitHub, or Linear)

---

## Workflow

### Step 1: Get Implementation Evidence

If components specified, invoke `/project-status <components>`.
If no components specified, invoke `/project-status` for full project scan.

Parse the output table to extract:
- Component name
- Status (Triage, Backlog, Todo, In Progress, In Review, Done, Shipped, Canceled, Unknown)
- Evidence description
- Source

### Step 2: Query Linear Current State

1. Get team's workflow states:
   - Use `mcp__linear__list_issue_statuses` with teamId from config

2. For each component, search for matching Linear issues:
   - Use `mcp__linear__list_issues` with query parameter set to component name

### Step 3: Match Components to Linear Issues

For each component from project-status:

**Primary: Exact Title Match**
- Issue title matches component name (case-insensitive)
- Score: 100

**Secondary: Partial Title Match**
- Component name appears anywhere in issue title
- Score: 60

**Tertiary: Identifier Match**
- If component looks like "ENT-123", query by identifier directly
- Use `mcp__linear__get_issue` with the identifier

**No Match**
- Add to unmatched list
- Report in output with option to create new issue

### Step 4: Determine Required Actions

For each matched component-to-issue pair:

1. Compare project-status status to Linear issue status
2. Apply status priority ordering (see Status Mapping)
3. Determine if upgrade is needed

**Upgrade-Only Rule:** Never downgrade status automatically. If Linear shows higher status than evidence, skip the update and note it.

### Step 5: Generate Change Preview

Output a preview table showing all proposed changes:

```
## Linear Sync Preview

| Component | Issue | Current | Proposed | Evidence |
|-----------|-------|---------|----------|----------|
| auth | ENT-123 | Backlog | In Progress | Feature branch exists |
| dashboard | ENT-456 | In Progress | Done | PR #78 merged, CI passing |

### No Change Needed
- ENT-789 (payments): Already at Done

### Skipped (Linear status higher)
- ENT-111 (analytics): Linear at Done, evidence shows In Progress

### No Linear Issue Found
- notifications: No matching issue

Proceed with updates? (y/n)
```

### Step 6: Request Confirmation

- For any updates: Request explicit confirmation
- For bulk updates (>3 issues): Require "yes" typed confirmation
- User can select individual issues to update or skip

### Step 7: Apply Updates

For each confirmed update:

1. Update issue status:
   ```
   mcp__linear__update_issue(id=issue_id, state=new_state_name)
   ```

2. Add explanatory comment:
   ```
   mcp__linear__create_comment(
     issueId=issue_id,
     body="Status updated to [New Status] based on code evidence:\n- [Evidence description]\n- Source: /linear-sync"
   )
   ```

### Step 8: Report Results

Output final results:

```
## Linear Sync Results

### Updated (2)
| Issue | Previous | New | Evidence |
|-------|----------|-----|----------|
| ENT-123 | Backlog | In Progress | Feature branch exists |
| ENT-456 | In Progress | Done | PR #78 merged, CI passing |

### Skipped (1)
- ENT-789: Linear status (Done) already higher than evidence (In Progress)

### No Match (1)
- notifications: No Linear issue found
```

---

## Status Mapping

### Priority Order (Highest to Lowest)

| Priority | Status | Linear State Type |
|----------|--------|-------------------|
| 1 | Shipped | completed |
| 2 | Done | completed |
| 3 | In Review | started |
| 4 | In Progress | started |
| 5 | Todo | unstarted |
| 6 | Backlog | backlog |
| 7 | Triage | triage |
| 8 | Canceled | canceled |
| 9 | Unknown | (no action) |

### Mapping to Linear States

| Project-Status | Linear State Name | Fallback |
|---------------|-------------------|----------|
| Shipped | Done | - |
| Done | Done | - |
| In Review | In Review | In Progress |
| In Progress | In Progress | - |
| Todo | Todo | - |
| Backlog | Backlog | - |
| Triage | Triage | - |
| Canceled | Canceled | (requires --force flag) |
| Unknown | (no action) | - |

### Resolving Team-Specific States

Since Linear teams can customize workflow states:

1. Call `mcp__linear__list_issue_statuses` to get team's states
2. Match by state name first (e.g., "In Review")
3. If no match, fall back to state type (e.g., type "started")
4. Handle teams without "In Review" state by using "In Progress"

---

## Safety Rules

1. **Never downgrade status automatically** - Only upgrade to higher priority status
2. **Always add comment explaining change** - Include evidence source
3. **Require confirmation for all updates** - No silent modifications
4. **Prompt before creating new issues** - Don't auto-create
5. **Canceled status requires explicit flag** - Use `--force` to mark as canceled

---

## Configuration

Read Linear settings from `.entourage/repos.json`:

```json
{
  "linear": {
    "teamId": "TEAM",
    "workspace": "my-workspace"
  }
}
```

### Authentication

1. **Preferred:** Use Linear MCP (handles OAuth automatically)
2. **Fallback:** API token from config file

---

## Error Handling

### Linear MCP Not Available
```
> Linear MCP not available. Ensure Linear MCP server is configured.
> See: https://linear.app/docs/mcp
```

### Team Not Found
```
> Linear team "TEAM" not found. Check `teamId` in `.entourage/repos.json`.
```

### Permission Denied
```
> Cannot update issue ENT-123: Insufficient permissions.
> Check your Linear role allows issue editing.
```

### State Not Found
```
> Cannot find state "In Review" in team TEAM.
> Available states: Triage, Backlog, Todo, In Progress, Done, Canceled
> Using "In Progress" instead.
```

---

## Examples

### Basic Sync

**Query:** `/linear-sync`

Runs full project status check and syncs all matching issues.

### Component-Specific Sync

**Query:** `/linear-sync auth dashboard`

Syncs only the specified components.

### After Project Status

**Query:** "Update Linear based on the status you just showed me"

Uses the most recent `/project-status` output to sync Linear.

---

## After Output

This skill modifies Linear issues and reports results. After completion:
- Summarize what was updated
- Note any issues that couldn't be matched
- Continue with next user request
