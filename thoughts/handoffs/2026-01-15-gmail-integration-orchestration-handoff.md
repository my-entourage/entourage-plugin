# Gmail Integration Orchestration - Handoff Document

**Date:** 2026-01-15
**Status:** Ready for Implementation
**Role:** Integration Agent (this session orchestrates parallel development)

---

## Summary

This session acts as the **Integration Agent** orchestrating two parallel development tracks:
1. Gmail MCP Server (Subagent 1)
2. Gmail Check Skill (Subagent 2)

The integration agent defines contracts first, launches subagents in parallel, then validates their integration.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      INTEGRATION AGENT (this session)                    │
│                          entourage-plugin (main)                         │
│  • Orchestrates subagents                                                │
│  • Defines contract schemas                                              │
│  • Runs integration tests                                                │
│  • Validates end-to-end flow                                            │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
           ┌───────────────────┴───────────────────┐
           │                                       │
           ▼                                       ▼
┌──────────────────────────────┐    ┌──────────────────────────────┐
│      SUBAGENT 1: MCP         │    │      SUBAGENT 2: SKILL       │
│  gmail-mcp-server-creation   │    │  gmail-read-skill-impl       │
│                              │    │                              │
│  Worktree:                   │    │  Worktree:                   │
│  ~/entourage-plugin-gmail-   │    │  ~/entourage-plugin-gmail-   │
│    mcp-server-creation       │    │    read-skill                │
│                              │    │                              │
│  Branch:                     │    │  Branch:                     │
│  gmail-mcp-server-creation   │    │  gmail-read-skill-impl       │
│                              │    │                              │
│  Deliverable:                │    │  Deliverable:                │
│  ~/entourage-gmail-mcp/      │    │  skills/gmail-check/         │
│  (new sibling repo)          │    │  SKILL.md + evaluations/     │
└──────────────────────────────┘    └──────────────────────────────┘
```

---

## Approach: Contract-First + Eval-Driven Development

Following [Anthropic's "Demystifying Evals for AI Agents"](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents):

### Phase Order (TDD-style)

1. **Define contracts first** - Integration agent defines Zod schemas for tool outputs
2. **Write evals first** - Both subagents write tests before implementation
3. **Implement to pass evals** - Iterate until tests pass
4. **Integrate** - Validate MCP + skill work together

### Why Contract-First?

- **MCP-agnostic skills** - Skill references tools by name, not server
- **Third-party compatible** - Any Gmail MCP conforming to contracts will work
- **No package coupling** - Skill doesn't depend on specific MCP implementation
- **Clear documentation** - Schemas define the interface for MCP authors

---

## Contract Schemas

Located at: `skills/gmail-check/integration/contracts/`

### SearchEmailResult (gmail_search_emails)

```typescript
import { z } from 'zod';

export const SearchEmailResultSchema = z.object({
  id: z.string(),           // Required - skill uses for read_email
  threadId: z.string(),     // Required - skill groups by thread
  from: z.string(),         // Required - displayed in evidence table
  subject: z.string(),      // Required - displayed in evidence table
  date: z.string(),         // Required - ISO 8601, used for sorting
  snippet: z.string(),      // Required - used for classification
  labels: z.array(z.string()).optional(),  // Optional - used for filtering
});
```

### EmailContent (gmail_read_email)

```typescript
export const EmailContentSchema = z.object({
  id: z.string(),
  threadId: z.string(),
  from: z.string(),
  to: z.array(z.string()),
  cc: z.array(z.string()).optional(),
  subject: z.string(),
  date: z.string(),
  body: z.object({
    text: z.string(),
    html: z.string().optional(),
  }),
  attachments: z.array(z.object({
    filename: z.string(),
    mimeType: z.string(),
    size: z.number(),
  })).optional(),
});
```

### Label (gmail_list_labels)

```typescript
export const LabelSchema = z.object({
  id: z.string(),
  name: z.string(),
  type: z.enum(['system', 'user']).optional(),
  messageCount: z.number().optional(),
});
```

---

## Worktree Reference

| Worktree Path | Branch | Purpose |
|--------------|--------|---------|
| `~/entourage-plugin` | `main` | Integration agent, contract schemas |
| `~/entourage-plugin-gmail-mcp-server-creation` | `gmail-mcp-server-creation` | MCP server development |
| `~/entourage-plugin-gmail-read-skill` | `gmail-read-skill-implementation` | Skill development |

---

## Execution Order

### Phase 1: Integration Agent - Create Contracts

1. Create `skills/gmail-check/integration/contracts/` directory
2. Write Zod schemas for all 3 tools
3. Write contract validator
4. Document contract testing for third parties

### Phase 2: Launch Subagents (Parallel)

**Subagent 1: MCP Server**
- Worktree: `~/entourage-plugin-gmail-mcp-server-creation`
- Plan: `thoughts/plans/2026-01-14-gmail-mcp-implementation-plan.md`
- Handoff: `thoughts/handoff/2026-01-14-gmail-mcp-server-handoff.md`
- Deliverable: `~/entourage-gmail-mcp/` (new repo)

**Subagent 2: Skill**
- Worktree: `~/entourage-plugin-gmail-read-skill`
- Plan: `thoughts/plans/2026-01-14-gmail-skill-implementation-plan.md`
- Deliverable: `skills/gmail-check/` with SKILL.md and evaluations

### Phase 3: Integration Agent - Validate

1. Run contract validator against MCP server
2. Test skill with configured MCP
3. Verify E2E flow produces expected output

### Phase 4: Merge and Document

1. Publish MCP server to npm
2. PR skill branch to main
3. PR integration tests to main

---

## Success Metrics

| Component | Pass Criteria |
|-----------|---------------|
| MCP Server | All unit tests pass, tools match contract schemas |
| Skill | Regression evals pass@1 = 100%, capability evals pass@3 > 80% |
| Integration | Contract validation passes, E2E produces expected output |

---

## Key Source Documents

| Document | Location | Purpose |
|----------|----------|---------|
| MCP Implementation Plan | `thoughts/plans/2026-01-14-gmail-mcp-implementation-plan.md` | Full MCP architecture |
| MCP Handoff | `thoughts/handoff/2026-01-14-gmail-mcp-server-handoff.md` | Implementation details |
| Skill Implementation Plan | `thoughts/plans/2026-01-14-gmail-skill-implementation-plan.md` | Full skill architecture |
| Gmail Research | `thoughts/research/2026-01-14-gmail-integration-research.md` | Background context |

---

## Files to Create (Integration Agent)

| File | Purpose |
|------|---------|
| `skills/gmail-check/integration/contracts/index.ts` | Export all schemas |
| `skills/gmail-check/integration/contracts/search-emails.ts` | SearchEmailResult schema |
| `skills/gmail-check/integration/contracts/read-email.ts` | EmailContent schema |
| `skills/gmail-check/integration/contracts/list-labels.ts` | Label schema |
| `skills/gmail-check/integration/validator.ts` | Contract validation function |
| `skills/gmail-check/integration/README.md` | Third-party testing docs |

---

## Notes

### MCP-Agnostic Design

The skill is designed to work with **any** Gmail MCP that conforms to the contract schemas. Third parties can:
1. Use `entourage-gmail-mcp` (our implementation)
2. Build their own Gmail MCP
3. Use another third-party Gmail MCP

The skill only references tools by name (`gmail_search_emails`), not by server name.

### Testing Limitations

MCP tools aren't available in test subprocesses (session isolation). Testing approaches:
1. **Contract tests** - Validate schema conformance with configured MCP
2. **Manual E2E** - Test interactively in Claude session
3. **Real Gmail** - Use gitignored credentials for local testing
