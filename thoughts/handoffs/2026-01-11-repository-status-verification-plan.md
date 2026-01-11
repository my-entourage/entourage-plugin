# Repository Status Verification Plan (Deferred)

**Status:** Deferred - Focus first on grounded-query and project-status skills
**Date:** 2026-01-11

## Context

This plan documents the broader approach for verifying project status by cross-referencing:
1. Meeting transcripts (what was discussed/planned)
2. Code repositories (what was actually implemented)

This is deferred in favor of first building the `grounded-query` and `project-status` skills that work on data files only.

---

## Problem Statement

When querying about project status, Claude can mark components as "Complete" based solely on meeting transcripts discussing them. The transcripts show *planning*, not *implementation*. To accurately determine status, we need to verify against actual code.

---

## Approaches Evaluated

### Option 1: Local Repository Scanning (Claude Code Native)

**How it works:** Scan local git repositories that the user points to, analyzing:
- File structure (do expected files exist?)
- Git history (recent commits, branches)
- Code content (implementations, tests, migrations)
- CI/CD status (if accessible)

**Pros:**
- No external API dependencies
- Works offline
- Full access to all repo content
- Privacy-preserving (nothing leaves machine)
- Immediate prototype viability

**Cons:**
- Requires user to have repos cloned locally
- Can't check remote-only repos
- No access to GitHub Issues/PRs/Actions without API

---

### Option 2: GitHub API Integration

**How it works:** Use GitHub's REST or GraphQL API to:
- List repositories in an org
- Check recent commits, PRs, issues
- Read file contents
- Check GitHub Actions status

**Pros:**
- Access to remote repos without local clones
- Rich metadata (issues, PRs, discussions, Actions)
- Can track cross-repo dependencies

**Cons:**
- Requires authentication (PAT or OAuth)
- Rate limits
- Privacy/security considerations for marketplace distribution
- More complex setup for end users

---

### Option 3: Hybrid Approach (Recommended for Future)

**How it works:**
- **Primary:** Scan local repositories (always available)
- **Optional:** GitHub API for enhanced metadata (issues, PRs, Actions status)

**Pros:**
- Works out of the box with local repos
- Enhanced features available for users who authenticate
- Graceful degradation

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

## Staging Plan (Deferred)

### Stage 1: Local Repository Scanning
- Add repo config file support to `project-status` skill
- Scan local repos for file patterns, git history
- Upgrade status based on code evidence

### Stage 2: GitHub API Integration
- Optional PAT configuration
- Query GitHub for PRs, issues, Actions status
- Richer status context

### Stage 3: Marketplace-Ready
- OAuth flow (if marketplace supports)
- Cross-platform path handling
- Graceful fallback when no repos configured

---

## Related Plan

See `/Users/jaredsisk/.claude/plans/glowing-doodling-crown.md` for the current implementation plan focusing on the `grounded-query` and `project-status` skills (data files only, no repo integration).
