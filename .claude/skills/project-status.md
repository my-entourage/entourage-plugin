---
name: project-status
description: Reports implementation status of project components with evidence. Use when asked about what's done, in progress, or planned for a project.
---

## Purpose

Provide accurate project status by distinguishing between what was discussed versus what is actually implemented.

## When to Use

Apply when user asks:
- "What's the status of X?"
- "Is Y complete?"
- "What has been implemented?"
- "Show me project progress"

## Status Levels

| Status | Definition | Evidence Required |
|--------|------------|-------------------|
| `Discussed` | Mentioned in meetings/messages | Transcript/message reference |
| `Planned` | Explicit decisions documented | Decision in transcript + rationale |
| `In Progress` | Implementation started | Code in repo (requires repo config) |
| `Complete` | Working implementation | Code + tests passing (requires repo) |
| `Unknown` | Insufficient evidence | N/A |

## Workflow

1. Identify components/features in query
2. Search data files for mentions of each
3. Classify evidence type (discussion vs decision vs implementation)
4. If repo config exists, check for code evidence
5. Output status table

## Output Format

```
## Status: [Project Name]

| Component | Status | Evidence | Confidence |
|-----------|--------|----------|------------|
| [Name] | Discussed/Planned/etc | [Brief description] | High/Med/Low |

### Notes
- [Any caveats about verification limitations]
```

## Critical Rule

**Never mark a component as "Complete" or "In Progress" based solely on meeting transcripts.**

Meeting transcripts can only support `Discussed` or `Planned` status. Higher statuses require code evidence from repositories.

If repos are not configured, add this note:
> Repository verification not configured. Maximum verifiable status is "Planned". Add repos to `.entourage/repos.json` for implementation status.

## Evidence Hierarchy

When determining status, use this hierarchy (strongest to weakest evidence):

| Evidence Type | Max Status Level |
|--------------|------------------|
| Meeting discussion only | Discussed |
| Architecture decisions documented | Planned |
| Code exists (no tests) | In Progress |
| Code + passing tests | Complete |
| Merged to main + deployed | Shipped |

## Example Output

**Query:** "What's the status of the database?"

```
## Status: Entourage

| Component | Status | Evidence | Confidence |
|-----------|--------|----------|------------|
| Database schema | Planned | Architecture decided Dec 22 | Medium |
| Clerk auth | Discussed | Mentioned Dec 21 | Low |
| API endpoints | Unknown | No mentions found | Low |

### Notes
- Repository verification not configured. Maximum verifiable status is "Planned". Add repos to `.entourage/repos.json` for implementation status.
- "Complete" and "In Progress" require code evidence from repositories.
```
