# Linear Check Skill

Query Linear to verify planning/implementation status of components.

## Usage

```
/linear-check <component-name>
/linear-check auth dashboard payments
```

## Authentication

This skill supports two authentication methods:

### 1. Linear MCP (Preferred)

Configure the Linear MCP server in your `.mcp.json`:

```json
{
  "mcpServers": {
    "linear": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.linear.app/sse"]
    }
  }
}
```

Then run `/mcp` to authenticate via OAuth.

### 2. API Token (Fallback)

Add your Linear API token to `.entourage/repos.json`:

```json
{
  "linear": {
    "token": "lin_api_YOUR_TOKEN_HERE",
    "teamId": "ENT",
    "workspace": "myentourage"
  }
}
```

Generate a token at: https://linear.app/settings/api

## Status Mapping

| Linear State Type | Linear State | Skill Status |
|-------------------|--------------|--------------|
| triage | Triage | Triage |
| backlog | Backlog | Backlog |
| unstarted | Todo | Todo |
| started | In Progress | In Progress |
| started | In Review | In Review |
| completed | Done | Done |
| canceled | * | Canceled |

## Output

Returns a markdown table with issue details:

```markdown
## Linear Scan: authentication

| Issue | Status | State | Assignee | Last Updated |
|-------|--------|-------|----------|--------------|
| ENT-123 | In Progress | In Progress | @alice | 2025-01-10 |
```

## Integration

This skill is typically invoked by `/project-status` to gather Linear evidence alongside GitHub and local repository evidence.

## See Also

- `/github-repo-check` - GitHub evidence gathering
- `/local-repo-check` - Local repository scanning
- `/project-status` - Orchestrates all evidence sources
