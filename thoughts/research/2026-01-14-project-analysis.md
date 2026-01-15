---
date: 2026-01-14T12:30:00-08:00
researcher: ii-vo
git_commit: 388263634020cb3be222d8f0e5d3e1b2b3bfaa59
branch: main
repository: my-entourage/entourage-plugin
topic: "Complete Project Analysis"
tags: [research, codebase, architecture, skills, evaluation]
status: complete
last_updated: 2026-01-14
last_updated_by: ii-vo
---

# Research: Complete Project Analysis

**Date**: 2026-01-14T12:30:00-08:00
**Researcher**: ii-vo
**Git Commit**: 388263634020cb3be222d8f0e5d3e1b2b3bfaa59
**Branch**: main
**Repository**: my-entourage/entourage-plugin

## Research Question
Comprehensive analysis of the entourage-plugin project: purpose, architecture, components, and development status.

## Summary

The **entourage-plugin** is a Claude Code plugin containing reusable skills for the Entourage team. Its primary purpose is to **prevent AI hallucination in project status reporting** by requiring evidence-based verification of claims. The plugin implements a multi-source verification system that cross-references:

1. **Meeting transcripts** - for discussion and planning evidence
2. **Local git repositories** - for code implementation evidence
3. **GitHub API** - for PRs, issues, Actions, and deployment evidence

The project has 4 core skills, a shell-based evaluation infrastructure, and comprehensive documentation of development decisions.

## Detailed Findings

### Project Overview

**Purpose**: Shared Claude Code skills for evidence-based project verification

**Plugin Name**: `entourage` (version 1.0.0)

**Repository**: https://github.com/my-entourage/entourage-plugin

**Structure**:
```
entourage-plugin/
├── .claude-plugin/          # Plugin manifests
│   ├── plugin.json          # Core manifest
│   └── marketplace.json     # Marketplace listing
├── skills/                  # Core skills
│   ├── grounded-query/
│   ├── project-status/
│   ├── local-repo-check/
│   └── github-repo-check/
├── commands/                # Simple commands
│   └── hello.md
├── examples/                # Configuration templates
│   └── repos.json.example
├── tests/                   # Evaluation infrastructure
│   ├── run.sh
│   ├── validate.sh
│   ├── lib/graders.sh
│   └── README.md
├── thoughts/                # Development documentation
│   ├── handoffs/
│   ├── plans/
│   └── research/
└── .github/workflows/       # CI/CD
    └── evals.yml
```

---

### Core Skills

#### 1. grounded-query (`skills/grounded-query/SKILL.md`)

**Purpose**: Verify factual claims against source documents to prevent hallucination.

**Invocation**: `/grounded-query <question>`

**Workflow**:
1. Generate initial response
2. Extract verifiable claims
3. Search data files for evidence (Grep, Read tools)
4. Classify: SUPPORTED, PARTIAL, NOT FOUND
5. Output evidence table

**Output Format**:
```markdown
### Evidence

| Claim | Status | Source |
|-------|--------|--------|
| [claim] | SUPPORTED | folder/filename |
```

**Critical Rule**: Never claim "Complete" based only on discussions.

---

#### 2. project-status (`skills/project-status/SKILL.md`)

**Purpose**: Report implementation status with multi-source evidence verification.

**Invocation**: `/project-status <components>`

**Status Levels**:
| Status | Definition | Evidence Required |
|--------|------------|-------------------|
| Discussed | Mentioned in meetings | Transcript reference |
| Planned | Decisions documented | Decision + rationale, or GitHub Issue |
| In Progress | Implementation started | Code in repo or open PR |
| Complete | Working implementation | Code + tests, or merged PR with CI |
| Shipped | Deployed to production | Deployment evidence |
| Unknown | Insufficient evidence | N/A |

**Workflow**:
1. Identify components in query
2. Search transcripts for mentions
3. Check `.entourage/repos.json` configuration
4. If `path` configured: invoke `/local-repo-check`
5. If `github` configured: invoke `/github-repo-check`
6. Combine evidence using 13-level priority hierarchy
7. Output status table with sources

**Unified Evidence Hierarchy** (13 levels):
1. Deployment to production → Shipped
2. PR merged + CI passing → Complete
3. Code + tests on main → Complete
4. PR merged (no CI info) → Complete
5. Code + tests (any branch) → Complete
6. Open PR with approvals → In Progress
7. Code exists (no tests) → In Progress
8. Open PR (no reviews) → In Progress
9. Feature branch exists → In Progress
10. GitHub Issue (in progress label) → In Progress
11. GitHub Issue (open) → Planned
12. Architecture decision documented → Planned
13. Meeting discussion → Discussed

