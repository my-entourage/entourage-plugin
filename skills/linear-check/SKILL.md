---
name: linear-check
description: Verify implementation status by querying Linear API for issues. Use when checking issue tracking status.
---

## Purpose

Query Linear to verify planning/implementation status of components/features. Returns evidence-based status levels using issue data from Linear.

## When to Use

- Directly invoked: `/linear-check authentication`
- Checking issue status for a component
- Verifying planning and tracking status
- When invoked by other skills (like `/project-status`)

## Input

Component or feature name(s) to verify. Examples:
- `/linear-check authentication`
- `/linear-check user-dashboard payments`

**Note:** Component searches are case-insensitive.

---

## Authentication

### Step 1: Check Linear MCP Availability

The Linear MCP server is preferred because it handles authentication via OAuth.

Check if Linear MCP tools are available by attempting to use a Linear MCP tool. If the tool responds successfully, use MCP for all queries.

### Step 2: Fallback to API Token

If Linear MCP is unavailable, fall back to token from `.entourage/repos.json`:

```json
{
  "linear": {
    "token": "lin_api_...",
    "teamId": "ENT",
    "workspace": "myentourage"
  }
}
```

Use curl with the token for GraphQL queries:
```bash
curl -X POST https://api.linear.app/graphql \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "..."}'
```

---

## Configuration Discovery

### Step 1: Check for Config File

Use the Read tool to check if `.entourage/repos.json` exists.

**If the file does not exist:**
```
> No repository configuration found. Create `.entourage/repos.json` with your Linear settings.
```

### Step 2: Extract Linear Config

Look for `linear` section in the config:

```json
{
  "linear": {
    "token": "lin_api_...",
    "teamId": "ENT",
    "workspace": "myentourage"
  }
}
```

### Step 3: No Linear Configuration

If no `linear` section exists and MCP is unavailable:
```
> No Linear configuration found. Either configure Linear MCP or add `linear` section to `.entourage/repos.json`.
```

---

## Linear API Queries

For each component/feature, run these queries:

### Using MCP (Preferred)

**Search issues by component name:**
Use the `list_issues` MCP tool with the query parameter set to the component name and teamId from config.

**Get issue details:**
Use the `get_issue` MCP tool with the issue ID.

**Get team's workflow states:**
Use the `list_issue_statuses` MCP tool with the teamId.

### Using API Token (Fallback)

Linear uses a GraphQL API at `https://api.linear.app/graphql`.

**Search issues by component name:**
```graphql
query SearchIssues($query: String!) {
  issueSearch(query: $query, first: 20) {
    nodes {
      identifier
      title
      state {
        name
        type
      }
      assignee {
        name
      }
      updatedAt
      url
    }
  }
}
```

**Get team's workflow states:**
```graphql
query TeamStates($teamKey: String!) {
  team(id: $teamKey) {
    id
    name
    states {
      nodes {
        name
        type
        position
      }
    }
  }
}
```

**Example curl command:**
```bash
curl -X POST https://api.linear.app/graphql \
  -H "Authorization: lin_api_YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { issueSearch(query: \"authentication\", first: 20) { nodes { identifier title state { name type } } } }"
  }'
```

---

## Evidence Synthesis

Apply this decision tree to determine component status based on Linear issue state:

```
1. Issue state type is "completed"?
   YES -> Status: Done (High confidence)

2. Issue state type is "started" AND state name contains "review"?
   YES -> Status: In Review (High confidence)

3. Issue state type is "started"?
   YES -> Status: In Progress (High confidence)

4. Issue state type is "unstarted" AND state name is "Todo"?
   YES -> Status: Todo (High confidence)

5. Issue state type is "backlog"?
   YES -> Status: Backlog (High confidence)

6. Issue state type is "triage"?
   YES -> Status: Triage (High confidence)

7. Issue state type is "canceled"?
   YES -> Status: Canceled (High confidence)

8. No Linear issue found?
   -> Status: Unknown
   -> Output: "No Linear issue found for this component."
```

### State Type Mapping

Linear uses these state types:
- `triage` - Issues needing review before acceptance
- `backlog` - Accepted but not scheduled
- `unstarted` - Scheduled/ready to start (includes "Todo")
- `started` - Work in progress (includes "In Progress", "In Review")
- `completed` - Done
- `canceled` - Won't fix, duplicate, etc.

---

## Error Handling

### MCP Not Available, No Token
```
> Linear MCP not configured and no API token found. Configure Linear MCP or add token to `.entourage/repos.json`.
```

### Token Invalid/Expired
If API returns authentication error:
```
> Linear API error: Authentication failed. Check your token in `.entourage/repos.json`.
```

### Rate Limited
If API returns rate limit error:
```
> Linear API rate limit reached. Try again later.
```

### Team Not Found
If team ID is invalid:
```
> Linear team not found. Check `teamId` in `.entourage/repos.json`.
```

---

## Output Format

### With Linear Configuration

```markdown
## Linear Scan: [Component Name]

| Issue | Status | State | Assignee | Last Updated |
|-------|--------|-------|----------|--------------|
| ENT-123 | In Progress | In Progress | @user | 2025-01-10 |

### Linear Details

**ENT-123:** "Implement authentication flow"
- Status: In Progress
- Assignee: @user
- Updated: Jan 10, 2025
- URL: https://linear.app/myentourage/issue/ENT-123
```

### Without Linear Configuration

```markdown
## Linear Scan

No Linear configuration found. Either:
1. Configure Linear MCP server, or
2. Add `linear` section to `.entourage/repos.json`:

{
  "linear": {
    "token": "lin_api_...",
    "teamId": "ENT",
    "workspace": "myentourage"
  }
}
```

### Multiple Components

When checking multiple components, output a summary table followed by details:

```markdown
## Linear Scan Summary

| Component | Status | Issue | State | Confidence |
|-----------|--------|-------|-------|------------|
| auth | In Progress | ENT-123 | In Progress | High |
| dashboard | Backlog | ENT-456 | Backlog | High |
| payments | Unknown | - | - | - |

### Details

[Per-component Linear details...]
```

---

## Example

**Query:** `/linear-check authentication`

**Output:**

```markdown
## Linear Scan: authentication

| Issue | Status | State | Assignee | Last Updated |
|-------|--------|-------|----------|--------------|
| ENT-123 | In Progress | In Progress | @alice | 2025-01-10 |

### Linear Details

**ENT-123:** "Implement Clerk authentication"
- Status: In Progress
- State: In Progress (started)
- Assignee: @alice
- Updated: Jan 10, 2025
- URL: https://linear.app/myentourage/issue/ENT-123
```

---

## After Output

This skill returns results to the calling context (usually `/project-status`). **Do not stop execution.**
Continue with the next step in the workflow or TODO list.
