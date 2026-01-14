# Linear Sync Skill - Deferred Plan

**Status:** Deferred
**Depends on:** `/linear-check` skill (must be completed first)
**Created:** 2026-01-14

## Overview

Create a `/linear-sync` skill that updates Linear issues based on project-status output. This skill will:
- Read project-status results
- Compare detected status vs Linear issue status
- Update Linear issues when code evidence shows higher status
- Optionally create new issues for discussed components

## Scope

- **Update existing issues** based on code evidence
- **Create new issues** (with user confirmation) for components found in transcripts
- **Add comments** explaining status changes

## Authentication

Use the same authentication strategy as `/linear-check`:
1. Check Linear MCP availability
2. Fall back to API token from `.entourage/repos.json`

## MCP Tools Required

- `update_issue` - Update issue status
- `create_issue` - Create new issues (with user confirmation)
- `create_comment` - Add sync note explaining change

## Workflow

```
1. Parse project-status output
2. For each component with Linear issue:
   - Compare current Linear status vs detected status
   - If code evidence shows higher status → Update Linear issue
   - Add comment explaining the status change source
3. For components without Linear issue:
   - Ask user before creating (don't auto-create)
   - If confirmed, create in Triage status
4. Report all changes made
```

## Comment Format

When updating an issue, add a comment like:

```
Status updated to In Review based on code evidence:
- PR #123 opened: "Implement auth flow"
- Source: /project-status sync
```

## Safety Rules

1. **Never downgrade status automatically** - Only upgrade
2. **Always add comment** explaining status change with evidence source
3. **Prompt user** before creating new issues
4. **Require confirmation** for bulk updates (>3 issues)

## GraphQL Mutations (API Fallback)

```graphql
# Update issue status
mutation UpdateIssue($id: String!, $stateId: String!) {
  issueUpdate(id: $id, input: { stateId: $stateId }) {
    issue { identifier state { name } }
  }
}

# Create comment
mutation CreateComment($issueId: String!, $body: String!) {
  commentCreate(input: { issueId: $issueId, body: $body }) {
    comment { id }
  }
}

# Create issue
mutation CreateIssue($title: String!, $teamId: String!, $stateId: String!) {
  issueCreate(input: { title: $title, teamId: $teamId, stateId: $stateId }) {
    issue { identifier url }
  }
}
```

## Output Format

```markdown
## Linear Sync Results

### Updated Issues
| Issue | Previous | New | Evidence |
|-------|----------|-----|----------|
| ENT-123 | Backlog | In Progress | Feature branch exists |
| ENT-456 | In Progress | In Review | PR #78 opened |

### Created Issues
| Issue | Component | Status |
|-------|-----------|--------|
| ENT-789 | payments | Triage |

### No Action Needed
- ENT-111: Already at Done (matches evidence)
- ENT-222: Linear status higher than evidence (manual override?)
```

## Test Cases

1. Issue found, status needs upgrade
2. Issue found, status already correct
3. Issue found, Linear status higher than evidence (no action)
4. No issue found, user confirms creation
5. No issue found, user declines creation
6. Bulk update confirmation flow

## Dependencies

- `/linear-check` must be working
- `/project-status` output format must be stable
- Linear MCP or API token must be configured

## Implementation Notes

- Parse markdown tables from project-status output
- Map status names to Linear state IDs (need to query team states first)
- Handle cases where Linear has custom workflow states
- Consider rate limiting for bulk updates
