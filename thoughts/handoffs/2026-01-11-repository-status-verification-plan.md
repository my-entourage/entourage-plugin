# Repository Status Verification Plan

**Status:** Stage 1 Implemented (Local Repository Scanning)
**Date:** 2026-01-11
**Updated:** 2026-01-11

## Context

This plan documents the broader approach for verifying project status by cross-referencing:
1. Meeting transcripts (what was discussed/planned)
2. Code repositories (what was actually implemented)

Stage 1 (local repository scanning) has been implemented. Stage 2 (GitHub API) is deferred to future work.

---

## Problem Statement

When querying about project status, Claude can mark components as "Complete" based solely on meeting transcripts discussing them. The transcripts show *planning*, not *implementation*. To accurately determine status, we need to verify against actual code.

---

## Approaches Evaluated

### Option 1: Local Repository Scanning (Claude Code Native)

Scan local git repositories that the user points to, analyzing:
- File structure (do expected files exist?)
- Git history (recent commits, branches)
- Code content (implementations, tests, migrations)
- CI/CD status (if accessible)

---

### Option 2: GitHub API Integration

Use GitHub's REST or GraphQL API to:
- List repositories in an org
- Check recent commits, PRs, issues
- Read file contents
- Check GitHub Actions status

---

### Option 3: Hybrid Approach (Recommended for Future)

- **Primary:** Scan local repositories (always available)
- **Optional:** GitHub API for enhanced metadata (issues, PRs, Actions status)

---

## Evidence Hierarchy

To determine if a component is "Complete" vs "Planned" vs "In Progress":

| Evidence Type | Status Implication | Source |
|--------------|-------------------|--------|
| Passing tests for feature | Strong completion signal | Local repo / CI |
| Migration files executed | Schema exists | Local repo / DB |
| Feature branch merged to main | Work completed | Git history / GitHub |
| Open PR with code | In progress | GitHub API |
| Committed code (no tests) | Partial implementation | Local repo |
| Issue/task created | Planned | GitHub Issues / Linear |
| Discussed in meeting | Ideation phase | Transcripts |

---

## Configuration Design

**File:** `.entourage/repos.json`
```json
{
  "repos": [
    {"name": "entourage-web", "path": "~/Documents/code/@orgs/my-entourage/entourage-web"},
    {"name": "entourage-context", "path": "~/entourage-context"}
  ]
}
```

If this file exists, the `project-status` skill could:
1. Search repos for files matching component keywords
2. Check for test files
3. Look at git history for recent commits
4. Upgrade status from "Discussed" to "In Progress" or "Complete" based on findings

---

## Open Questions (For Future)

1. **Repo discovery:** Should the skill auto-discover repos or require explicit configuration?

2. **What counts as "complete"?**
   - Code exists?
   - Code exists + tests pass?
   - Merged to main?
   - Deployed?

3. **Transcript parsing:** How structured is the task/feature naming in transcripts? Can we reliably extract component names to search for?

4. **GitHub vs local priority:** If both are available, which source wins for status determination?

5. **Marketplace authentication:** Does the Claude Code marketplace support storing user secrets (like GitHub PATs)?

---

## Staging Plan

### Stage 1: Local Repository Scanning - IMPLEMENTED
- [x] Add repo config file support to `project-status` skill
- [x] Scan local repos for file patterns, git history
- [x] Upgrade status based on code evidence
- [x] Documentation in README.md
- [x] Example config template

### Stage 2: GitHub API Integration - DEFERRED
- Optional PAT configuration
- Query GitHub for PRs, issues, Actions status
- Richer status context

### Stage 3: Marketplace-Ready - DEFERRED
- OAuth flow (if marketplace supports)
- Cross-platform path handling
- Graceful fallback when no repos configured

---

## Related Plan

See `/Users/jaredsisk/.claude/plans/glowing-doodling-crown.md` for the current implementation plan focusing on the `grounded-query` and `project-status` skills (data files only, no repo integration).
