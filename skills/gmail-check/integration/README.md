# Gmail MCP Contract Testing

This directory contains contract schemas and validation tools for testing Gmail MCP implementations against the `/gmail-check` skill requirements.

## Overview

The `/gmail-check` skill is **MCP-agnostic** - it works with any Gmail MCP server that provides tools matching these contracts. This allows users to:

1. Use `entourage-gmail-mcp` (our reference implementation)
2. Build their own Gmail MCP
3. Use another third-party Gmail MCP

## Contract Schemas

Located in `contracts/`:

| File | Tool | Description |
|------|------|-------------|
| `search-emails.ts` | `gmail_search_emails` | Search Gmail with query syntax |
| `read-email.ts` | `gmail_read_email` | Get full email content |
| `list-labels.ts` | `gmail_list_labels` | List available Gmail labels |

### Required Tool Names

Your MCP must expose tools with these exact names:
- `gmail_search_emails`
- `gmail_read_email`
- `gmail_list_labels`

### Schema Definitions

#### gmail_search_emails

**Input:**
```typescript
{
  query: string;      // Gmail search query
  maxResults?: number; // Default: 20, Max: 100
}
```

**Output:** Array of:
```typescript
{
  id: string;         // Required - Message ID
  threadId: string;   // Required - Thread ID
  from: string;       // Required - Sender
  subject: string;    // Required - Subject line
  date: string;       // Required - ISO 8601 date
  snippet: string;    // Required - Preview text
  labels?: string[];  // Optional - Gmail labels
}
```

#### gmail_read_email

**Input:**
```typescript
{
  messageId: string;  // Message ID from search results
}
```

**Output:**
```typescript
{
  id: string;
  threadId: string;
  from: string;
  to: string[];
  cc?: string[];
  subject: string;
  date: string;       // ISO 8601
  body: {
    text: string;     // Required - Plain text
    html?: string;    // Optional - HTML version
  };
  attachments?: Array<{
    filename: string;
    mimeType: string;
    size: number;
  }>;
}
```

#### gmail_list_labels

**Input:** None

**Output:** Array of:
```typescript
{
  id: string;         // Required - Label ID
  name: string;       // Required - Display name
  type?: 'system' | 'user';  // Optional - Label type
  messageCount?: number;      // Optional - Message count
}
```

## Validating Your MCP

### Manual Validation

Since MCP tools aren't available in automated tests (session isolation), validate manually:

1. **Configure your MCP** in Claude settings:
   ```json
   {
     "mcpServers": {
       "gmail": {
         "type": "stdio",
         "command": "your-gmail-mcp-command"
       }
     }
   }
   ```

2. **Start a Claude session** and verify tools are available

3. **Test each tool**:
   - Call `gmail_list_labels` - should return array of labels
   - Call `gmail_search_emails` with `{ query: "test", maxResults: 5 }`
   - Call `gmail_read_email` with a message ID from search results

4. **Check response format** matches the schemas above

### Using the Validator

Import and use the validation functions:

```typescript
import {
  validateSearchEmails,
  validateReadEmail,
  validateListLabels,
} from './validator';

// After calling MCP tool, validate response:
const result = validateSearchEmails(mcpResponse);
if (!result.pass) {
  console.error('Validation failed:', result.errors);
}
```

## Common Issues

### Missing Required Fields

If validation fails with "Required", ensure your MCP returns all required fields:
- `id`, `threadId`, `from`, `subject`, `date`, `snippet` for search results
- `id`, `threadId`, `from`, `to`, `subject`, `date`, `body.text` for email content

### Date Format

Dates must be ISO 8601 format:
- ✅ `2026-01-15T10:30:00Z`
- ✅ `2026-01-15T10:30:00+00:00`
- ❌ `Jan 15, 2026`
- ❌ `1705312200` (timestamps)

### Tool Names

The skill calls tools by exact name. Ensure your MCP registers:
- `gmail_search_emails` (not `searchEmails` or `gmail.search`)
- `gmail_read_email` (not `readEmail` or `gmail.read`)
- `gmail_list_labels` (not `listLabels` or `gmail.labels`)

## Reference Implementation

See [entourage-gmail-mcp](https://github.com/my-entourage/entourage-gmail-mcp) for a reference implementation that conforms to these contracts.
