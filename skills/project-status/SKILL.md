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
| `Planned` | Explicit decisions documented | Decision in transcript + rationale, or GitHub Issue |
| `In Progress` | Implementation started | Code in repo or open PR |
| `Complete` | Working implementation | Code + tests, or merged PR with CI passing |
| `Shipped` | Deployed to production | Deployment evidence from GitHub |
| `Unknown` | Insufficient evidence | N/A |

---

## Agent Skills as Product Features

Claude Code plugins and agent skills (SKILL.md files) are product features. They serve as executable prompts that define agent behavior.

### Detecting Skill Features

When scanning repositories, also check for:
```
skills/*/SKILL.md
commands/*.md
.claude/skills/*/SKILL.md
.claude/commands/*.md
```

### Skill Status Evidence

| Evidence | Status | Confidence |
|----------|--------|------------|
| SKILL.md exists + tests in `evaluations/` | Complete | High |
| SKILL.md exists (no tests) | In Progress | Medium |
| Skill mentioned in transcripts only | Discussed | Medium |

Include skills in the component status table with type indicator:
```
| grounded-query (skill) | Complete | SKILL.md + evaluations | entourage-plugin | High |
```

## Workflow

1. Identify components/features in query
2. Search data files for transcript mentions of each component
3. Check if `.entourage/repos.json` exists
4. If repos configured with `path` field:
   - Invoke `/repo-check <components>` for local git evidence
5. If repos configured with `github` field:
   - Invoke `/github-repo-check <components>` for GitHub evidence
6. Combine all evidence sources using the unified hierarchy
7. Output status table with sources

---

## Repository Verification

This skill uses two sub-skills to verify implementation status:
- `/repo-check` - Scans local git repositories
- `/github-repo-check` - Queries GitHub API for PRs, issues, Actions, deployments

### Configuration Check

Read `.entourage/repos.json` and check each repo entry for:
- `path` field - Enables local scanning via `/repo-check`
- `github` field - Enables GitHub scanning via `/github-repo-check`

### With Local Repository (`path` configured)

1. Invoke `/repo-check <component-names>`
2. Get evidence: file existence, test files, git history

### With GitHub Repository (`github` configured)

1. Invoke `/github-repo-check <component-names>`
2. Get evidence: PRs, issues, Actions status, deployments

### Without Any Repository Configuration

- Skip both `/repo-check` and `/github-repo-check`
- Limit status levels to "Discussed" or "Planned" (transcript evidence only)
- Add note about configuring repos

---

## Unified Evidence Hierarchy

When combining evidence from transcripts, local repos, and GitHub, use this priority order:

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
| 10 | GitHub Issue (in progress label) | GitHub | In Progress |
| 11 | GitHub Issue (open) | GitHub | Planned |
| 12 | Architecture decision documented | Transcripts | Planned |
| 13 | Meeting discussion | Transcripts | Discussed |

**Rule:** Higher priority evidence overrides lower. If GitHub shows PR merged but local shows no tests, use the GitHub evidence (Complete).

---

## Conflict Resolution: GitHub is Source of Truth

When local and GitHub evidence conflict (e.g., PR merged on GitHub but local repo not updated):

**GitHub wins** - GitHub represents the canonical shared state.

When this conflict is detected, add a sync note to the output:
```
Info: Local repo may be behind remote. Consider running `git pull`.
```

---

## Context Mismatch Detection

After scanning configured repos, check if results suggest misconfiguration:

### Warning Triggers

1. **High Unknown Rate**: >50% of queried components return "Unknown" status
2. **Transcript Mismatch**: Transcripts mention repo names not in repos.json
3. **Empty Scans**: Configured repos return no relevant code for any component

### Warning Output

When triggered, add to Notes section:
```
Warning: Configured repos may not contain the discussed features.
- Transcripts mention: entourage-web, entourage-api
- Configured repos: entourage-plugin
Consider updating `.entourage/repos.json` to include missing repositories.
```

### Detection Method

1. After transcript search, extract repo names mentioned (patterns: `entourage-*`, `*-web`, `*-api`)
2. Compare against repos.json entries
3. If mismatch detected, include warning in output

---

## Output Format

```
## Status: [Project Name]

| Component | Status | Evidence | Source | Confidence |
|-----------|--------|----------|--------|------------|
| [Name] | Discussed/Planned/etc | [Brief description] | [Source] | High/Med/Low |

### Notes
- [Any caveats about verification limitations]
```

## Critical Rule

**Never mark a component as "Complete" or "In Progress" based solely on meeting transcripts.**

Meeting transcripts can only support `Discussed` or `Planned` status. Higher statuses require code evidence from repositories (local or GitHub).

If no repos are configured, add this note:
> Repository verification not configured. Maximum verifiable status is "Planned". Add repos to `.entourage/repos.json` for implementation status.

---

## Example Output

### With Both Local and GitHub Verification

**Query:** "What's the status of authentication?"

```
## Status: Entourage

| Component | Status | Evidence | Source | Confidence |
|-----------|--------|----------|--------|------------|
| Clerk auth | Shipped | PR #42 merged, deployed to prod | GitHub | Very High |
| User dashboard | Complete | PR #45 merged, CI passing | GitHub + Local | High |
| Email notifications | In Progress | PR #48 open, 2 approvals | GitHub | High |
| Analytics | Planned | Issue #52 created | GitHub | High |
| Notifications | Discussed | Mentioned Dec 21 meeting | Transcripts | High |

Info: Local repo may be behind remote. Consider running `git pull`.

### Evidence Details

**Clerk auth (Shipped)**
- PR: #42 "Add Clerk authentication" - merged Jan 8
- Actions: Build, Test, Lint passed
- Deployment: prod-v1.2.0 deployed Jan 8 14:32 UTC

**User dashboard (Complete)**
- PR: #45 "User dashboard" - merged Jan 10
- Actions: Build, Test passed
- Local: Tests found at `src/dashboard/__tests__/`
```

### With Local Repository Only

**Query:** "What's the status of authentication?"

```
## Status: Entourage

| Component | Status | Evidence | Source | Confidence |
|-----------|--------|----------|--------|------------|
| Clerk auth | Complete | Tests passing, merged to main | entourage-web | High |
| User dashboard | In Progress | Code exists, no tests | entourage-web | Medium |
| Email notifications | Discussed | Mentioned Dec 21 meeting | Transcripts | High |

### Notes
- GitHub verification not configured. Add `github` field to repos for PR/CI/deployment status.
```

### Without Repository Configuration

**Query:** "What's the status of the database?"

```
## Status: Entourage

| Component | Status | Evidence | Source | Confidence |
|-----------|--------|----------|--------|------------|
| Database schema | Planned | Architecture decided Dec 22 | Transcripts | Medium |
| Clerk auth | Discussed | Mentioned Dec 21 | Transcripts | Low |
| API endpoints | Unknown | No mentions found | - | Low |

### Notes
- Repository verification not configured. Maximum verifiable status is "Planned".
- Add repos to `.entourage/repos.json` for implementation status.
- Add `github` field to repos for PR/CI/deployment status.
```
