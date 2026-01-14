# Gmail Integration Research for Entourage Plugin

**Date:** 2026-01-14
**Purpose:** Research approaches to pull and parse Gmail information for use with Entourage skills and local folder context databases.

---

## Executive Summary

There are **three viable approaches** for integrating Gmail with the Entourage plugin:

| Approach | Best For | Complexity | Entourage Fit |
|----------|----------|------------|---------------|
| **MCP Server** | Claude Code/Desktop users | Low-Medium | Excellent |
| **Direct Gmail API** | Custom skill with Python/Node | Medium-High | Good |
| **Domain-Wide Delegation** | Enterprise/Workspace orgs | High | Limited |

**Recommendation:** Use an **MCP Server** for immediate integration, with the option to build a dedicated `/gmail-check` skill for deeper context database integration.

---

## Approach 1: MCP Server (Recommended)

### Overview

Model Context Protocol (MCP) servers provide plug-and-play Gmail integration for Claude. Several mature implementations exist that can be installed directly.

### Available MCP Servers

#### 1. GongRzhe/Gmail-MCP-Server (Most Feature-Complete)

**Installation:**
```bash
npx -y @smithery/cli install @gongrzhe/server-gmail-autoauth-mcp --client claude
```

**Available Tools (16 total):**

| Tool | Description | Use for Entourage |
|------|-------------|-------------------|
| `search_emails` | Query using Gmail search syntax | Find emails about components |
| `read_email` | Retrieve full content + metadata | Extract evidence from threads |
| `list_email_labels` | Get all labels | Organize by project/topic |
| `download_attachment` | Save attachments locally | Get design specs, docs |
| `send_email` | Send with attachments | (Future: status updates) |
| `batch_modify_emails` | Label multiple emails | Organize findings |

**Configuration for Claude Desktop:**
```json
{
  "mcpServers": {
    "gmail": {
      "command": "npx",
      "args": ["@gongrzhe/server-gmail-autoauth-mcp"]
    }
  }
}
```

**Authentication:**
- OAuth 2.0 with auto browser launch
- Credentials stored in `~/.gmail-mcp/`
- Requires `gcp-oauth.keys.json` from Google Cloud Console

#### 2. Shravan1610/Gmail-mcp-server (Docker-Based)

**Tools:**
- `gmail_list_messages` - Search emails
- `gmail_get_message` - Read full content
- `gmail_send_message` - Send new emails
- `gmail_reply_message` - Reply to threads
- `gmail_modify_labels` - Manage labels

**Security Features:**
- Credentials as Docker secrets
- Scoped OAuth permissions
- No plaintext credential storage

### MCP Integration with Entourage

**How it works with skills:**

1. User installs Gmail MCP server
2. Entourage skill (e.g., `/project-status`) can reference MCP tools
3. Skill instructions can include Gmail searches as evidence sources

**Example skill workflow:**
```markdown
## Gathering Gmail Evidence

If the user has Gmail MCP configured:
1. Search for emails mentioning the component: `search_emails "auth system"`
2. Read relevant threads for context
3. Extract sender, date, and key quotes
4. Include as "Discussed" or "In Progress" evidence
```

---

## Approach 2: Direct Gmail API

### Overview

Build a custom skill that directly calls the Gmail API using Python or Node.js scripts. More control but requires more setup.

### Authentication Options

#### Option A: OAuth 2.0 (User Consent)

Best for personal Gmail accounts.

**Required Scopes:**

| Scope | Access Level | Use Case |
|-------|--------------|----------|
| `gmail.readonly` | Read-only access | Best for evidence gathering |
| `gmail.metadata` | Headers only | Lightweight search |
| `gmail.modify` | Read + label | Organize findings |
| `gmail.send` | Send emails | Status notifications |
| `mail.google.com` | Full access | IMAP/SMTP (avoid if possible) |

**Recommendation:** Use `gmail.readonly` for minimum viable integration.

**Setup Steps:**
1. Create project in Google Cloud Console
2. Enable Gmail API
3. Configure OAuth consent screen
4. Create OAuth 2.0 Client ID (Desktop app type)
5. Download `credentials.json`
6. Run OAuth flow to get tokens

#### Option B: Service Account with Domain-Wide Delegation

Best for Google Workspace organizations.

**Requirements:**
- Google Workspace admin access
- Service account with JSON key
- Domain-wide delegation enabled in Admin Console

**Security Considerations:**
- Can impersonate any user in the domain
- Requires super admin to authorize
- Changes can take up to 24 hours

### Gmail API Key Operations

**List Messages:**
```python
# Python example
from googleapiclient.discovery import build

service = build('gmail', 'v1', credentials=creds)
results = service.users().messages().list(
    userId='me',
    q='subject:auth system after:2025/01/01',
    maxResults=10
).execute()
```

**Get Message Content:**
```python
message = service.users().messages().get(
    userId='me',
    id=message_id,
    format='full'  # or 'metadata' for headers only
).execute()
```

**Gmail Search Operators:**
| Operator | Example | Description |
|----------|---------|-------------|
| `from:` | `from:alice@company.com` | Sender filter |
| `to:` | `to:team@company.com` | Recipient filter |
| `subject:` | `subject:design review` | Subject line |
| `after:` | `after:2025/01/01` | Date range |
| `has:attachment` | - | Has attachments |
| `label:` | `label:project-x` | By label |
| `in:` | `in:inbox` | Location |

### Parsing Messages

**npm package:** `gmail-api-parse-message`
```javascript
import parseMessage from 'gmail-api-parse-message';

const parsed = parseMessage(rawMessage);
// Returns: { textPlain, textHtml, headers, attachments }
```

---

## Approach 3: Configuration Extension

