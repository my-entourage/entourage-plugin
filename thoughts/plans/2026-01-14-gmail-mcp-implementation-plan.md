# Gmail MCP Server Implementation Plan

**Date:** 2026-01-14
**Status:** Draft
**Related:** `thoughts/plans/2026-01-14-gmail-skill-implementation-plan.md`

---

## Executive Summary

This plan covers the implementation of `entourage-gmail-mcp`, a privacy-first Gmail MCP server that provides read-only email access for Entourage skills. The server is intentionally minimal—3 tools with `gmail.readonly` scope only.

**Key Design Principle:** This MCP server is optional. Skills reference tools by name (`gmail_search_emails`), not server name. Users may substitute any compatible Gmail MCP.

---

## Architecture Context

```
┌─────────────────────────────────────────────────────────────────┐
│                    User's MCP Configuration                      │
│  (User chooses: global ~/.claude.json OR project .mcp.json)     │
└─────────────────────────────────────────────────────────────────┘
                               │
                    MCP provides tools:
                    - gmail_search_emails
                    - gmail_read_email
                    - gmail_list_labels
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    entourage-plugin Skills                       │
│  /gmail-check: Calls gmail_* tools, formats evidence            │
│  /project-status: Orchestrates evidence from multiple sources   │
└─────────────────────────────────────────────────────────────────┘
```

The MCP server is the **access layer**; skills are the **intelligence layer**.

---

## Repository Structure

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
│       ├── read-email.ts     # read_email tool
│       └── list-labels.ts    # list_labels tool
├── scripts/
│   └── auth.ts               # CLI auth command
├── tests/
│   ├── tools/
│   │   ├── search-emails.test.ts
│   │   ├── read-email.test.ts
│   │   └── list-labels.test.ts
│   └── fixtures/
│       └── gmail-api-responses/
│           ├── search-results.json
│           ├── message-full.json
│           └── labels-list.json
└── docs/
    └── setup.md
```

---

## MCP Tools Specification

### Tool 1: `search_emails`

**Purpose:** Search Gmail with query syntax

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | Gmail search query (same syntax as Gmail search box) |
| `maxResults` | number | No | Maximum emails to return (default: 20, max: 100) |

**Returns:**
```typescript
interface SearchResult {
  id: string;           // Message ID
  threadId: string;     // Thread ID for grouping
  from: string;         // Sender email/name
  subject: string;      // Email subject
  date: string;         // ISO 8601 date
  snippet: string;      // Preview text (~200 chars)
  labels: string[];     // Gmail labels
}
```

**Example queries:**
```
auth system after:2025/10/01 -category:promotions
from:alice@company.com has:attachment
subject:(review OR feedback) database
```

### Tool 2: `read_email`

**Purpose:** Get full email content

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `messageId` | string | Yes | Message ID from search results |

**Returns:**
```typescript
interface EmailContent {
  id: string;
  threadId: string;
  from: string;
  to: string[];
  cc: string[];
  subject: string;
  date: string;
  body: {
    text: string;       // Plain text body
    html?: string;      // HTML body (if available)
  };
  attachments: Array<{
    filename: string;
    mimeType: string;
    size: number;
  }>;
}
```

### Tool 3: `list_labels`

**Purpose:** List available Gmail labels for filtering

**Parameters:** None

**Returns:**
```typescript
interface Label {
  id: string;
  name: string;
  type: 'system' | 'user';
  messageCount?: number;
}
```

---

## Design Principles

### 1. Minimal Scope

Request only `gmail.readonly` OAuth scope:
- Can read and search emails
- Cannot send, modify, or delete
- Cannot access other Google services

### 2. Local Credential Storage

```
~/.entourage/
├── gmail-credentials.json    # OAuth client credentials
└── gmail-token.json          # Refresh token (user-specific)
```

Never store credentials in:
- Project directories
- Version control
- Environment variables in code

### 3. Filtered Output

Return only necessary fields—no raw API dumps:

```typescript
// ❌ Don't return raw Gmail API response
return response.data;

// ✅ Return structured, minimal data
return {
  id: message.id,
  from: parseFrom(message),
  subject: getHeader(message, 'Subject'),
  date: getHeader(message, 'Date'),
  snippet: message.snippet
};
```

### 4. No Third-Party Dependencies

Allowed dependencies only:
- `@modelcontextprotocol/sdk` — MCP server framework
- `googleapis` — Official Google API client
- `zod` — Schema validation

No additional libraries for logging, HTTP, etc.

---

## Implementation

### package.json

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
    "auth": "node dist/scripts/auth.js",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "googleapis": "^140.0.0",
    "zod": "^3.25.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0",
    "vitest": "^2.0.0"
  }
}
```

