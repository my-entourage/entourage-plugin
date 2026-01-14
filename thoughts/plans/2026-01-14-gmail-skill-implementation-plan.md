# Gmail Skill Implementation Plan

**Date:** 2026-01-14
**Status:** Draft
**Related Research:** `thoughts/research/2026-01-14-gmail-integration-research.md`

---

## Executive Summary

This plan outlines how to add Gmail integration to Entourage for pulling email evidence into context databases. Based on analysis of the existing architecture and the official [Notion MCP Server](https://github.com/makenotion/notion-mcp-server) pattern, I recommend a **hybrid approach**:

1. **`/gmail-check` skill** in `entourage-plugin` (matches existing patterns)
2. **`entourage-gmail-mcp`** as a separate, privacy-first MCP server repo
3. **Configuration extension** to `.entourage/repos.json`

---

## Decision: Where Should Gmail Live?

### Options Evaluated

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A: Skill Only** | `/gmail-check` in entourage-plugin, uses third-party MCP | Fast, no new repos | Trust third-party code |
| **B: Skill + Custom MCP** | Skill in plugin, own MCP server in separate repo | Privacy control, modular | Two repos to maintain |
| **C: Context Extractor Repo** | New `entourage-extractors` repo with Gmail, Notion, etc. | Centralized extractors | Different pattern from skills |
| **D: All-in-One** | MCP server code directly in entourage-plugin | Single repo | Bloats plugin with Node.js |

### Recommendation: Option B (Skill + Custom MCP)

**Rationale:**
1. Skills are markdown-only (no code) - matches existing pattern
2. MCP server needs TypeScript/Node.js - doesn't fit in plugin
3. Follows Notion's model: official MCP server ([makenotion/notion-mcp-server](https://github.com/makenotion/notion-mcp-server)) is separate from integrations
4. Privacy-first: user controls their own Gmail MCP with minimal scopes
5. Modular: skill works with any Gmail MCP (ours or third-party)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    entourage-plugin                             │
│  ┌─────────────────┐  ┌──────────────────┐  ┌───────────────┐  │
│  │ /project-status │  │ /github-repo-    │  │ /gmail-check  │  │
│  │   (orchestrator)│  │    check         │  │   (NEW)       │  │
│  └────────┬────────┘  └────────┬─────────┘  └───────┬───────┘  │
│           │                    │                    │           │
│           │  invokes skills    │                    │           │
│           ▼                    ▼                    ▼           │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                  .entourage/repos.json                     │ │
│  │  { github: {...}, gmail: {...}, repos: [...] }             │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
        ┌──────────┐   ┌───────────┐   ┌──────────────────┐
        │ gh CLI   │   │ Gmail MCP │   │ Local filesystem │
        │ (GitHub) │   │  Server   │   │    (git repos)   │
        └──────────┘   └─────┬─────┘   └──────────────────┘
                             │
                             ▼
              ┌──────────────────────────────┐
              │    entourage-gmail-mcp       │
              │  (separate repo, optional)   │
              │  - gmail.readonly scope only │
              │  - privacy-first design      │
              └──────────────────────────────┘
```

---

## Component 1: Configuration Extension

### Updated `.entourage/repos.json` Schema

```json
{
  "github": {
    "token": "ghp_xxx",
    "defaultOrg": "my-org"
  },
  "gmail": {
    "enabled": true,
    "method": "mcp",
    "mcp": {
      "server": "entourage-gmail",
      "command": "node",
      "args": ["/path/to/entourage-gmail-mcp/dist/index.js"]
    },
    "searchDefaults": {
      "maxResults": 20,
      "daysBack": 90,
      "excludeCategories": ["promotions", "social", "spam"]
    }
  },
  "repos": [
    {
      "name": "my-app",
      "path": "~/code/my-app",
      "github": "my-org/my-app",
      "gmailFilters": ["from:team@company.com", "label:my-app"]
    }
  ]
}
```

### Configuration Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `gmail.enabled` | boolean | No | Enable/disable Gmail integration |
| `gmail.method` | enum | No | `"mcp"` or `"api"` (future) |
| `gmail.mcp.server` | string | No | MCP server name for Claude config |
| `gmail.mcp.command` | string | No | Command to run MCP server |
| `gmail.mcp.args` | array | No | Arguments for MCP server |
| `gmail.searchDefaults.maxResults` | number | No | Max emails per search (default: 20) |
| `gmail.searchDefaults.daysBack` | number | No | Search window in days (default: 90) |
| `gmail.searchDefaults.excludeCategories` | array | No | Gmail categories to exclude |
| `repos[].gmailFilters` | array | No | Per-repo Gmail search filters |

### Example Configuration Template

Add to `examples/repos.json.example`:

```json
{
  "github": {
    "token": "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "defaultOrg": "my-org"
  },
  "gmail": {
    "enabled": true,
    "method": "mcp",
    "mcp": {
      "server": "entourage-gmail"
    },
    "searchDefaults": {
      "maxResults": 20,
      "daysBack": 90
    }
  },
  "repos": [
    {
      "name": "my-web-app",
      "path": "~/Documents/code/my-web-app",
      "mainBranch": "main",
      "github": "my-org/my-web-app",
      "gmailFilters": ["label:web-app-project"]
    }
  ]
}
```

---

## Component 2: `/gmail-check` Skill

### Directory Structure

```
skills/gmail-check/
├── SKILL.md              # Main skill definition
├── README.md             # User documentation
└── evaluations/
    ├── evaluation.json   # Test cases
    └── fixtures/
        ├── emails-found/
        │   ├── .entourage/repos.json
        │   └── mock-mcp-response.json
        ├── no-gmail-config/
        │   └── .entourage/repos.json
        └── auth-failed/
            └── .entourage/repos.json
```

### SKILL.md Content

```yaml
---
name: gmail-check
description: Search Gmail for evidence about project components. Returns email threads, senders, dates, and relevance for status determination.
---

## Purpose

Search Gmail for email evidence related to project components and features. This skill queries Gmail via MCP server to find discussions, design reviews, and planning emails that contribute to implementation status.

## Prerequisites

1. Gmail MCP server configured in Claude Desktop/Code
2. `.entourage/repos.json` with `gmail.enabled: true`
3. OAuth authentication completed for Gmail MCP

## Workflow

### Step 1: Check Gmail Configuration

Read `.entourage/repos.json` and verify:
- `gmail.enabled` is `true`
- `gmail.method` is configured (default: `"mcp"`)

If Gmail is not configured, return:
```
Gmail integration not configured.

To enable Gmail search, add to .entourage/repos.json:
{
  "gmail": {
    "enabled": true,
    "method": "mcp"
  }
}

And configure Gmail MCP server in Claude settings.
```

### Step 2: Build Search Query

For each component/feature name provided:

1. Parse the component name from input
2. Apply repo-specific filters if `repos[].gmailFilters` is set
3. Apply default exclusions from `gmail.searchDefaults.excludeCategories`
4. Build Gmail search query:

```
({component_name}) after:{days_back} -category:promotions -category:social
```

**Example queries:**
```
(auth system) after:2025/10/01 -category:promotions
(database migration) has:attachment after:2025/10/01
subject:(review OR feedback) (payment flow) after:2025/10/01
```

### Step 3: Execute Gmail Search

Use the MCP tool `search_emails` with the constructed query:

```
search_emails query="{gmail_query}" maxResults={max_results}
```

### Step 4: Process Results

For each email returned, extract:
- `id` - Message ID (for read_email if needed)
- `threadId` - Thread grouping
- `from` - Sender email/name
- `subject` - Email subject
- `date` - Date sent
- `snippet` - Preview text

### Step 5: Classify Evidence

Determine evidence type based on email characteristics:

| Pattern | Evidence Type | Status Contribution |
|---------|---------------|---------------------|
| Active thread (multiple recent replies) | Active Discussion | In Progress |
| Email with attachment (spec, design, doc) | Planning Document | Planned |
| Subject contains "review", "feedback" | Review Request | In Progress |
| Simple mention in body | Discussion | Discussed |
| No emails found | No Evidence | Unknown |

### Step 6: Output Format

Return a structured markdown table:

```markdown
## Gmail Evidence: {Component Name}

**Search Query:** `{query_used}`
**Emails Found:** {count}
**Date Range:** {oldest} to {newest}

### Email Summary

| Date | From | Subject | Type | Relevance |
|------|------|---------|------|-----------|
| 2025-01-10 | alice@co.com | Auth design review | Review | High |
| 2025-01-08 | bob@co.com | Re: Login flow | Discussion | Medium |

### Key Evidence

**Highest Relevance Email:**
- **From:** {sender}
- **Date:** {date}
- **Subject:** {subject}
- **Snippet:** "{snippet_text}"

### Evidence Summary

| Evidence Type | Count | Suggests Status |
|---------------|-------|-----------------|
| Design Reviews | 2 | In Progress |
| Planning Docs | 1 | Planned |
| Discussions | 3 | Discussed |

**Recommended Status:** {status} (based on {evidence_type})
```

## Error Handling

### No Gmail Configuration
```
⚠️ Gmail not configured in .entourage/repos.json

Add gmail section to enable email evidence gathering.
See: examples/repos.json.example
```

### MCP Server Not Available
```
⚠️ Gmail MCP server not responding

Verify Gmail MCP is configured in Claude settings:
1. Check claude_desktop_config.json has gmail server
2. Run authentication if needed: npx entourage-gmail-mcp auth
```

### Authentication Failed
```
⚠️ Gmail authentication failed

Re-authenticate with Gmail:
1. Run: npx entourage-gmail-mcp auth
2. Complete OAuth flow in browser
3. Retry search
```

### No Results Found
```
No Gmail evidence found for: {component_name}

Searched: {query}
Date range: last {days} days
Suggestion: Try broader search terms or extend date range
```

## Integration with /project-status

When invoked by `/project-status`, this skill returns evidence that contributes to the unified status hierarchy:

- **Gmail design review** → contributes to "In Progress"
- **Gmail with spec attachment** → contributes to "Planned"
- **Gmail simple mention** → contributes to "Discussed"

The `/project-status` skill combines Gmail evidence with:
1. Transcript evidence (highest for "Discussed")
2. Local repo evidence (code, tests)
3. GitHub evidence (PRs, issues, deployments)
```

---

## Component 3: `entourage-gmail-mcp` Repository

### Repository Structure

```
entourage-gmail-mcp/
├── package.json
├── tsconfig.json
├── README.md
├── src/
│   ├── index.ts              # MCP server entry point
│   ├── gmail-client.ts       # Gmail API wrapper
│   ├── oauth.ts              # OAuth flow handler
│   └── tools/
│       ├── search-emails.ts  # search_emails tool
│       └── read-email.ts     # read_email tool
├── scripts/
│   └── auth.ts               # CLI auth command
└── docs/
    └── setup.md              # Setup instructions
```

### Key Design Principles

1. **Minimal Scope:** Request only `gmail.readonly` (not `gmail.modify`)
2. **Local Credentials:** Store in `~/.entourage/gmail-token.json`
3. **Filtered Output:** Return only needed fields (no raw API dump)
4. **No Third-Party Dependencies:** Only `googleapis` + `@modelcontextprotocol/sdk`

### MCP Tools Provided

| Tool | Description | Parameters |
|------|-------------|------------|
| `search_emails` | Search Gmail with query | `query`, `maxResults` |
| `read_email` | Get full email content | `messageId` |
| `list_labels` | List Gmail labels | none |

### Package.json

```json
{
  "name": "entourage-gmail-mcp",
  "version": "1.0.0",
  "description": "Privacy-first Gmail MCP server for Entourage",
  "type": "module",
  "bin": {
    "entourage-gmail-mcp": "./dist/cli.js"
  },
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "auth": "node dist/scripts/auth.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "googleapis": "^140.0.0",
    "zod": "^3.25.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0"
  }
}
```

---

## Component 4: Update `/project-status` Skill

### Changes Required

Add Gmail as a fourth evidence source in the `/project-status` SKILL.md:

```markdown
## Evidence Sources

