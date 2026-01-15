# Linear API Fallback Implementation Plan

**Date:** 2026-01-15
**Status:** Ready for Execution
**Execution:** Parallel worktrees with subagents

---

## Execution Strategy

### Step 0: Commit Current Analysis (Main Agent)

Before launching parallel work, commit the evaluation analysis to `claude-agent-eval-analysis` branch:
- `thoughts/research/2026-01-13-evaluating-ai-agents-testing-approaches.md` (reliability analysis addendum)
- `thoughts/handoffs/2026-01-15-eval-assessment-handoff.md` (updated status)
- `tests/results/dashboard.md` (metrics dashboard)
- `thoughts/plans/2026-01-15-linear-api-fallback-implementation.md` (this plan)

### Parallel Execution

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PARALLEL WORKTREE STRATEGY                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  MAIN AGENT (current session)                                            │
│  ├── Commit evaluation analysis                                          │
│  ├── Interactive Q&A with user                                           │
│  └── Improve testing framework/reporting                                 │
│                                                                          │
│  SUBAGENT 1 (background)          SUBAGENT 2 (background)                │
│  ├── Worktree: linear-check-api   ├── Worktree: linear-sync-api          │
│  ├── Branch: linear-check-api-    ├── Branch: linear-sync-api-           │
│  │           fallback             │           fallback                   │
│  └── Task: Implement API          └── Task: Implement API                │
│            fallback in                      fallback in                  │
│            linear-check                     linear-sync                  │
│            SKILL.md + tests                 SKILL.md + tests             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Problem Statement

The `linear-check` and `linear-sync` skills fail 93% of tests because:
1. MCP authentication cannot work in test subprocess (non-interactive)
2. API fallback is documented in `linear-check` but not implemented
3. API fallback is not documented or implemented in `linear-sync`

**Goal:** Enable both skills to work without MCP by falling back to direct GraphQL API calls when MCP is unavailable.

---

## Linear API Verification

### Confirmed Capabilities

| Operation | GraphQL | Supported |
|-----------|---------|-----------|
| Search issues | `searchIssues` query | ✅ |
| Get issue | `issue(id:)` query | ✅ |
| Get team states | `team.states` query | ✅ |
| **Update issue** | `issueUpdate` mutation | ✅ |
| **Create comment** | `commentCreate` mutation | ✅ |
| Create issue | `issueCreate` mutation | ✅ |

### Authentication

```
Authorization: Bearer lin_api_xxx
Endpoint: https://api.linear.app/graphql
Rate limit: 1,500 req/hour (API key), 500 req/hour (OAuth)
```

### Sources