**Conflict Resolution**: GitHub wins when local and GitHub disagree.

**Agent Skills as Features**: Treats `SKILL.md` files as product features for status checks.

---

#### 3. local-repo-check (`skills/local-repo-check/SKILL.md`)

**Purpose**: Scan local git repositories for implementation evidence.

**Invocation**: `/local-repo-check <components>` (or via project-status)

**Configuration**: Reads `.entourage/repos.json` for repository paths.

**Scanning Process**:
1. Check config file exists
2. Expand paths (tilde expansion)
3. For each component:
   - Convert to multiple naming conventions (CamelCase, snake_case, kebab-case)
   - Glob for matching files
   - Glob for test files
   - Check git history for commits
   - Check for feature branches

**Evidence Synthesis**:
- Code + tests on main → Complete (High)
- Code + tests any branch → Complete (Medium)
- Code, no tests → In Progress (Medium)
- Feature branch only → In Progress (Low)
- No evidence → Unknown

---

#### 4. github-repo-check (`skills/github-repo-check/SKILL.md`)

**Purpose**: Query GitHub API for PRs, issues, Actions, and deployments.

**Invocation**: `/github-repo-check <components>` (or via project-status)

**Authentication**:
1. Preferred: `gh` CLI (automatic, secure)
2. Fallback: Token in `.entourage/repos.json`

**API Queries**:
- Search PRs mentioning component
- Recent merged PRs
- Search issues
- GitHub Actions status
- Deployments
- PR reviews

**Evidence Synthesis**:
- Deployment exists → Shipped (Very High)
- PR merged + Actions passing → Complete (Very High)
- PR merged → Complete (High)
- Open PR with approvals → In Progress (High)
- Open PR → In Progress (Medium)
- Issue with "in progress" label → In Progress (Medium)
- Issue exists → Planned (High)
- No evidence → Unknown

---

### Evaluation Infrastructure

#### Architecture

**Layer 1: Validation** (`tests/validate.sh`)
- JSON syntax validation
- Required field checks
- Status value validation
- No Claude API calls required

**Layer 2: Execution** (`tests/run.sh`)
- Runs skills via Claude CLI
- Grades outputs against assertions
- Supports pass@k metrics via TRIALS_PER_CASE
- Stores results in `tests/results/`

#### Grading System (`tests/lib/graders.sh`)

**Assertion Types**:
- `contains`: Output includes strings
- `notContains`: Output excludes strings
- `status`: Status level match
- `confidence`: Confidence level match
- `evidenceStatus`: SUPPORTED/PARTIAL/NOT FOUND
- `hasSource`: File references present
- `format`: Table formatting
- `tableHeaders`: Specific headers exist

#### Test Case Structure

Location: `skills/[skill]/evaluations/evaluation.json`

```json
{
  "name": "skill-name",
  "description": "Skill description",
  "testCases": [
    {
      "id": "unique-id",
      "name": "Human-readable name",
      "input": "/skill-name query",
      "setup": {
        "description": "Test context"
      },
      "expectedBehavior": "Plain English description",
      "expectedOutput": {
        "contains": ["word1", "word2"],
        "status": "Complete",
        "confidence": "High"
      }
    }
  ]
}
```

#### Fixture System

Location: `skills/[skill]/evaluations/fixtures/[case-id]/`

Contents:
- `.entourage/repos.json` - Repository configuration
- `data/transcripts/*.md` - Mock meeting transcripts
- `mock-repo/` - Mock git repository with code/tests

Fixtures are copied to working directory before skill execution.

#### Test Coverage

| Skill | Test Cases |
|-------|------------|
| grounded-query | 11 |
| local-repo-check | 10 |
| github-repo-check | 18 |
| project-status | 13 |
| **Total** | **52** |

---

### CI/CD Pipeline

**File**: `.github/workflows/evals.yml`

**Jobs**:
1. `validate-plugin` - Verify plugin manifest and skill files
2. `validate-evaluations` - Run `tests/validate.sh`
3. `lint-json` - Validate all JSON syntax
4. `check-eval-coverage` - Report evaluation coverage per skill
5. `summary` - Aggregate results

**Triggers**: PR and push to main when `skills/**` or `tests/**` change

**Note**: Does NOT run Claude evaluations (no API key in CI)

---

### Development History

#### Timeline

