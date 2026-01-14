# Gmail Check Skill

Search Gmail for evidence about project components and features. Returns email threads, senders, dates, and relevance classification for status determination.

## Quick Start

1. Enable Gmail in your project configuration:

```json
// .entourage/repos.json
{
  "gmail": {
    "enabled": true,
    "searchDefaults": {
      "maxResults": 20,
      "daysBack": 90,
      "excludeCategories": ["promotions", "social", "spam"]
    }
  }
}
```

2. Configure a Gmail MCP server in Claude settings (see [MCP Setup](#mcp-setup))

3. Invoke the skill:

```
/gmail-check authentication
/gmail-check user-dashboard payments
```

## Configuration

### Gmail Settings

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `gmail.enabled` | boolean | false | Enable/disable Gmail integration |
| `gmail.searchDefaults.maxResults` | number | 20 | Max emails per search |
| `gmail.searchDefaults.daysBack` | number | 90 | Search window in days |
| `gmail.searchDefaults.excludeCategories` | array | [] | Gmail categories to exclude |

### Per-Repo Filters

Apply Gmail filters to specific repositories:

```json
{
  "repos": [
    {
      "name": "my-app",
      "path": "~/code/my-app",
      "gmailFilters": ["from:team@company.com", "label:my-app"]
    }
  ]
}
```

When searching for components related to `my-app`, these filters are added to the Gmail query.

## MCP Setup

This skill is MCP-agnostic and works with any Gmail MCP that provides:

- `gmail_search_emails` (required)
- `gmail_read_email` (optional)
- `gmail_list_labels` (optional)

### Example MCP Configuration

Add to `~/.claude.json` or project `.mcp.json`:

```json
{
  "mcpServers": {
    "gmail": {
      "type": "sse",
      "url": "https://your-gmail-mcp.example.com/sse"
    }
  }
}
```

## Evidence Classification

The skill classifies emails into evidence types:

| Type | Indicators | Status Contribution |
|------|------------|---------------------|
| Design Review | "review", "feedback", "design" in subject | In Progress |
| Planning Document | "spec", "plan", "timeline" in subject | Planned |
| Active Discussion | Multiple replies in thread | In Progress |
| Discussion | Clear work-related reference | Discussed |
| Mention | Casual/passing reference | Discussed |

## Output Format

```markdown
## Gmail Evidence: authentication

**Search Query:** `(authentication) after:2025-10-17 -category:promotions`
**Emails Found:** 3
**Date Range:** 2026-01-08 to 2026-01-11

### Email Summary

| Date | From | Subject | Type | Relevance |
|------|------|---------|------|-----------|
| 2026-01-11 | bob@co.com | Re: Auth design review | Design Review | High |

### Evidence Summary

| Evidence Type | Count | Suggests Status |
|---------------|-------|-----------------|
| Design Review | 2 | In Progress |

**Recommended Status:** In Progress (based on Design Review evidence)
```

## Integration with /project-status

When Gmail is enabled, `/project-status` automatically invokes `/gmail-check` for each component. Email evidence is combined with:

- Local git repository evidence
- GitHub PR/issue evidence
- Linear issue evidence
- Meeting transcript evidence

## Troubleshooting

### Gmail Not Configured

Ensure `.entourage/repos.json` has `gmail.enabled: true`.

### MCP Not Found

1. Check MCP configuration in `~/.claude.json` or `.mcp.json`
2. Verify the Gmail MCP provides `gmail_search_emails` tool
3. Complete OAuth authentication for the Gmail MCP
4. Restart Claude Code to reload MCP changes

### No Results

- Try broader search terms
- Extend `daysBack` in configuration
- Check if component uses different naming in emails
- Verify category exclusions aren't filtering relevant emails

## Evaluations

Test cases are defined in `evaluations/evaluation.json`. Categories:

- **Regression**: Must pass 100% (error handling, output format)
- **Capability**: Target 80%+ (search, classification, filtering)
- **Adversarial**: Target 90%+ (hallucination prevention, status inflation)

Run evaluations manually since MCP tools aren't available in automated tests.
