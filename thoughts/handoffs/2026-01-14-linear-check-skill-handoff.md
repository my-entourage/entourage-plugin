# Linear Check Skill Implementation Handoff

**Date:** 2026-01-14
**Branch:** `linear-check-claude-code-skill`
**Status:** Implementation Complete, Pending Testing

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

## Testing Instructions

### Prerequisites
The `linear-check` skill requires a Claude Code restart to be recognized (skill was added after session started).

### Option 1: Test via Skill Invocation
1. Restart Claude Code to load the new skill
2. Run `/linear-check auth` to test issue search
3. Run `/linear-check nonexistent-thing` to test "not found" case

### Option 2: Test Linear MCP Directly
If Linear MCP is configured, test the MCP tools directly:
- Use `list_issues` MCP tool with query "auth"
- Verify issues from ENT team are returned

### Option 3: Test API Fallback
1. Generate Linear API token at https://linear.app/myentourage/settings/api
2. Add token to `.entourage/repos.json`:
   ```json
   {
     "linear": {
       "token": "lin_api_YOUR_TOKEN",
       "teamId": "ENT",
       "workspace": "myentourage"
     }
   }
   ```
3. Test with curl:
   ```bash
   curl -X POST https://api.linear.app/graphql \
     -H "Authorization: lin_api_YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"query": "query { issueSearch(query: \"auth\", first: 5) { nodes { identifier title state { name type } } } }"}'
   ```

### Expected Results
- **Issue found:** Returns markdown table with issue details, status mapped correctly
- **No issue found:** Returns "Unknown" status with message
- **No config:** Returns configuration instructions

### Test Cases from evaluation.json
- `no-config` - No Linear configuration
- `issue-found-in-progress` - Issue with In Progress status
- `issue-found-done` - Issue with Done status
- `no-issue-found` - No matching issue
- `multiple-components` - Query for multiple components

## Current Status

**Implemented:**
- [x] `skills/linear-check/SKILL.md` - Skill definition
- [x] `skills/linear-check/README.md` - Documentation
- [x] `skills/linear-check/evaluations/evaluation.json` - Test cases
- [x] Status hierarchy updated in all skills
- [x] Linear integration in project-status workflow
- [x] `.entourage/repos.json` schema updated

**Pending:**
- [ ] Test skill invocation after Claude Code restart
- [ ] Verify Linear MCP integration works
- [ ] Test API token fallback

## References

- [Linear MCP Server - OpenTools](https://opentools.com/registry/linear-remote)
- [Linear Workflow Docs](https://linear.app/docs/configuring-workflows)
- [Linear Triage Docs](https://linear.app/docs/triage)
- Existing pattern: `skills/github-repo-check/SKILL.md`
