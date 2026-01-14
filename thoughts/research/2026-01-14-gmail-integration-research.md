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

## Deep Dive: MCP Server Data Schema

### What Third-Party Gmail MCP Servers Actually Pull

The GongRzhe/Gmail-MCP-Server makes these Gmail API calls under the hood:

**API Endpoints Called:**
```
users.messages.list()        # Search/list emails
users.messages.get()         # Full message content
users.messages.send()        # Send emails
users.messages.modify()      # Add/remove labels
users.messages.delete()      # Permanent delete
users.messages.attachments.get()  # Download attachments
users.drafts.create()        # Create drafts
users.labels.list/create/update/delete()
users.settings.filters.list/create/get/delete()
```

**OAuth Scopes Requested:**
```
https://www.googleapis.com/auth/gmail.modify   # Read + write + labels
https://www.googleapis.com/auth/gmail.settings.basic  # Filter management
```

**Data Schema Returned (per message):**

```typescript
interface GmailMessage {
  id: string;                    // Message ID
  threadId: string;              // Thread ID for grouping
  labelIds: string[];            // ["INBOX", "UNREAD", "Label_123"]
  snippet: string;               // First ~100 chars preview
  historyId: string;             // For sync/polling
  internalDate: string;          // Epoch ms timestamp
  sizeEstimate: number;          // Bytes

  payload: {
    mimeType: string;            // "multipart/alternative", "text/plain"
    headers: [                   // Parsed headers
      { name: "From", value: "alice@example.com" },
      { name: "To", value: "bob@example.com" },
      { name: "Subject", value: "Design Review" },
      { name: "Date", value: "Mon, 13 Jan 2025 10:00:00 -0800" }
    ];
    body: {
      data: string;              // Base64-encoded content
      size: number;
    };
    parts?: MessagePart[];       // Nested MIME parts for multipart
  };

  // Only with format=RAW
  raw?: string;                  // Full RFC 2822 base64url encoded
}

interface Attachment {
  attachmentId: string;
  filename: string;
  mimeType: string;
  size: number;
}
```

**Credential Storage:**
- OAuth keys: `~/.gmail-mcp/gcp-oauth.keys.json`
- Access/refresh tokens: `~/.gmail-mcp/credentials.json`
- Configurable via env vars: `GMAIL_CREDENTIALS_PATH`, `GMAIL_OAUTH_PATH`

### MCP vs Direct API: Key Differences

| Aspect | Third-Party MCP Server | Direct Gmail API |
|--------|------------------------|------------------|
| **Your Code** | None - use npm package | You write & control it |
| **Credential Flow** | Through their OAuth handler | Your OAuth implementation |
| **Data Access** | They decode/transform | Raw API response |
| **Scope Control** | Their choice (often broad) | You choose exactly |
| **Trust Model** | Trust their code + npm | Trust only Google |
| **Updates** | They control | You control |
| **Auditing** | Read their source | Full visibility |

**Privacy Concerns with Third-Party MCP:**
1. **Code runs locally** - but you're trusting their npm package
2. **Credentials stored locally** - but their code handles them
3. **Scopes may be broader than needed** - `gmail.modify` vs `gmail.readonly`
4. **No transparency** - code can change with `npm update`

---

## Building Your Own Gmail MCP Server (Privacy-First)

### Why Build Your Own

1. **Full code control** - audit every line
2. **Minimal scopes** - request only `gmail.readonly`
3. **No npm supply chain risk** - no third-party dependencies for Gmail
4. **Custom schema** - return only fields you need for Entourage

### Minimal MCP Server Structure

```
entourage-gmail-mcp/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts          # MCP server entry
│   ├── gmail-client.ts   # Direct Gmail API wrapper
│   └── oauth.ts          # OAuth flow handler
└── README.md
```

### Dependencies (Minimal)

```json
{
  "name": "entourage-gmail-mcp",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "googleapis": "^140.0.0",
    "zod": "^3.25.0"
  }
}
```

### MCP Server Code (src/index.ts)

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { GmailClient } from "./gmail-client.js";

const server = new McpServer({
  name: "entourage-gmail",
  version: "1.0.0",
});

const gmail = new GmailClient();

// Tool 1: Search emails (read-only)
server.tool(
  "search_emails",
  {
    query: z.string().describe("Gmail search query (e.g., 'from:alice subject:design')"),
    maxResults: z.number().optional().default(10),
  },
  async ({ query, maxResults }) => {
    const results = await gmail.searchMessages(query, maxResults);

    // Return only what Entourage needs - no raw content
    const simplified = results.map(msg => ({
      id: msg.id,
      threadId: msg.threadId,
      from: msg.from,
      subject: msg.subject,
      date: msg.date,
      snippet: msg.snippet,
    }));

    return {
      content: [{
        type: "text",
        text: JSON.stringify(simplified, null, 2)
      }],
    };
  }
);

// Tool 2: Read single email
server.tool(
  "read_email",
  {
    messageId: z.string().describe("Gmail message ID"),
  },
  async ({ messageId }) => {
    const message = await gmail.getMessage(messageId);

    // Return structured data, not raw API response
    return {
      content: [{
        type: "text",
        text: JSON.stringify({
          id: message.id,
          from: message.from,
          to: message.to,
          subject: message.subject,
          date: message.date,
          body: message.textPlain,  // Just plain text, not HTML
          hasAttachments: message.attachments.length > 0,
        }, null, 2),
      }],
    };
  }
);