- [Linear GraphQL API](https://linear.app/developers/graphql)
- [Working with GraphQL](https://developers.linear.app/docs/graphql/working-with-the-graphql-api)
- [Apollo Studio Schema](https://studio.apollographql.com/public/Linear-API/variant/current/schema/reference/objects/Mutation)

---

## Current State Analysis

### linear-check SKILL.md

**Has API fallback documented:**
- ✅ GraphQL query for `searchIssues`
- ✅ GraphQL query for `team.states`
- ✅ Curl examples with auth header
- ✅ Config structure for token in `.entourage/repos.json`

**Gap:** Skill instructs Claude to "fall back" but provides no mechanism to detect MCP unavailability.

### linear-sync SKILL.md

**Missing API fallback:**
- ❌ Only references MCP tools (`mcp__linear__*`)
- ❌ No GraphQL mutations documented
- ❌ No curl examples for write operations

**Required mutations:**
1. `issueUpdate` - Change issue state
2. `commentCreate` - Add explanatory comment

---

## Implementation Plan

### Phase 1: Document GraphQL Mutations in linear-sync

Add "Using API Token (Fallback)" section with:

#### 1. Issue Update Mutation

```graphql
mutation IssueUpdate($id: String!, $stateId: String!) {
  issueUpdate(id: $id, input: { stateId: $stateId }) {
    success
    issue {
      id
      identifier
      state {
        id
        name
        type
      }
    }
  }
}
```

**Curl example:**
```bash
curl -X POST https://api.linear.app/graphql \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation($id: String!, $stateId: String!) { issueUpdate(id: $id, input: { stateId: $stateId }) { success issue { identifier state { name } } } }",
    "variables": {"id": "issue-uuid", "stateId": "state-uuid"}
  }'
```

#### 2. Comment Create Mutation

```graphql
mutation CommentCreate($issueId: String!, $body: String!) {
  commentCreate(input: { issueId: $issueId, body: $body }) {
    success
    comment {
      id
      body
    }
  }
}
```

**Curl example:**
```bash
curl -X POST https://api.linear.app/graphql \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation($issueId: String!, $body: String!) { commentCreate(input: { issueId: $issueId, body: $body }) { success } }",
    "variables": {"issueId": "issue-uuid", "body": "Status updated based on code evidence..."}
  }'
```

#### 3. Get State ID Query

Before updating, need to resolve state name → state ID:

```graphql
query TeamStates($teamId: String!) {
  team(id: $teamId) {
    states {
      nodes {
        id
        name
        type
      }
    }
  }
}
```

### Phase 2: Add MCP Detection Logic

Both skills need a detection mechanism. Add to "Authentication" section:

```markdown
### Step 1: Attempt MCP First

Try to call a Linear MCP tool (e.g., `mcp__linear__list_teams`).

**If successful:** Use MCP for all operations.
**If fails with "MCP not available" or tool not found:** Fall back to API token.

### Step 2: API Token Fallback

Read token from `.entourage/repos.json`:

```json
{
  "linear": {
    "token": "lin_api_xxx",
    "teamId": "TEAM",
    "workspace": "my-workspace"
  }
}
```

Use the token for direct GraphQL API calls.
```

### Phase 3: Update Test Fixtures

Create fixtures with API token for automated testing:

```
skills/linear-check/evaluations/fixtures/
├── with-config/           # Generic (committed) - no token
│   └── .entourage/repos.json
│       {"linear": {"teamId": "TEAM"}}
│
└── local-myteam/          # Workspace-specific (gitignored)
    └── .entourage/repos.json
        {"linear": {"token": "lin_api_xxx", "teamId": "ENT", "workspace": "myentourage"}}
```

Add to `.gitignore`:
```
skills/*/evaluations/fixtures/local-*
```

### Phase 4: Update Evaluation Test Cases

Modify `evaluation.json` to:
1. Mark MCP-dependent tests as `pending` with clear reason
2. Add API-fallback tests that use token-based fixtures

---

## Files to Modify

| File | Changes |
|------|---------|
| `skills/linear-sync/SKILL.md` | Add "Using API Token (Fallback)" section with mutations |
| `skills/linear-check/SKILL.md` | Add MCP detection logic |
| `skills/linear-check/evaluations/evaluation.json` | Update test case status/fixtures |
| `skills/linear-sync/evaluations/evaluation.json` | Update test case status/fixtures |
| `.gitignore` | Add `skills/*/evaluations/fixtures/local-*` |

---

## GraphQL Reference

### Complete Query Set (linear-check)

```graphql
# Search issues by term
query SearchIssues($term: String!, $teamId: String) {
  searchIssues(term: $term, first: 20, teamId: $teamId) {
    nodes {
      id
      identifier
      title
      state { id name type }
      assignee { name }
      updatedAt
      url
    }
  }
}

# Get single issue by identifier
query Issue($id: String!) {
  issue(id: $id) {
    id
    identifier
    title
    state { id name type }
    assignee { name }
    updatedAt
    url
  }
}

# Get team workflow states
query TeamStates($teamId: String!) {
  team(id: $teamId) {
    id
    name
    states {
      nodes { id name type position }
    }
  }
}
```

### Complete Mutation Set (linear-sync)

```graphql
# Update issue status
mutation IssueUpdate($id: String!, $stateId: String!) {
  issueUpdate(id: $id, input: { stateId: $stateId }) {
    success
    issue {
      id
      identifier
      state { id name type }
    }
  }
}

# Add comment to issue
mutation CommentCreate($issueId: String!, $body: String!) {
  commentCreate(input: { issueId: $issueId, body: $body }) {
    success
    comment { id }
  }
}

# Create new issue (for unmatched components)
mutation IssueCreate($teamId: String!, $title: String!, $description: String) {
  issueCreate(input: { teamId: $teamId, title: $title, description: $description }) {
    success
    issue {
      id
      identifier
      url
    }
  }
}
```

---

## Verification Strategy

### 1. Structure Validation (CI)

```bash
./tests/validate.sh
```

Verifies JSON schema, required fields, no broken references.

### 2. Local API Test (Manual)

With gitignored fixture containing real token:

```bash
# Test read operations
./tests/run.sh linear-check

# Test write operations (creates test issues)
LINEAR_SYNC_AUTO_CONFIRM=1 ./tests/run.sh linear-sync
```

### 3. Expected Results After Implementation

| Skill | Current | Expected | Notes |
|-------|---------|----------|-------|
| linear-check | 7% | 80%+ | With API fallback and token |
| linear-sync | 8% | 70%+ | With API fallback and token |

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Token exposure in fixtures | Gitignore `local-*` directories |
| Rate limiting in tests | Use `TRIALS_PER_CASE=1` for CI |
| Write tests modify real data | Use `[TEST]` prefix, auto-cancel |
| Team-specific state names | Query states first, fallback to type |

---

## Timeline Estimate

| Phase | Effort |
|-------|--------|
| Phase 1: Document mutations | 30 min |
| Phase 2: Add detection logic | 30 min |
| Phase 3: Create fixtures | 20 min |
| Phase 4: Update test cases | 30 min |
| **Total** | ~2 hours |

---

## Design Decisions (Resolved)

| Question | Decision |
|----------|----------|
| Fixture templates | **Both**: Commit template with placeholder + document in README |
| Write test safety | **Production + prefix**: Use `[TEST]` prefix, auto-cancel after test |
| MCP detection | Try MCP first, catch failure, fall back to API token |

### Fixture Strategy

1. **Committed template** (sanitized):
   ```
   skills/linear-check/evaluations/fixtures/with-config/.entourage/repos.json
   {"linear": {"token": "YOUR_TOKEN_HERE", "teamId": "TEAM", "workspace": "your-workspace"}}
   ```

2. **Gitignored local fixtures** (real tokens):
   ```
   skills/linear-check/evaluations/fixtures/local-myteam/.entourage/repos.json
   {"linear": {"token": "lin_api_xxx", "teamId": "ENT", "workspace": "myentourage"}}
   ```

3. **README documentation**: Explain both approaches

### Write Test Safety Protocol

Tests that create/modify Linear issues will:
1. Prefix all test issue titles with `[TEST]`
2. Set test issues to `Canceled` state after verification
3. Linear auto-archives canceled issues per workspace settings
4. Run in production workspace (no separate test workspace needed)