### Extending `.entourage/repos.json`

Add optional Gmail section following existing patterns:

```json
{
  "github": {
    "token": "ghp_xxx",
    "defaultOrg": "my-org"
  },
  "gmail": {
    "enabled": true,
    "credentialsPath": "~/.gmail-mcp/gcp-oauth.keys.json",
    "scopes": ["https://www.googleapis.com/auth/gmail.readonly"],
    "searchDefaults": {
      "maxResults": 20,
      "includeSpam": false
    }
  },
  "repos": [...]
}
```

### Alternative: MCP Reference

Since MCP handles its own auth, could simply flag MCP availability:

```json
{
  "integrations": {
    "gmail": {
      "type": "mcp",
      "server": "@gongrzhe/server-gmail-autoauth-mcp"
    }
  }
}
```

---

## Proposed Skill: `/gmail-check`

### Skill Design

```
skills/gmail-check/
├── SKILL.md              # Main skill instructions
├── README.md             # Documentation
└── evaluations/
    ├── evaluation.json
    └── fixtures/
        ├── search-found/
        ├── no-results/
        └── auth-failed/
```

### SKILL.md Structure (Draft)

```yaml
---
name: gmail-check
description: Search Gmail for evidence about project components and features
---
```

**Workflow:**
1. Check if Gmail MCP or credentials available
2. Parse component/feature names from input
3. Build Gmail search query
4. Execute search via MCP tool or API
5. Parse results for relevant evidence
6. Return structured output with quotes, senders, dates

### Output Format

Match existing skill patterns:

```markdown
## Gmail Evidence: Auth System

| Date | From | Subject | Relevance |
|------|------|---------|-----------|
| 2025-01-10 | alice@co.com | Auth design review | Design feedback |
| 2025-01-08 | bob@co.com | Re: Login flow | Implementation discussion |

### Key Quotes

> "We should use JWT tokens for the auth system" - Alice (2025-01-10)
```

### Integration with `/project-status`

```markdown
## Evidence Sources

1. ✅ Transcripts (existing)
2. ✅ Local git repos (existing)
3. ✅ GitHub API (existing)
4. 🆕 Gmail threads (new)
```

Gmail evidence would contribute to:
- **"Discussed"** - Email threads mentioning the component
- **"In Progress"** - Active email threads with recent replies
- **"Planned"** - Emails with attached specs/designs

---

## Security Considerations

### Credential Storage

| Method | Location | Gitignore | Security Level |
|--------|----------|-----------|----------------|
| MCP default | `~/.gmail-mcp/` | N/A (system) | High |
| Service account | `.entourage/` | Required | Medium |
| OAuth tokens | `.entourage/` | Required | Medium |

### Scope Recommendations

**For read-only evidence gathering:**
```
https://www.googleapis.com/auth/gmail.readonly
```

**For full integration (future):**
```
https://www.googleapis.com/auth/gmail.modify
https://www.googleapis.com/auth/gmail.send
```

### Google Verification Requirements

- Apps using restricted scopes require security assessment
- Personal use apps can be "unverified" (100 user limit)
- Production apps need privacy policy and verification

---

## Implementation Roadmap

### Phase 1: MCP Integration (Quick Win)

1. Document MCP server setup for Entourage users
2. Update `/project-status` to reference Gmail MCP tools
3. Add example searches for component evidence

**Effort:** 1-2 days

### Phase 2: Dedicated `/gmail-check` Skill

1. Create skill directory structure
2. Write SKILL.md with search workflow
3. Add evaluation fixtures
4. Integrate with `/project-status`

**Effort:** 3-5 days

### Phase 3: Full API Integration (Optional)

1. Add Python/Node.js Gmail API wrapper
2. Implement credential management
3. Create `.entourage/gmail.json` config schema
4. Add batch operations for efficiency

**Effort:** 1-2 weeks

---

## Resources

### Official Documentation

- [Gmail API Overview](https://developers.google.com/workspace/gmail/api)
- [OAuth 2.0 for Google APIs](https://developers.google.com/identity/protocols/oauth2)
- [Gmail API Scopes](https://developers.google.com/workspace/gmail/api/auth/scopes)
- [Domain-Wide Delegation](https://support.google.com/a/answer/162106)

### MCP Servers

- [GongRzhe/Gmail-MCP-Server](https://github.com/GongRzhe/Gmail-MCP-Server) - Most comprehensive
- [Shravan1610/Gmail-mcp-server](https://github.com/Shravan1610/Gmail-mcp-server) - Docker-based
- [theposch/gmail-mcp](https://github.com/theposch/gmail-mcp) - Lightweight

### Libraries

- [googleapis (Node.js)](https://www.npmjs.com/package/googleapis) - Official Google API client
- [gmail-api-parse-message](https://www.npmjs.com/package/gmail-api-parse-message) - Message parser
- [node-gmail-api](https://www.npmjs.com/package/node-gmail-api) - Batch operations

### Claude Code

- [MCP Integration Docs](https://code.claude.com/docs/en/mcp)

---

## Appendix: Gmail Search Query Examples

### For Entourage Context

```
# Find design discussions about auth
subject:design (auth OR authentication OR login) after:2024/06/01

# Find code review emails
subject:(review OR PR OR "pull request") from:github.com

# Find planning emails about a feature
(roadmap OR plan OR spec) (database OR migration) has:attachment

# Find recent team discussions
to:team@company.com after:2025/01/01 -category:promotions
```

### Building Queries from Components

```python
def build_query(component_name, months_back=3):
    date = (datetime.now() - timedelta(days=months_back*30)).strftime('%Y/%m/%d')
    return f'({component_name}) after:{date} -category:promotions -category:social'
```