| Date | Event |
|------|-------|
| 2026-01-11 | Problem identified: Status inflation from transcript-only evidence |
| 2026-01-11 | Stage 1 & 2 implemented: Local + GitHub repository checking |
| 2026-01-12 | Evaluation infrastructure planned |
| 2026-01-12 | First evaluation execution, blocked by stop token bug |
| 2026-01-13 | Research completed on agent testing methodologies |
| 2026-01-13 | Evaluation harness fixed, 40% pass rate achieved |

#### Key Decisions

1. **GitHub is source of truth** - When local and GitHub conflict, GitHub wins
2. **Shell-based infrastructure** - No Node.js/npm dependencies
3. **Co-located evaluations** - Tests live with skills
4. **Two-phase testing** - Code-based graders first, LLM-as-judge later
5. **Evidence hierarchy** - 13-level priority system

#### Current Status

- Phase 1.5 complete: Harness works, fixtures created
- ~40% pass rate (9/21 tested cases)
- Target: >80% before Phase 2 (LLM-as-judge)
- github-repo-check not yet tested (requires auth)

---

### Configuration

#### Plugin Manifest (`.claude-plugin/plugin.json`)

```json
{
  "name": "entourage",
  "version": "1.0.0",
  "description": "Shared skills for the Entourage team",
  "author": {
    "name": "My Entourage",
    "email": "blaze46593@gmail.com"
  },
  "repository": "https://github.com/my-entourage/entourage-plugin"
}
```

#### Repository Configuration (`.entourage/repos.json`)

```json
{
  "github": {
    "token": "ghp_xxx",
    "defaultOrg": "my-org"
  },
  "repos": [
    {
      "name": "my-app",
      "path": "~/code/my-app",
      "mainBranch": "main",
      "github": "my-org/my-app"
    }
  ]
}
```

---

## Code References

- Plugin manifest: `.claude-plugin/plugin.json`
- Core skill (grounded-query): `skills/grounded-query/SKILL.md`
- Core skill (project-status): `skills/project-status/SKILL.md`
- Core skill (local-repo-check): `skills/local-repo-check/SKILL.md`
- Core skill (github-repo-check): `skills/github-repo-check/SKILL.md`
- Evaluation runner: `tests/run.sh`
- Validation script: `tests/validate.sh`
- Grading library: `tests/lib/graders.sh`
- CI workflow: `.github/workflows/evals.yml`

## Architecture Documentation

### Skill Invocation Pattern

Skills are defined as `SKILL.md` files in `skills/[name]/` directories. Claude Code discovers them automatically and makes them available via `/skill-name` commands.

### Configuration Discovery Pattern

Skills that need repository configuration:
1. Check for `.entourage/repos.json` in working directory
2. Parse JSON for repo entries
3. Expand paths (tilde → home directory)
4. Use `path` field for local scanning, `github` field for API queries

### Evidence Aggregation Pattern

The project-status skill orchestrates two sub-skills:
1. Invoke `/local-repo-check` if `path` configured
2. Invoke `/github-repo-check` if `github` configured
3. Combine results using priority hierarchy
4. Higher priority evidence overrides lower

### Evaluation Pattern

Two-layer validation:
1. **Plumbing layer** (validate.sh): Structure only, CI-safe
2. **Execution layer** (run.sh): Requires Claude API

Assertions are code-based (deterministic), not LLM-based.

## Historical Context

### Development Documents

- `thoughts/handoffs/2026-01-11-repository-status-verification-plan.md` - Original problem + solution design
- `thoughts/handoffs/2026-01-12-evaluation-plan-handoff.md` - Evaluation execution attempt
- `thoughts/handoffs/2026-01-13-eval-harness-phase1-handoff.md` - Infrastructure fixes
- `thoughts/plans/2026-01-12-eval-infrastructure-plan.md` - Testing architecture proposal
- `thoughts/research/2026-01-13-evaluating-ai-agents-testing-approaches.md` - Methodology research

### Problem Origin

The plugin was created to solve a specific problem: Claude was marking components as "Complete" based on meeting transcripts where features were merely discussed, not implemented. The solution requires verification against actual code and GitHub data before assigning completion status.

## Related Research

- `thoughts/research/2026-01-13-evaluating-ai-agents-testing-approaches.md` - Testing methodology research

## Open Questions

1. **github-repo-check testing** - How to test GitHub API skill without exposing tokens in CI?
2. **Pass rate improvement** - What assertion adjustments needed to reach >80%?
3. **Phase 2 implementation** - When and how to add LLM-as-judge grading?
4. **Marketplace publishing** - Is the plugin ready for marketplace distribution?