// Start server with stdio transport
const transport = new StdioServerTransport();
await server.connect(transport);
```

### Gmail Client Wrapper (src/gmail-client.ts)

```typescript
import { google } from "googleapis";
import { OAuth2Client } from "google-auth-library";
import * as fs from "fs";
import * as path from "path";

const SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]; // MINIMAL
const CREDENTIALS_PATH = path.join(
  process.env.HOME || "~",
  ".entourage",
  "gmail-credentials.json"
);
const TOKEN_PATH = path.join(
  process.env.HOME || "~",
  ".entourage",
  "gmail-token.json"
);

export class GmailClient {
  private auth: OAuth2Client | null = null;
  private gmail: any = null;

  async initialize() {
    if (this.gmail) return;

    const credentials = JSON.parse(fs.readFileSync(CREDENTIALS_PATH, "utf8"));
    const { client_id, client_secret, redirect_uris } = credentials.installed;

    this.auth = new google.auth.OAuth2(client_id, client_secret, redirect_uris[0]);

    // Load saved tokens
    if (fs.existsSync(TOKEN_PATH)) {
      const token = JSON.parse(fs.readFileSync(TOKEN_PATH, "utf8"));
      this.auth.setCredentials(token);
    } else {
      throw new Error("Gmail not authenticated. Run: npx entourage-gmail-mcp auth");
    }

    this.gmail = google.gmail({ version: "v1", auth: this.auth });
  }

  async searchMessages(query: string, maxResults: number = 10) {
    await this.initialize();

    const res = await this.gmail.users.messages.list({
      userId: "me",
      q: query,
      maxResults,
    });

    if (!res.data.messages) return [];

    // Batch fetch message metadata (not full content)
    const messages = await Promise.all(
      res.data.messages.map((m: any) => this.getMessageMetadata(m.id))
    );

    return messages;
  }

  async getMessageMetadata(messageId: string) {
    await this.initialize();

    const res = await this.gmail.users.messages.get({
      userId: "me",
      id: messageId,
      format: "metadata",  // Only headers, not body
      metadataHeaders: ["From", "To", "Subject", "Date"],
    });

    const headers = res.data.payload?.headers || [];
    const getHeader = (name: string) =>
      headers.find((h: any) => h.name === name)?.value || "";

    return {
      id: res.data.id,
      threadId: res.data.threadId,
      from: getHeader("From"),
      to: getHeader("To"),
      subject: getHeader("Subject"),
      date: getHeader("Date"),
      snippet: res.data.snippet,
    };
  }

  async getMessage(messageId: string) {
    await this.initialize();

    const res = await this.gmail.users.messages.get({
      userId: "me",
      id: messageId,
      format: "full",
    });

    // Parse the complex MIME structure
    const headers = res.data.payload?.headers || [];
    const getHeader = (name: string) =>
      headers.find((h: any) => h.name === name)?.value || "";

    // Extract plain text body
    const textPlain = this.extractTextPlain(res.data.payload);

    // Get attachment info (not content)
    const attachments = this.extractAttachmentInfo(res.data.payload);

    return {
      id: res.data.id,
      threadId: res.data.threadId,
      from: getHeader("From"),
      to: getHeader("To"),
      subject: getHeader("Subject"),
      date: getHeader("Date"),
      textPlain,
      attachments,
    };
  }

  private extractTextPlain(payload: any): string {
    if (!payload) return "";

    if (payload.mimeType === "text/plain" && payload.body?.data) {
      return Buffer.from(payload.body.data, "base64").toString("utf8");
    }

    if (payload.parts) {
      for (const part of payload.parts) {
        const text = this.extractTextPlain(part);
        if (text) return text;
      }
    }

    return "";
  }

  private extractAttachmentInfo(payload: any): Array<{filename: string, mimeType: string, size: number}> {
    const attachments: any[] = [];

    const traverse = (part: any) => {
      if (part.filename && part.body?.attachmentId) {
        attachments.push({
          filename: part.filename,
          mimeType: part.mimeType,
          size: part.body.size || 0,
        });
      }
      if (part.parts) {
        part.parts.forEach(traverse);
      }
    };

    if (payload) traverse(payload);
    return attachments;
  }
}
```

### Claude Desktop Configuration

```json
{
  "mcpServers": {
    "entourage-gmail": {
      "command": "node",
      "args": ["/path/to/entourage-gmail-mcp/dist/index.js"]
    }
  }
}
```

### Key Privacy Advantages of Your Own MCP

| Feature | Third-Party MCP | Your Own MCP |
|---------|-----------------|--------------|
| **OAuth Scope** | `gmail.modify` (read+write) | `gmail.readonly` only |
| **Data Returned** | Full API response | Only fields you need |
| **Credential Location** | `~/.gmail-mcp/` (their choice) | `~/.entourage/` (your choice) |
| **Code Audit** | Must trust npm | You wrote it |
| **Attack Surface** | npm supply chain | Only googleapis |
| **Update Control** | Auto-updates risk | You control versions |

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