### src/index.ts (Entry Point)

```typescript
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { searchEmailsTool } from './tools/search-emails.js';
import { readEmailTool } from './tools/read-email.js';
import { listLabelsTool } from './tools/list-labels.js';

const server = new Server(
  { name: 'entourage-gmail-mcp', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

// Register tools
server.setRequestHandler('tools/list', () => ({
  tools: [searchEmailsTool.definition, readEmailTool.definition, listLabelsTool.definition]
}));

server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case 'gmail_search_emails':
      return searchEmailsTool.handler(args);
    case 'gmail_read_email':
      return readEmailTool.handler(args);
    case 'gmail_list_labels':
      return listLabelsTool.handler(args);
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

// Start server
const transport = new StdioServerTransport();
await server.connect(transport);
```

### OAuth Flow

```typescript
// src/oauth.ts
import { google } from 'googleapis';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';

const SCOPES = ['https://www.googleapis.com/auth/gmail.readonly'];
const TOKEN_PATH = join(homedir(), '.entourage', 'gmail-token.json');
const CREDENTIALS_PATH = join(homedir(), '.entourage', 'gmail-credentials.json');

export async function getAuthClient() {
  if (!existsSync(CREDENTIALS_PATH)) {
    throw new Error(
      'Gmail credentials not found. Run: entourage-gmail-mcp auth --setup'
    );
  }

  const credentials = JSON.parse(readFileSync(CREDENTIALS_PATH, 'utf-8'));
  const { client_id, client_secret, redirect_uris } = credentials.installed;

  const oauth2Client = new google.auth.OAuth2(
    client_id, client_secret, redirect_uris[0]
  );

  if (existsSync(TOKEN_PATH)) {
    const token = JSON.parse(readFileSync(TOKEN_PATH, 'utf-8'));
    oauth2Client.setCredentials(token);
    return oauth2Client;
  }

  throw new Error(
    'Gmail not authenticated. Run: entourage-gmail-mcp auth'
  );
}

export function saveToken(token: object) {
  writeFileSync(TOKEN_PATH, JSON.stringify(token, null, 2));
}
```

---

## Testing Strategy

Following [Anthropic's eval guidance](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents):

### Unit Tests (Code-Based Graders)

Test individual tools with mocked Gmail API responses:

```typescript
// tests/tools/search-emails.test.ts
import { describe, it, expect, vi } from 'vitest';
import { searchEmailsTool } from '../../src/tools/search-emails';

describe('search_emails', () => {
  it('returns structured results from Gmail API', async () => {
    // Mock Gmail API
    vi.mock('googleapis', () => ({
      google: {
        gmail: () => ({
          users: {
            messages: {
              list: vi.fn().mockResolvedValue({
                data: { messages: [{ id: 'msg1', threadId: 'thread1' }] }
              }),
              get: vi.fn().mockResolvedValue({
                data: mockMessageResponse
              })
            }
          }
        })
      }
    }));

    const result = await searchEmailsTool.handler({
      query: 'test',
      maxResults: 10
    });

    expect(result).toHaveProperty('content');
    expect(result.content[0]).toHaveProperty('from');
    expect(result.content[0]).toHaveProperty('subject');
    expect(result.content[0]).toHaveProperty('snippet');
  });

  it('handles no results gracefully', async () => {
    // Mock empty response
    vi.mock('googleapis', () => ({
      google: {
        gmail: () => ({
          users: { messages: { list: vi.fn().mockResolvedValue({ data: {} }) } }
        })
      }
    }));

    const result = await searchEmailsTool.handler({ query: 'nonexistent' });

    expect(result.content).toEqual([]);
    expect(result.isError).toBeFalsy();
  });

  it('returns helpful error on auth failure', async () => {
    vi.mock('googleapis', () => ({
      google: {
        gmail: () => ({
          users: { messages: { list: vi.fn().mockRejectedValue(new Error('401')) } }
        })
      }
    }));

    const result = await searchEmailsTool.handler({ query: 'test' });

    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain('authentication');
  });
});
```

### Integration Tests

Test actual Gmail API with dedicated test account (gitignored credentials):

```typescript
// tests/integration/gmail-api.test.ts
import { describe, it, expect } from 'vitest';

describe.skipIf(!process.env.GMAIL_TEST_CREDENTIALS)('Gmail API Integration', () => {
  it('searches real Gmail account', async () => {
    const result = await searchEmailsTool.handler({
      query: 'from:me',
      maxResults: 5
    });

    expect(result.content.length).toBeLessThanOrEqual(5);
  });
});
```

### Test Fixtures

```json
// tests/fixtures/gmail-api-responses/search-results.json
{
  "messages": [
    {
      "id": "18d1234567890abc",
      "threadId": "18d1234567890abc"
    },
    {
      "id": "18d0987654321def",
      "threadId": "18d0987654321def"
    }
  ],
  "resultSizeEstimate": 2
}
```

---

## Error Handling

### Error Types

| Error | Detection | User Message |
|-------|-----------|--------------|
| No credentials | `!existsSync(CREDENTIALS_PATH)` | "Gmail credentials not found. Run: entourage-gmail-mcp auth --setup" |
| Not authenticated | `!existsSync(TOKEN_PATH)` | "Gmail not authenticated. Run: entourage-gmail-mcp auth" |
| Token expired | 401 response | "Gmail session expired. Run: entourage-gmail-mcp auth" |
| Invalid query | Gmail API error | "Invalid search query: {error.message}" |
| Rate limited | 429 response | "Gmail rate limit exceeded. Try again in a few minutes." |

### Error Response Format

```typescript
interface ToolError {
  isError: true;
  content: [{
    type: 'text';
    text: string;  // User-friendly message with resolution steps
  }];
}
```

---

## Setup Documentation

### docs/setup.md

```markdown
# Gmail MCP Server Setup

## Prerequisites

1. Google Cloud Project with Gmail API enabled
2. OAuth 2.0 credentials (Desktop app type)

## Quick Start

### 1. Get Google Cloud Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. Enable Gmail API: APIs & Services → Enable APIs → Search "Gmail"
4. Create OAuth credentials: APIs & Services → Credentials → Create → OAuth Client ID
5. Select "Desktop app" as application type
6. Download JSON file

### 2. Configure Credentials

```bash
mkdir -p ~/.entourage
mv ~/Downloads/client_secret_*.json ~/.entourage/gmail-credentials.json
```

### 3. Authenticate

```bash
npx entourage-gmail-mcp auth
```

This opens a browser for Google OAuth. Grant read-only Gmail access.

### 4. Add to Claude

Add to `~/.claude.json`:

```json
{
  "mcpServers": {
    "gmail": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "entourage-gmail-mcp"]
    }
  }
}
```

## Verify

In Claude Code:
```
What MCP tools are available?
```

Should show `gmail_search_emails`, `gmail_read_email`, `gmail_list_labels`.
```

