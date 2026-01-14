---
name: gmail-check
description: Search Gmail for evidence about project components. Returns email threads, senders, dates, and relevance for status determination.
---

## Purpose

Search Gmail for email evidence related to project components and features. This skill queries Gmail via MCP to find discussions, design reviews, and planning emails that contribute to implementation status assessment.

## When to Use

- Directly invoked: `/gmail-check authentication`
- Checking for email discussions about a component
- Finding design review threads
- Looking for planning documents sent via email
- When invoked by other skills (like `/project-status`)

## Input

Component or feature name(s) to search for. Examples:
- `/gmail-check authentication`
- `/gmail-check user-dashboard payments`
- `/gmail-check database migration`

**Note:** Component searches are case-insensitive and use Gmail's search syntax.

---

## MCP Tools Used

This skill is MCP-agnostic and works with any Gmail MCP server that provides:

- `gmail_search_emails` - Search Gmail with query syntax (required)
- `gmail_read_email` - Get full email content (optional, for deep inspection)
- `gmail_list_labels` - List available labels for filtering (optional)

---

## Workflow

### Step 1: Check Configuration

Read `.entourage/repos.json` and verify Gmail is enabled.

**Check for `gmail.enabled` field:**
- If `gmail` section is missing or `gmail.enabled` is `false`, return setup instructions (see Error Handling).
- If `gmail.enabled` is `true`, proceed to Step 2.

**Extract configuration values:**
```json
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

### Step 2: Verify MCP Availability

Check if the `gmail_search_emails` MCP tool is available.

Attempt to use the tool. If it fails with a "tool not found" or connection error, return MCP setup guidance (see Error Handling).

### Step 3: Check for Repo-Specific Filters

If the input references a specific repo name, check for `gmailFilters` in that repo's configuration:

```json
{
  "repos": [
    {
      "name": "my-app",
      "gmailFilters": ["from:team@company.com", "label:my-app"]
    }
  ]
}
```

If `gmailFilters` is defined, include these in the search query.

### Step 4: Build Search Query

Construct a Gmail search query using:

1. **Component name(s)** from input - wrap in parentheses
2. **Date filter** - `after:YYYY-MM-DD` based on `daysBack` config (default: 90 days)
3. **Category exclusions** - from `excludeCategories` config
4. **Repo filters** - if applicable from Step 3

**Query format:**
```
({component_name}) after:{date} -category:promotions -category:social -category:spam {repo_filters}
```

**Example queries:**
- `/gmail-check auth` becomes: `(auth) after:2025-10-17 -category:promotions -category:social -category:spam`
- `/gmail-check auth login` becomes: `(auth login) after:2025-10-17 -category:promotions -category:social -category:spam`
- With repo filters: `(auth) after:2025-10-17 -category:promotions from:team@company.com label:my-app`

### Step 5: Execute Search

Call the `gmail_search_emails` MCP tool with the constructed query.

**Expected response schema:**
```typescript
{
  id: string;         // Message ID
  threadId: string;   // Thread ID
  from: string;       // Sender
  subject: string;    // Subject line
  date: string;       // ISO 8601 date
  snippet: string;    // Preview text
  labels?: string[];  // Gmail labels
}[]
```

If no results are returned, output the "No Results" message (see Error Handling).

### Step 6: Classify Evidence

For each email found, determine evidence type based on characteristics:

| Pattern | Evidence Type | Status Contribution |
|---------|---------------|---------------------|
| Subject contains "review", "feedback", "design" | Design Review | In Progress |
| Subject contains "spec", "plan", "timeline", "proposal" | Planning Document | Planned |
| Multiple replies in same thread (active discussion) | Active Discussion | In Progress |
| Email with attachment keywords (doc, pdf, spec) | Planning Document | Planned |
| Simple mention in body/snippet | Discussion | Discussed |
| Casual/passing reference (not main topic) | Mention | Discussed |

**Classification Rules:**

1. **Design Review**: Subject or snippet contains "review", "feedback", "design doc"
2. **Planning Document**: Subject contains "spec", "plan", "timeline", "proposal", or has attachment indicators
3. **Active Discussion**: Thread has multiple recent replies (same threadId, different messages)
4. **Discussion**: Clear reference to component in context of work discussion
5. **Mention**: Component name appears but is not the main topic (be conservative)

**IMPORTANT:** Do NOT overclaim status from casual mentions. If an email only briefly mentions the component in passing (e.g., "we also talked about X"), classify as "Mention" with status "Discussed", NOT "In Progress" or "Complete".

### Step 7: Generate Output

Format the results as structured markdown.

---

## Output Format

### With Emails Found

```markdown
## Gmail Evidence: {Component Name}

**Search Query:** `{query_used}`
**Emails Found:** {count}
**Date Range:** {oldest_date} to {newest_date}

### Email Summary