1. **Transcripts** - Meeting notes, voice memos in `data/transcripts/`
2. **Local Git Repos** - Code files, tests, commit history
3. **GitHub API** - PRs, issues, Actions, deployments
4. **Gmail** (NEW) - Email threads, design reviews, discussions

## Workflow Update

...

### Step 4: Gather Gmail Evidence (NEW)

If `.entourage/repos.json` has `gmail.enabled: true`:

1. Invoke `/gmail-check {components}`
2. Parse returned evidence table
3. Add to evidence synthesis:
   - Design review emails → "In Progress" evidence
   - Spec attachments → "Planned" evidence
   - Simple mentions → "Discussed" evidence

...
```

---

## Implementation Phases

### Phase 1: Skill Foundation (1-2 days)

**Tasks:**
- [ ] Create `skills/gmail-check/` directory structure
- [ ] Write SKILL.md with full workflow
- [ ] Add configuration schema to examples/repos.json.example
- [ ] Create basic evaluation.json with test cases
- [ ] Update `/project-status` to reference `/gmail-check`

**Deliverables:**
- `/gmail-check` skill that works with any Gmail MCP server
- Configuration documentation

### Phase 2: Custom MCP Server (3-5 days)

**Tasks:**
- [ ] Create `entourage-gmail-mcp` repository
- [ ] Implement `search_emails` tool with minimal scope
- [ ] Implement `read_email` tool
- [ ] Add OAuth CLI authentication flow
- [ ] Write setup documentation
- [ ] Test with Claude Desktop

**Deliverables:**
- Privacy-first Gmail MCP server
- npm package: `entourage-gmail-mcp`

### Phase 3: Integration & Testing (2-3 days)

**Tasks:**
- [ ] Create evaluation fixtures for `/gmail-check`
- [ ] Test end-to-end with `/project-status`
- [ ] Add error handling for edge cases
- [ ] Document full setup flow

**Deliverables:**
- Complete test coverage
- User documentation

### Phase 4: Future Enhancements (Optional)

- [ ] Add `notion-check` skill following same pattern
- [ ] Add Slack MCP integration
- [ ] Create `entourage-extractors` meta-package

---

## Evaluation Test Cases

### evaluation.json

```json
{
  "name": "gmail-check",
  "description": "Search Gmail for project evidence",
  "testCases": [
    {
      "id": "emails-found",
      "name": "Find relevant emails",
      "input": "/gmail-check auth system",
      "setup": {
        "description": "Gmail configured with matching emails",
        "mockMcpResponse": "fixtures/emails-found/mock-mcp-response.json"
      },
      "expectedOutput": {
        "contains": ["Gmail Evidence", "auth system", "From", "Subject"],
        "format": "table"
      }
    },
    {
      "id": "no-config",
      "name": "Gmail not configured",
      "input": "/gmail-check database",
      "setup": {
        "description": "No gmail section in repos.json"
      },
      "expectedOutput": {
        "contains": ["not configured", "gmail.enabled"],
        "notContains": ["Error", "crash"]
      }
    },
    {
      "id": "no-results",
      "name": "No emails match search",
      "input": "/gmail-check nonexistent-feature",
      "setup": {
        "description": "Gmail configured but no matching emails"
      },
      "expectedOutput": {
        "contains": ["No Gmail evidence found", "nonexistent-feature"],
        "status": "Unknown"
      }
    }
  ]
}
```

---

## Comparison: Gmail vs Notion MCP Patterns

| Aspect | Notion MCP (Reference) | Gmail MCP (Proposed) |
|--------|------------------------|----------------------|
| **Official Server** | [makenotion/notion-mcp-server](https://github.com/makenotion/notion-mcp-server) | `entourage-gmail-mcp` |
| **Auth Method** | Internal integration token | OAuth 2.0 |
| **Scopes** | Full workspace access | `gmail.readonly` only |
| **Tools Count** | 21 tools | 3 tools (minimal) |
| **Transport** | STDIO + HTTP | STDIO only |
| **Config** | `NOTION_TOKEN` env var | `~/.entourage/gmail-token.json` |

### Lessons from Notion MCP

1. **Separate server repo** - MCP server is its own npm package
2. **Markdown-friendly output** - Content returned in editable format
3. **Search-first** - `search` tool is primary entry point
4. **Environment-based auth** - Token via env var, not config file

---

## Open Questions

1. **Should Gmail MCP be in my-entourage org?**
   - Recommendation: Yes, as `my-entourage/entourage-gmail-mcp`

2. **Support third-party Gmail MCP servers?**
   - Recommendation: Yes, skill should work with any MCP server
   - Configuration allows specifying custom server

3. **Per-repo Gmail filters?**
   - Recommendation: Yes, via `repos[].gmailFilters` array
   - Allows project-specific email searches

4. **Batch vs individual email fetching?**
   - Recommendation: Start with list + selective read
   - Avoid fetching full content of all emails

---

## Success Criteria

- [ ] `/gmail-check` returns structured email evidence
- [ ] Works with any Gmail MCP server (not locked to ours)
- [ ] `/project-status` integrates Gmail evidence
- [ ] Configuration schema documented in examples
- [ ] Privacy: only `gmail.readonly` scope required
- [ ] Evaluation tests pass with 80%+ rate

---

## References

- [Gmail Integration Research](./2026-01-14-gmail-integration-research.md)
- [Official Notion MCP Server](https://github.com/makenotion/notion-mcp-server)
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [Gmail API Scopes](https://developers.google.com/workspace/gmail/api/auth/scopes)
