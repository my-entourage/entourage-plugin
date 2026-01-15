# Gmail Integration Orchestration - Handoff Document

**Date:** 2026-01-15
**Updated:** 2026-01-15
**Status:** Integration Testing In Progress
**Branch:** `main` (integration agent), `gmail-read-skill-implementation` (skill)

---

## Summary

This session acted as the **Integration Agent** orchestrating two parallel development tracks:
1. Gmail MCP Server (Subagent 1) - ✅ Complete
2. Gmail Check Skill (Subagent 2) - ✅ Complete

Currently in **Phase 3: Integration Testing** - validating the MCP + skill work together.

---

## Current Status

### Completed ✅

| Phase | Details |
|-------|---------|
| Contract schemas | `skills/gmail-check/integration/contracts/` with Zod schemas |
| MCP Server | `~/entourage-gmail-mcp/` - 40 tests passing, pushed to GitHub |
| Skill | `skills/gmail-check/` - 14 test cases, 7 fixtures, pushed |
| Git | All repos committed and pushed |

### In Progress 🔄

- **Integration Testing** - User is setting up Google Cloud OAuth credentials
- MCP server built and CLI working (`node dist/cli.js help` verified)

### Pending ⏳

- Configure MCP in `~/.claude.json`
- Authenticate with Gmail (`entourage-gmail-mcp auth`)
- Verify MCP tools appear in Claude session
- Test `/gmail-check` skill E2E
- Create PR for skill branch
- Publish MCP to npm

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      INTEGRATION AGENT (this session)                    │
│                          entourage-plugin (main)                         │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
           ┌───────────────────┴───────────────────┐
           │                                       │
           ▼                                       ▼
┌──────────────────────────────┐    ┌──────────────────────────────┐
│      SUBAGENT 1: MCP ✅       │    │      SUBAGENT 2: SKILL ✅     │
│                              │    │                              │
│  Repo: ~/entourage-gmail-mcp │    │  Branch: gmail-read-skill-   │
│  GitHub: my-entourage/       │    │    implementation            │
│    entourage-gmail-mcp       │    │                              │
│                              │    │  Files:                      │
│  40 tests passing            │    │  - skills/gmail-check/       │
│  3 tools implemented         │    │    SKILL.md                  │
│  CLI with auth command       │    │  - 14 test cases             │
└──────────────────────────────┘    └──────────────────────────────┘
```

---

## Key Files

### Integration Agent (main branch)
- `skills/gmail-check/integration/contracts/` - Zod schemas defining tool contracts
- `skills/gmail-check/integration/validator.ts` - Contract validation functions
- `skills/gmail-check/integration/README.md` - Third-party testing docs
- `thoughts/handoffs/2026-01-15-gmail-integration-orchestration-handoff.md` - This file

### MCP Server (`~/entourage-gmail-mcp`)
- `src/tools/search-emails.ts` - gmail_search_emails implementation
- `src/tools/read-email.ts` - gmail_read_email implementation
- `src/tools/list-labels.ts` - gmail_list_labels implementation
- `src/oauth.ts` - OAuth flow with gmail.readonly scope
- `src/cli.ts` - CLI with auth command

### Skill (`gmail-read-skill-implementation` branch)
- `skills/gmail-check/SKILL.md` - 7-step workflow
- `skills/gmail-check/evaluations/evaluation.json` - 14 test cases
- `skills/gmail-check/evaluations/fixtures/` - 7 fixture directories

---

## Next Steps

1. **Complete Google Cloud OAuth setup**
   - Create project, enable Gmail API
   - Configure OAuth consent screen with gmail.readonly scope
   - Create Desktop app credentials
   - Save to `~/.entourage/gmail-credentials.json`

2. **Authenticate with Gmail**
   ```bash
   node ~/entourage-gmail-mcp/dist/cli.js auth
   ```

3. **Configure MCP in Claude**
   Add to `~/.claude.json`:
   ```json
   {
     "mcpServers": {
       "gmail": {
         "type": "stdio",
         "command": "node",
         "args": ["/Users/jaredsisk/entourage-gmail-mcp/dist/index.js"]
       }
     }
   }
   ```

4. **Test E2E**
   ```bash
   claude --plugin-dir ~/entourage-plugin-gmail-read-skill
   ```
   Then invoke `/gmail-check auth system`

5. **After integration passes:**
   - Create PR for `gmail-read-skill-implementation` → `main`
   - Publish `entourage-gmail-mcp` to npm
   - Update plugin README with Gmail setup instructions

---

## GitHub Repositories

| Repo | URL | Status |
|------|-----|--------|
| entourage-plugin | https://github.com/my-entourage/entourage-plugin | Main plugin repo |
| entourage-gmail-mcp | https://github.com/my-entourage/entourage-gmail-mcp | New MCP server |

### Branches

| Branch | Purpose | Status |
|--------|---------|--------|
| `main` | Contract schemas, integration | Pushed |
| `gmail-read-skill-implementation` | Skill implementation | Pushed, PR ready |
| `gmail-mcp-server-creation` | (worktree for MCP dev) | Work complete |

---

## Contract Schemas

Located at: `skills/gmail-check/integration/contracts/`

### gmail_search_emails → SearchEmailResult[]
```typescript
{ id, threadId, from, subject, date, snippet, labels? }
```

### gmail_read_email → EmailContent
```typescript
{ id, threadId, from, to, cc?, subject, date, body: { text, html? }, attachments? }
```

### gmail_list_labels → Label[]
```typescript
{ id, name, type?, messageCount? }
```

---

## Notes

### MCP-Agnostic Design
The skill references tools by name (`gmail_search_emails`), not server name. Any Gmail MCP conforming to the contract schemas will work.

### Testing Limitations
MCP tools aren't available in test subprocesses (session isolation). Testing requires:
1. Manual E2E in Claude session with MCP configured
2. Contract validation against live MCP responses

### Google Cloud OAuth
- Requires "Desktop app" OAuth client type
- Only `gmail.readonly` scope needed
- User must be added as test user if app is in "Testing" mode
- Credentials stored in `~/.entourage/gmail-credentials.json`
- Token stored in `~/.entourage/gmail-token.json`
