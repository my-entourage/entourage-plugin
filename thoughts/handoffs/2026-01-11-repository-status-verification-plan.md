# Repository Status Verification Plan

**Status:** Stage 2 Implemented (GitHub API Integration)
**Date:** 2026-01-11
**Updated:** 2026-01-12

## Context

This plan documents the broader approach for verifying project status by cross-referencing:
1. Meeting transcripts (what was discussed/planned)
2. Code repositories (what was actually implemented)

Stage 1 (local repository scanning) and Stage 2 (GitHub API integration) are now implemented.

---

## Problem Statement

When querying about project status, Claude can mark components as "Complete" based solely on meeting transcripts discussing them. The transcripts show *planning*, not *implementation*. To accurately determine status, we need to verify against actual code.

---

## Current Architecture

```
project-status
  ├── uses /local-repo-check (local git scanning)
  └── uses /github-repo-check (GitHub API scanning)
```

The `/project-status` skill orchestrates both sub-skills and combines evidence using a unified hierarchy.

---

## Configuration Design

**File:** `.entourage/repos.json`
```json
{
  "github": {
    "token": "ghp_...",
    "defaultOrg": "my-org"
  },
  "repos": [
    {
      "name": "entourage-web",
      "path": "~/Documents/code/entourage-web",
      "mainBranch": "main",
      "github": "my-org/entourage-web"
    }
  ]
}
```

**Fields:**
- `github.token` - Optional PAT (only needed if gh CLI unavailable)
- `github.defaultOrg` - Default organization
- `repos[].path` - Local path for `/local-repo-check`
- `repos[].github` - GitHub identifier for `/github-repo-check`

---

## Evidence Hierarchy (Unified)

| Priority | Evidence Type | Source | Max Status |
|----------|--------------|--------|------------|
| 1 | Deployment to production | GitHub | Shipped |
| 2 | PR merged + CI passing | GitHub | Complete |
| 3 | Code + tests on main | Local | Complete |
| 4 | PR merged (no CI info) | GitHub | Complete |
| 5 | Code + tests (any branch) | Local | Complete |
| 6 | Open PR with approvals | GitHub | In Progress |
| 7 | Code exists (no tests) | Local | In Progress |
| 8 | Open PR (no reviews) | GitHub | In Progress |
| 9 | Feature branch exists | Local | In Progress |
| 10 | GitHub Issue (in progress) | GitHub | In Progress |
| 11 | GitHub Issue (open) | GitHub | Planned |
| 12 | Architecture decision | Transcripts | Planned |
| 13 | Meeting discussion | Transcripts | Discussed |

**Conflict Resolution:** GitHub is source of truth. When local and GitHub disagree, GitHub wins.

---

## GitHub-Only Data Points

These are not available via local git but are available via GitHub API:

| Data Point | Evidence Value | API Endpoint |
|------------|----------------|--------------|
| Pull Requests | In Progress → Complete | `/repos/{owner}/{repo}/pulls` |
| Issues | Planned signals | `/repos/{owner}/{repo}/issues` |
| GitHub Actions | CI pass/fail | `/repos/{owner}/{repo}/actions/runs` |
| Deployments | Shipped verification | `/repos/{owner}/{repo}/deployments` |
| Releases | Shipped with version | `/repos/{owner}/{repo}/releases` |
| Code Reviews | Quality gate | `/repos/{owner}/{repo}/pulls/{pr}/reviews` |

---

## Authentication

**Preferred: gh CLI**
- Handles auth automatically after `gh auth login`
- Credentials stored in system keychain
- Works with all organizations

**Fallback: Personal Access Token**
- Store in `.entourage/repos.json`
- Required scopes: `repo`, `read:org`, `workflow`

---

## Staging Plan

### Stage 1: Local Repository Scanning - IMPLEMENTED
- [x] Add repo config file support to `project-status` skill
- [x] Scan local repos for file patterns, git history
- [x] Upgrade status based on code evidence
- [x] Documentation in README.md
- [x] Example config template

### Stage 2: GitHub API Integration - IMPLEMENTED
- [x] Create `/github-repo-check` skill
- [x] gh CLI preferred, PAT fallback
- [x] Query PRs, issues, Actions, deployments
- [x] Update `/project-status` to orchestrate both skills
- [x] Unified evidence hierarchy
- [x] GitHub as source of truth for conflicts
- [x] Documentation for GitHub configuration

### Stage 3: Marketplace-Ready - DEFERRED
- OAuth flow (if marketplace supports)
- Cross-platform path handling
- Graceful fallback when no repos configured

---

## Resolved Questions

1. **GitHub vs local priority:** GitHub is source of truth (represents canonical shared state)
2. **What counts as "complete"?** PR merged + CI passing = Very High confidence
3. **Authentication method:** gh CLI preferred (secure, automatic), PAT as fallback
4. **APIs vs Webhooks:** REST API chosen (simpler for on-demand queries, no infrastructure needed)

---

## Related Files

- `/Users/jaredsisk/.claude/plans/groovy-drifting-lake.md` - Detailed Phase 2 implementation plan
- `skills/github-repo-check/SKILL.md` - New GitHub scanning skill
- `skills/project-status/SKILL.md` - Updated to orchestrate both skills
- `skills/local-repo-check/SKILL.md` - Local git scanning skill