| Date | From | Subject | Type | Relevance |
|------|------|---------|------|-----------|
| 2026-01-10 | alice@co.com | Auth design review | Design Review | High |
| 2026-01-08 | bob@co.com | Re: Auth design review | Active Discussion | High |
| 2026-01-05 | carol@co.com | Sprint planning notes | Mention | Low |

### Evidence Summary

| Evidence Type | Count | Suggests Status |
|---------------|-------|-----------------|
| Design Review | 2 | In Progress |
| Planning Document | 1 | Planned |
| Discussion | 1 | Discussed |

**Recommended Status:** In Progress (based on Design Review evidence)
```

### No Emails Found

```markdown
## Gmail Evidence: {Component Name}

**Search Query:** `{query_used}`
**Emails Found:** 0

No Gmail evidence found for: {component_name}

Searched: {query}
Date range: last {days} days

Suggestions:
- Try broader search terms
- Extend the date range in `.entourage/repos.json`
- Check if component has different naming in email discussions
```

### Multiple Components

When checking multiple components, output each separately:

```markdown
## Gmail Evidence Summary

| Component | Emails | Top Evidence | Suggested Status |
|-----------|--------|--------------|------------------|
| auth | 3 | Design Review | In Progress |
| dashboard | 1 | Mention | Discussed |
| payments | 0 | - | Unknown |

### auth

[Individual component output...]

### dashboard

[Individual component output...]

### payments

No Gmail evidence found for: payments
```

---

## Error Handling

### Gmail Not Configured

If `.entourage/repos.json` is missing or has no `gmail` section:

```markdown
## Gmail Evidence

Gmail integration not configured.

Add to `.entourage/repos.json`:
```json
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

Then configure a Gmail MCP server in your Claude settings.
```

### MCP Not Available

If Gmail is enabled but MCP tools are not accessible:

```markdown
## Gmail Evidence

Gmail MCP tools not found. Gmail is enabled in config but the MCP server is not connected.

To configure Gmail MCP:

1. Ensure a Gmail MCP server is configured in `~/.claude.json` or `.mcp.json`
2. The MCP must provide the `gmail_search_emails` tool
3. Complete OAuth authentication for the Gmail MCP
4. Restart Claude Code to load MCP changes

Example MCP configuration:
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
```

### MCP Error

If the MCP tool returns an error:

```markdown
## Gmail Evidence

Gmail MCP error: {error_message}

Possible causes:
- OAuth token expired - re-authenticate with Gmail MCP
- MCP server not running
- Network connectivity issues

Try restarting Claude Code or re-authenticating with the Gmail MCP.
```

---

## Examples

### Example 1: Design Review Evidence

**Query:** `/gmail-check clerk-auth`

**Output:**

```markdown
## Gmail Evidence: clerk-auth

**Search Query:** `(clerk-auth) after:2025-10-17 -category:promotions -category:social -category:spam`
**Emails Found:** 3
**Date Range:** 2026-01-08 to 2026-01-11

### Email Summary

| Date | From | Subject | Type | Relevance |
|------|------|---------|------|-----------|
| 2026-01-11 | bob@company.com | Re: Clerk auth design review | Design Review | High |
| 2026-01-10 | alice@company.com | Clerk auth design review | Design Review | High |
| 2026-01-08 | carol@company.com | Auth implementation timeline | Planning Document | High |

### Evidence Summary

| Evidence Type | Count | Suggests Status |
|---------------|-------|-----------------|
| Design Review | 2 | In Progress |
| Planning Document | 1 | Planned |

**Recommended Status:** In Progress (based on Design Review evidence)
```

### Example 2: Casual Mention Only

**Query:** `/gmail-check payment-gateway`

**Output:**

```markdown
## Gmail Evidence: payment-gateway

**Search Query:** `(payment-gateway) after:2025-10-17 -category:promotions -category:social -category:spam`
**Emails Found:** 1
**Date Range:** 2026-01-05

### Email Summary

| Date | From | Subject | Type | Relevance |
|------|------|---------|------|-----------|
| 2026-01-05 | dave@company.com | Q1 roadmap discussion | Mention | Low |

### Evidence Summary

| Evidence Type | Count | Suggests Status |
|---------------|-------|-----------------|
| Mention | 1 | Discussed |

**Recommended Status:** Discussed (only casual mention found, not main topic)
```

### Example 3: No Evidence

**Query:** `/gmail-check nonexistent-feature`

**Output:**

```markdown
## Gmail Evidence: nonexistent-feature

**Search Query:** `(nonexistent-feature) after:2025-10-17 -category:promotions -category:social -category:spam`
**Emails Found:** 0

No Gmail evidence found for: nonexistent-feature

Searched: (nonexistent-feature) after:2025-10-17 -category:promotions -category:social -category:spam
Date range: last 90 days

Suggestions:
- Try broader search terms
- Extend the date range in `.entourage/repos.json`
- Check if component has different naming in email discussions
```

---

## After Output

This skill returns results to the calling context (usually `/project-status`). **Do not stop execution.**
Continue with the next step in the workflow or TODO list.
