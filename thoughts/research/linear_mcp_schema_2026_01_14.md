# Linear MCP Reference (2026-01-14)

Complete reference for Linear MCP tools available via `mcp__linear__*` functions.

## Configuration

Add to `~/.claude.json` or project `.mcp.json`:
```json
{
  "mcpServers": {
    "linear": {
      "type": "sse",
      "url": "https://mcp.linear.app/sse"
    }
  }
}
```

## Key Insight: Status vs Status Type

**Issue `status` is a string only.** The `list_issues` and `get_issue` tools return `status: "Triage"` as a string, NOT an object with `type` field.

To get the status type (triage, backlog, started, completed, canceled), you must:
1. Call `list_issue_statuses` with the team
2. Cross-reference the status name to find its type

```
Status Name → Type
─────────────────────
Triage      → triage
Backlog     → backlog
Todo        → unstarted
In Progress → started
In Review   → started
Done        → completed
Canceled    → canceled
Duplicate   → canceled
```

## Read Tools

### `list_teams`
```json
[{"id": "uuid", "name": "Entourage", "createdAt": "ISO", "updatedAt": "ISO"}]
```

### `get_team` (query: UUID, key, or name)
```json
{"id": "uuid", "name": "Entourage", "createdAt": "ISO", "updatedAt": "ISO"}
```

### `list_users` (query, team)
```json
[{
  "id": "uuid", "name": "Jared Sisk", "email": "...", "displayName": "jared",
  "isAdmin": true, "isGuest": false, "isActive": true,
  "avatarUrl": "...", "status": "Offline (last seen ISO)"
}]
```

### `get_user` (query: ID, name, email, or "me")
Same structure as list_users item.

### `list_projects` (team, member, state, initiative, query, limit, etc.)
```json
{
  "content": [{
    "id": "uuid", "name": "Web Interface", "color": "#bec2c8",
    "summary": "", "description": "", "url": "https://linear.app/...",
    "startDate": "2025-12-24", "targetDate": null,
    "priority": {"value": 3, "name": "Medium"},
    "lead": {"id": "uuid", "name": "Iivo Angerpuro"},
    "status": {"id": "uuid", "name": "In Progress"},
    "labels": [], "initiatives": []
  }],
  "pageInfo": {"endCursor": "uuid", "hasNextPage": true, "hasPreviousPage": false}
}
```

### `get_project` (query: ID or name)
Same structure as list_projects content item.

### `list_issues` (team, assignee, state, project, label, query, parentId, cycle, limit, etc.)
```json
[{
  "id": "uuid", "identifier": "ENT-50", "title": "Issue title",
  "description": "markdown content",
  "priority": {"value": 3, "name": "Medium"},
  "url": "https://linear.app/...",
  "gitBranchName": "jared/ent-50-issue-slug",
  "createdAt": "ISO", "updatedAt": "ISO", "dueDate": "2026-01-09",
  "status": "Todo",
  "labels": ["Feature"],
  "attachments": [{"id": "uuid", "title": "PR title", "url": "https://github.com/..."}],
  "documents": [],
  "createdBy": "Jared Sisk", "createdById": "uuid",
  "assignee": "Jared Sisk", "assigneeId": "uuid",
  "project": "Project Name", "projectId": "uuid",
  "projectMilestone": {"id": "uuid", "name": "Milestone"},
  "parentId": "uuid",
  "team": "Entourage", "teamId": "uuid",
  "archivedAt": "ISO"
}]
```

**Optional fields:** priority, dueDate, project/projectId, projectMilestone, parentId, archivedAt, assignee/assigneeId

### `get_issue` (id, includeRelations)
Same as list_issues item, plus when includeRelations=true:
```json
{
  "...issue fields...",
  "relations": {
    "blocks": [], "blockedBy": [], "relatedTo": [], "duplicateOf": null
  }
}
```

### `list_issue_statuses` (team - required)
```json
[
  {"id": "uuid", "type": "triage", "name": "Triage"},
  {"id": "uuid", "type": "backlog", "name": "Backlog"},
  {"id": "uuid", "type": "unstarted", "name": "Todo"},
  {"id": "uuid", "type": "started", "name": "In Progress"},
  {"id": "uuid", "type": "started", "name": "In Review"},
  {"id": "uuid", "type": "completed", "name": "Done"},
  {"id": "uuid", "type": "canceled", "name": "Canceled"},
  {"id": "uuid", "type": "canceled", "name": "Duplicate"}
]
```

### `list_issue_labels` (team, name, limit)
```json
[{"id": "uuid", "name": "Feature", "color": "#BB87FC"}]
```

### `list_comments` (issueId - required)
```json
[{"id": "uuid", "body": "markdown", "createdAt": "ISO", "user": {...}}]
```

### `list_cycles` (teamId - required, type: current/previous/next)
```json
[{"id": "uuid", "number": 1, "startsAt": "ISO", "endsAt": "ISO", ...}]
```

### `list_documents` (projectId, query, limit)
```json
{"content": [{...}], "pageInfo": {...}}
```

### `get_document` (id - document ID or slug)

### `list_project_labels` (name, limit)

### `search_documentation` (query - required, page)
```json
[{"id": "uuid", "title": "Triage", "url": "https://linear.app/docs/triage", "snippet": "..."}]
```

## Write Tools

### `create_issue` (title, team - required)
Optional: assignee, description, priority, state, project, labels, dueDate, cycle, parentId, blocks, blockedBy, relatedTo, duplicateOf, links, milestone, delegate

### `update_issue` (id - required)
All create_issue fields plus: estimate
**Warning:** blockedBy, blocks, relatedTo arrays REPLACE existing relations entirely.

### `create_comment` (issueId, body - required, parentId)

### `create_project` (name, team - required)
Optional: description, summary, color, icon, lead, state, priority, startDate, targetDate, labels, initiative

### `update_project` (id - required)
All create_project fields plus initiatives array.

### `create_document` (title, project - required)
Optional: content, color, icon

### `update_document` (id - required)
Optional: title, content, color, icon, project

### `create_issue_label` (name - required)
Optional: color, description, isGroup, parentId, teamId

## Common Patterns

```python
# Get status type for an issue
statuses = list_issue_statuses(team="Entourage")
issue = get_issue(id="ENT-38")
status_type = next(s["type"] for s in statuses if s["name"] == issue["status"])

# Find all in-progress issues
issues = list_issues(team="Entourage", state="In Progress")

# Search by text
issues = list_issues(query="authentication")

# Get sub-issues
sub_issues = list_issues(parentId="parent-issue-uuid")

# Filter by label
issues = list_issues(label="Feature")
```
