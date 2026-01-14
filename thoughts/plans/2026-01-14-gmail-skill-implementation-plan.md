# Gmail Skill Implementation Plan

**Date:** 2026-01-14
**Status:** Draft
**Related:**
- `thoughts/plans/2026-01-14-gmail-mcp-implementation-plan.md` (MCP server)
- `thoughts/research/2026-01-14-gmail-integration-research.md`

---

## Executive Summary

This plan covers implementing the `/gmail-check` skill in `entourage-plugin` for pulling email evidence into project status assessments. The skill is **MCP-agnostic**—it works with any Gmail MCP server that provides the expected tools.

**Approach:** Eval-driven development following [Anthropic's "Demystifying Evals for AI Agents"](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) guidance.

---

## Architecture Context

```
┌─────────────────────────────────────────────────────────────────┐
│                    User's MCP Configuration                      │
│  - Any Gmail MCP that provides: gmail_search_emails,            │
│    gmail_read_email, gmail_list_labels                          │
└─────────────────────────────────────────────────────────────────┘
                               │
                    MCP provides tools
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    entourage-plugin                              │
│  ┌─────────────────┐  ┌──────────────────┐  ┌───────────────┐   │
│  │ /project-status │  │ /github-repo-    │  │ /gmail-check  │   │
│  │   (orchestrator)│  │    check         │  │   (NEW)       │   │
│  └────────┬────────┘  └────────┬─────────┘  └───────┬───────┘   │
│           │                    │                    │            │
│           ▼                    ▼                    ▼            │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                  .entourage/repos.json                     │  │
│  │  { github: {...}, gmail: {...}, repos: [...] }             │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**Key Principle:** Skills reference MCP tools by **tool name** (`gmail_search_emails`), not server name. This allows users to configure MCPs however they prefer.

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
| `gmail.searchDefaults.maxResults` | number | No | Max emails per search (default: 20) |
| `gmail.searchDefaults.daysBack` | number | No | Search window in days (default: 90) |
| `gmail.searchDefaults.excludeCategories` | array | No | Gmail categories to exclude |
| `repos[].gmailFilters` | array | No | Per-repo Gmail search filters |

---

## Component 2: `/gmail-check` Skill

### Directory Structure

```
skills/gmail-check/
├── SKILL.md              # Main skill definition
├── README.md             # User documentation
└── evaluations/
    ├── evaluation.json   # Test cases (assertion-based)
    └── fixtures/
        ├── emails-found/
        │   ├── .entourage/repos.json
        │   └── expected-output.md
        ├── no-gmail-config/
        │   └── .entourage/repos.json
        ├── mcp-unavailable/
        │   └── .entourage/repos.json
        └── no-results/
            └── .entourage/repos.json
```

### SKILL.md Content

```yaml
---
name: gmail-check
description: Search Gmail for evidence about project components. Returns email threads, senders, dates, and relevance for status determination.
---

## Purpose

Search Gmail for email evidence related to project components and features. This skill queries Gmail via MCP to find discussions, design reviews, and planning emails that contribute to implementation status.

## MCP Tools Used

- `gmail_search_emails` - Search Gmail with query syntax
- `gmail_read_email` - Get full email content (optional, for deep inspection)
- `gmail_list_labels` - List available labels for filtering

## Prerequisites

1. Gmail MCP server configured (any compatible MCP)
2. `.entourage/repos.json` with `gmail.enabled: true`
3. OAuth authentication completed for Gmail MCP

## Workflow

### Step 1: Check Configuration

Read `.entourage/repos.json` and verify:
- `gmail.enabled` is `true`

If Gmail is not configured, return setup instructions.

### Step 2: Verify MCP Availability

Check if `gmail_search_emails` tool is available.

If MCP not found, return helpful guidance on MCP setup.

### Step 3: Build Search Query

For each component/feature name provided:

1. Parse the component name from input
2. Apply repo-specific filters if `repos[].gmailFilters` is set
3. Apply default exclusions from `gmail.searchDefaults.excludeCategories`
4. Build Gmail search query:

```
({component_name}) after:{date} -category:promotions -category:social
```

### Step 4: Execute Search

Call `gmail_search_emails` with the constructed query.

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

Return structured markdown:

```markdown
## Gmail Evidence: {Component Name}

**Search Query:** `{query_used}`
**Emails Found:** {count}
**Date Range:** {oldest} to {newest}

### Email Summary

| Date | From | Subject | Type | Relevance |
|------|------|---------|------|-----------|
| 2025-01-10 | alice@co.com | Auth design review | Review | High |

### Evidence Summary

| Evidence Type | Count | Suggests Status |
|---------------|-------|-----------------|
| Design Reviews | 2 | In Progress |
| Planning Docs | 1 | Planned |

**Recommended Status:** {status} (based on {evidence_type})
```

## Error Handling

### Gmail Not Configured
```
Gmail integration not configured.

Add to .entourage/repos.json:
{
  "gmail": { "enabled": true }
}

And configure a Gmail MCP server in Claude settings.
```

### MCP Not Available
```
Gmail MCP tools not found.

Verify Gmail MCP is configured:
1. Check ~/.claude.json or .mcp.json has a Gmail MCP server
2. Restart Claude Code to load MCP changes
```

### No Results
```
No Gmail evidence found for: {component_name}

Searched: {query}
Date range: last {days} days
Suggestion: Try broader search terms or extend date range
```
```

---

## Component 3: Update `/project-status` Skill

Add Gmail as a fourth evidence source:

```markdown
## Evidence Sources

1. **Transcripts** - Meeting notes, voice memos in `data/transcripts/`
2. **Local Git Repos** - Code files, tests, commit history
3. **GitHub API** - PRs, issues, Actions, deployments
4. **Gmail** (NEW) - Email threads, design reviews, discussions

## Workflow Update

### Step 4: Gather Gmail Evidence (NEW)

If `.entourage/repos.json` has `gmail.enabled: true`:

1. Invoke `/gmail-check {components}`
2. Parse returned evidence table
3. Add to evidence synthesis:
   - Design review emails → "In Progress" evidence
   - Spec attachments → "Planned" evidence
   - Simple mentions → "Discussed" evidence
```

---

## Eval-Driven Development

Following [Anthropic's guidance](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents), we adopt eval-driven development:

### Core Principles

1. **Start with 20-50 tasks from real failures** — Not hypothetical scenarios
2. **Grade outcomes, not paths** — Allow different valid approaches
3. **Code-based graders first** — Fast, deterministic, CI-friendly
4. **Multiple trials for non-determinism** — Use pass@k metrics
5. **Reference solutions validate graders** — Prove tasks are solvable

### Evaluation Categories

#### Capability Evals (New Features)

Test whether the skill can accomplish the intended task:

| ID | Name | Purpose | Expected Pass Rate |
|----|------|---------|-------------------|
| `emails-found` | Find relevant emails | Core functionality | Start low, improve |
| `multiple-components` | Handle multiple search terms | Scaling | 80%+ target |
| `per-repo-filters` | Apply repo-specific filters | Config respect | 80%+ target |

#### Regression Evals (Stability)

Prevent breaking existing functionality:

| ID | Name | Purpose | Expected Pass Rate |
|----|------|---------|-------------------|
| `no-gmail-config` | Graceful when disabled | Error handling | 100% |
| `mcp-unavailable` | Helpful when MCP missing | Error handling | 100% |
| `no-results` | Informative when empty | Edge case | 100% |

#### Adversarial Evals (Robustness)

Test failure modes and edge cases:

| ID | Name | Purpose | Expected Pass Rate |
|----|------|---------|-------------------|
| `hallucination-prevention` | Don't invent emails | Safety | 100% |
| `status-inflation` | Don't overclaim from mentions | Accuracy | 90%+ |
| `malformed-config` | Handle bad repos.json | Resilience | 100% |

### Grading Strategy

#### Layer 1: Code-Based Graders (Primary)

```json
{
  "id": "emails-found",
  "expectedOutput": {
    "contains": ["Gmail Evidence", "Email Summary", "|"],
    "notContains": ["Error", "failed", "exception"],
    "format": "table"
  }
}
```

**Assertion Types:**
- `contains` — Required strings in output
- `notContains` — Prohibited strings
- `format` — Expected structure (table, list, etc.)
- `hasSection` — Required markdown sections

#### Layer 2: LLM-Based Graders (Future)

For nuanced quality assessment:

```json
{
  "id": "emails-found",
  "rubric": {
    "relevance": "Are the emails related to the search query?",
    "classification": "Are evidence types correctly identified?",
    "completeness": "Does output include all required sections?"
  }
}
```

### evaluation.json

```json
{
  "name": "gmail-check",
  "description": "Search Gmail for project evidence",
  "testCases": [
    {
      "id": "emails-found",
      "name": "Find relevant emails",
      "category": "capability",
      "input": "/gmail-check auth system",
      "setup": {
        "description": "Gmail configured, MCP returns matching emails",
        "fixture": "fixtures/emails-found",
        "mockMcp": true
      },
      "expectedOutput": {
        "contains": ["Gmail Evidence", "auth system", "Email Summary"],
        "format": "table",
        "hasSection": ["Evidence Summary"]
      },
      "passRate": {
        "target": 0.8,
        "current": null
      }
    },
    {
      "id": "no-gmail-config",
      "name": "Gmail not configured",
      "category": "regression",
      "input": "/gmail-check database",
      "setup": {
        "description": "No gmail section in repos.json",
        "fixture": "fixtures/no-gmail-config"
      },
      "expectedOutput": {
        "contains": ["not configured", ".entourage/repos.json"],
        "notContains": ["Error", "exception", "failed"]
      },
      "passRate": {
        "target": 1.0,
        "current": null
      }
    },
    {
      "id": "mcp-unavailable",
      "name": "Gmail MCP not connected",
      "category": "regression",
      "input": "/gmail-check feature",
      "setup": {
        "description": "Gmail enabled but MCP server not running",
        "fixture": "fixtures/mcp-unavailable"
      },
      "expectedOutput": {
        "contains": ["MCP", "Gmail", "configure"],
        "notContains": ["Error", "crash"]
      },
      "passRate": {
        "target": 1.0,
        "current": null
      }
    },
    {
      "id": "no-results",
      "name": "No emails match search",
      "category": "regression",
      "input": "/gmail-check nonexistent-feature-xyz",
      "setup": {
        "description": "Gmail configured but search returns empty",
        "fixture": "fixtures/no-results",
        "mockMcp": true
      },
      "expectedOutput": {
        "contains": ["No Gmail evidence found", "nonexistent-feature-xyz"],
        "notContains": ["Error"]
      },
      "passRate": {
        "target": 1.0,
        "current": null
      }
    },
    {
      "id": "hallucination-prevention",
      "name": "No invented emails",
      "category": "adversarial",
      "input": "/gmail-check authentication",
      "setup": {
        "description": "MCP returns empty results; skill must not invent data",
        "fixture": "fixtures/no-results",
        "mockMcp": true
      },
      "expectedOutput": {
        "notContains": ["from:", "@", "Subject:"],
        "contains": ["No Gmail evidence"]
      },
      "passRate": {
        "target": 1.0,
        "current": null
      }
    },
    {
      "id": "status-inflation-prevention",
      "name": "Don't overclaim from casual mentions",
      "category": "adversarial",
      "input": "/gmail-check payment-system",
      "setup": {
        "description": "Email mentions 'payment' in passing, not as main topic",
        "fixture": "fixtures/casual-mention",
        "mockMcp": true
      },
      "expectedOutput": {
        "notContains": ["In Progress", "Complete", "Implemented"],
        "contains": ["Discussed", "mention"]
      },
      "passRate": {
        "target": 0.9,
        "current": null
      }
    },
    {
      "id": "per-repo-filters",
      "name": "Apply repo-specific Gmail filters",
      "category": "capability",
      "input": "/gmail-check my-app features",
      "setup": {
        "description": "repos.json has gmailFilters for my-app",
        "fixture": "fixtures/repo-filters"
      },
      "expectedOutput": {
        "contains": ["label:my-app", "from:team@company.com"]
      },
      "passRate": {
        "target": 0.8,
        "current": null
      }
    },
    {
      "id": "evidence-classification",
      "name": "Correctly classify evidence types",
      "category": "capability",
      "input": "/gmail-check database migration",
      "setup": {
        "description": "Mix of design review, planning doc, and discussion emails",
        "fixture": "fixtures/mixed-evidence",
        "mockMcp": true
      },
      "expectedOutput": {
        "contains": ["Design Review", "Planning", "Discussion"],
        "hasSection": ["Evidence Summary"]
      },
      "passRate": {
        "target": 0.8,
        "current": null
      }
    }
  ]
}
```

### Pass@k Strategy

For non-deterministic outputs, run multiple trials:

```bash
# Run each test case 3 times
./tests/run.sh gmail-check --trials 3

# pass@1: Probability of success on first try
# pass@3: Probability of at least one success in 3 tries
```

**Target Metrics:**
- Regression evals: pass@1 = 100%
- Capability evals: pass@3 = 80%+
- Adversarial evals: pass@1 = 90%+

### Test Fixtures

#### fixtures/emails-found/.entourage/repos.json

```json
{
  "gmail": {
    "enabled": true,
    "searchDefaults": {
      "maxResults": 20,
      "daysBack": 90
    }
  },
  "repos": []
}
```

#### fixtures/emails-found/mock-mcp-response.json

```json
{
  "tool": "gmail_search_emails",
  "response": {
    "content": [
      {
        "id": "msg1",
        "threadId": "thread1",
        "from": "alice@company.com",
        "subject": "Auth system design review",
        "date": "2026-01-10T10:30:00Z",
        "snippet": "Here's the design doc for the auth system..."
      },
      {
        "id": "msg2",
        "threadId": "thread1",
        "from": "bob@company.com",
        "subject": "Re: Auth system design review",
        "date": "2026-01-11T14:20:00Z",
        "snippet": "Looks good! I have a few questions about..."
      }
    ]
  }
}
```

---

## Implementation Phases

### Phase 1: Eval Foundation (Day 1)

**Goal:** Complete evaluation infrastructure before any skill code

Tasks:
- [ ] Create `skills/gmail-check/` directory structure
- [ ] Write `evaluation.json` with all test cases
- [ ] Create fixture directories with mock data
- [ ] Run validation: `./tests/validate.sh`
- [ ] Verify all test cases have unambiguous criteria

**Success Criteria:**
- `validate.sh` passes
- Each test case has clear pass/fail criteria
- Domain expert review confirms criteria are correct

### Phase 2: Reference Solutions (Day 2)

**Goal:** Prove all test cases are solvable

Tasks:
- [ ] Write `fixtures/*/expected-output.md` for each test case
- [ ] Manually verify each expected output meets criteria
- [ ] Document any edge cases discovered

**Success Criteria:**
- Every test case has a reference solution
- Reference solutions pass their own assertions
- No ambiguous or impossible test cases

### Phase 3: SKILL.md Implementation (Day 3-4)

**Goal:** Write skill definition that passes evals

Tasks:
- [ ] Write SKILL.md with complete workflow
- [ ] Iterate until regression evals pass@1 = 100%
- [ ] Iterate until capability evals pass@3 > 80%
- [ ] Review transcripts for failed trials

**Success Criteria:**
- All regression evals pass consistently
- Capability evals meet targets
- No systematic failure patterns

### Phase 4: Integration (Day 5)

**Goal:** Integrate with `/project-status`

Tasks:
- [ ] Update `/project-status` SKILL.md to invoke `/gmail-check`
- [ ] Add Gmail evidence synthesis to status hierarchy
- [ ] Run end-to-end tests

**Success Criteria:**
- `/project-status` includes Gmail evidence when enabled
- Evidence correctly influences status recommendations

---

## Testing Without MCP

Since MCP tools aren't available in test subprocesses, evaluations use:

1. **Fixture-based mocking** — Mock MCP responses in fixture files
2. **Config-only tests** — Test configuration parsing without MCP calls
3. **Manual verification** — Interactive testing in live Claude session
4. **Pending status** — Mark MCP-dependent tests as pending for local runs

```json
{
  "id": "emails-found",
  "status": "pending",
  "pendingReason": "Requires Gmail MCP; run manually or with mock server"
}
```

---

## Success Criteria

- [ ] All regression evals pass@1 = 100%
- [ ] All capability evals pass@3 > 80%
- [ ] All adversarial evals pass@1 > 90%
- [ ] `/gmail-check` returns structured email evidence
- [ ] Works with any Gmail MCP (not locked to specific server)
- [ ] `/project-status` integrates Gmail evidence
- [ ] Configuration schema documented in examples
- [ ] No hallucinated emails in any trial

---

## References

- [Gmail MCP Implementation Plan](./2026-01-14-gmail-mcp-implementation-plan.md)
- [Gmail Integration Research](../research/2026-01-14-gmail-integration-research.md)
- [Demystifying Evals for AI Agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) — Anthropic
- [Evaluating AI Agents Research](../research/2026-01-14-evaluating-ai-agents-testing-approaches-media-content.md)
- [entourage-plugin Evaluation Infrastructure](../../thoughts/plans/2026-01-12-eval-infrastructure-plan.md)
