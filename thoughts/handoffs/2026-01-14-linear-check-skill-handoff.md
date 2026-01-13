# Linear Check Skill Implementation Handoff

**Date:** 2026-01-14
**Branch:** `linear-check-claude-code-skill`
**Status:** In Progress

## Objective

Add `/linear-check` skill as an evidence source for project-status, parallel to `/github-repo-check`.

## Scope

- **In Scope:** `/linear-check` skill only
- **Deferred:** `/linear-sync` skill (see `thoughts/plans/linear-sync.md`)

## Authentication Strategy

Following the same pattern as `/github-repo-check`:

1. **Check Linear MCP availability** - If MCP tools respond, use them
2. **Fallback to API token** - Use token from `.entourage/repos.json`

```json
{
  "linear": {
    "token": "lin_api_...",
    "teamId": "ENT",
    "workspace": "myentourage"
  }
}
```

## Status Hierarchy Changes

Aligning with Linear's workflow states:

| Old Status | New Status | Notes |
|------------|------------|-------|
| Discussed | Triage | Mentioned, needs review |
| Planned | Backlog / Todo | Accepted or scheduled |
| In Progress | In Progress | Work started |
| (new) | In Review | PR open, awaiting review |
| Complete | Done | PR merged |
| Shipped | Shipped | Deployed to production |
| (new) | Canceled | Explicitly closed |

## Implementation Phases

### Phase 1: Create `/linear-check` Skill
- `skills/linear-check/SKILL.md`
- `skills/linear-check/README.md`
- MCP tools: `list_issues`, `get_issue`, `list_issue_statuses`
- GraphQL fallback for API token auth

### Phase 2: Update Status Hierarchy
Files to modify:
- `skills/project-status/SKILL.md`
- `skills/local-repo-check/SKILL.md`
- `skills/github-repo-check/SKILL.md`
- `skills/grounded-query/SKILL.md`

### Phase 3: Integrate into project-status
- Add Linear configuration check
- Add `/linear-check` invocation
- Update Unified Evidence Hierarchy
- Update conflict resolution rules

### Phase 4: Update Configuration
- Add Linear section to `.entourage/repos.json`
- Optional `.mcp.json` for MCP users

### Phase 5: Testing
- Create `skills/linear-check/evaluations/evaluation.json`
- Test cases: issue found, not found, multiple issues, API fallback

## Linear MCP Tools Available (22 total)

Key tools for this skill:
- `list_issues` - Search by query, teamId
- `get_issue` - Get issue details by ID
- `list_issue_statuses` - Get team's workflow states
- `get_issue_status` - Get specific status details

## Linear GraphQL API (Fallback)

Endpoint: `https://api.linear.app/graphql`

Key queries:
```graphql
query SearchIssues($query: String!, $teamId: String) {
  issueSearch(query: $query, filter: { team: { id: { eq: $teamId } } }) {
    nodes { identifier, title, state { name type }, assignee { name }, updatedAt }
  }
}

query TeamStates($teamId: String!) {
  team(id: $teamId) {
    states { nodes { name type position } }
  }
}
```

## Test Workspace

- Linear workspace: https://linear.app/myentourage/team/ENT/active
- Team ID: ENT

## Decisions Made

- **Auth:** MCP preferred, API token fallback
- **Status mapping:** Align with Linear (Triage, Backlog, Todo, etc.)
- **Configurable mapping:** Deferred to future PR

## References

- [Linear MCP Server - OpenTools](https://opentools.com/registry/linear-remote)
- [Linear Workflow Docs](https://linear.app/docs/configuring-workflows)
- [Linear Triage Docs](https://linear.app/docs/triage)
- Existing pattern: `skills/github-repo-check/SKILL.md`