---

## Implementation Phases

### Phase 1: Core MCP Server

**Goal:** Working MCP server with mocked tests

Tasks:
- [ ] Initialize repository with TypeScript + Vitest
- [ ] Implement `gmail_search_emails` tool
- [ ] Implement `gmail_read_email` tool
- [ ] Implement `gmail_list_labels` tool
- [ ] Write unit tests with mocked Gmail API
- [ ] Add OAuth flow scaffold

**Test Criteria:**
- All unit tests pass
- MCP server starts without errors
- Tools register correctly

### Phase 2: OAuth & Authentication

**Goal:** Complete auth flow working with real Gmail

Tasks:
- [ ] Implement CLI auth command
- [ ] Add token refresh logic
- [ ] Write integration tests (local only)
- [ ] Document credential setup

**Test Criteria:**
- Can authenticate with test Gmail account
- Token persists and refreshes correctly
- Clear error messages for auth failures

### Phase 3: Documentation & Publishing

**Goal:** Ready for npm publish and user adoption

Tasks:
- [ ] Write comprehensive README
- [ ] Add setup documentation
- [ ] Create example configurations
- [ ] Publish to npm as `entourage-gmail-mcp`

**Test Criteria:**
- `npx entourage-gmail-mcp --help` works
- Documentation covers all setup scenarios
- Works with Claude Desktop and Claude Code

---

## Comparison with Notion MCP

| Aspect | Notion MCP | Gmail MCP (This) |
|--------|------------|------------------|
| Repo | [makenotion/notion-mcp-server](https://github.com/makenotion/notion-mcp-server) | entourage-gmail-mcp |
| Auth | Internal integration token | OAuth 2.0 |
| Scopes | Full workspace access | `gmail.readonly` only |
| Tools | 21 tools | 3 tools (minimal) |
| Transport | STDIO + HTTP | STDIO only |
| Config | `NOTION_TOKEN` env var | `~/.entourage/gmail-token.json` |

---

## Security Considerations

1. **Minimal scope:** Only `gmail.readonly`—cannot modify emails
2. **Local tokens:** Credentials never leave user's machine
3. **No logging:** Never log email content or credentials
4. **User control:** Users can revoke access via Google account settings

---

## References

- [Gmail API Documentation](https://developers.google.com/gmail/api)
- [Gmail API Scopes](https://developers.google.com/workspace/gmail/api/auth/scopes)
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [Notion MCP Server](https://github.com/makenotion/notion-mcp-server) (reference implementation)
