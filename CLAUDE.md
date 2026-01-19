# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

entourage-plugin is a Claude Code plugin providing skills for project verification, context management, data import, and session tracking. Skills are invoked with `/skill-name` syntax.

## Development Commands

```bash
# Run all evaluations (requires Claude CLI and API access)
./tests/run.sh

# Run specific skill evaluation
./tests/run.sh grounded-query

# Validate evaluation JSON files (no API required)
./tests/validate.sh

# Dry run (preview without executing)
./tests/run.sh --dry-run

# Multi-trial for pass@k metrics
TRIALS_PER_CASE=3 ./tests/run.sh

# Run with local plugin
claude --plugin-dir ~/entourage-plugin
```

## Architecture

### Skill Structure

Each skill lives in `skills/<skill-name>/` with this structure:
```
skills/my-skill/
├── SKILL.md                 # Skill definition (YAML frontmatter + instructions)
├── README.md                # User documentation
└── evaluations/
    ├── evaluation.json      # Test cases with assertions
    └── fixtures/<case-id>/  # Test data per case
        └── .entourage/repos.json
```

SKILL.md requires frontmatter:
```yaml
---
name: skill-name
description: Brief description for skill selection
---
```

### Skill Categories

**Verification Skills** (check implementation status):
- `project-status` - Orchestrates other check skills, combines evidence
- `local-repo-check` - Scans local git repos for code/tests
- `github-repo-check` - Queries GitHub API (PRs, issues, Actions, deployments)
- `linear-check` - Queries Linear for issue status
- `linear-sync` - Updates Linear issues based on evidence
- `grounded-query` - Verifies claims against source documents

**Import Skills** (bring data into context):
- `import-hyprnote` - Import Hyprnote meeting transcripts
- `import-notion` - Export Notion pages to local markdown
- `update-timeline` - Build chronological events index from all sources

### Key Architectural Patterns

**Evidence Hierarchy**: `project-status` combines evidence from multiple sources with priority order: GitHub deployments > merged PRs > local code+tests > Linear issues > transcripts. GitHub is source of truth when local/remote conflict.

**Configuration Discovery**: Skills check for `.entourage/repos.json` (shared, committed) and `.entourage/paths.local.json` (personal paths, gitignored). Paths support `~` expansion.

**Skill Chaining**: Skills can invoke other skills (e.g., `/project-status` calls `/local-repo-check`). After outputting results, skills continue execution rather than stopping.

**Authentication Hierarchy**: MCP servers (OAuth) > CLI tools (gh, gcloud) > environment variables (tokens in .env.local)

### Session Tracking

Hooks in `hooks/hooks.json` trigger `scripts/session-start.sh` and `scripts/session-end.sh`. Requires `GITHUB_NICKNAME` env var. Disable with `CLAUDE_LOGGER_DISABLED=1` or `"sessionLogging": false` in `.entourage/config.json`.

## Evaluation Framework

Test cases in `evaluation.json` use these assertion types:
- `contains` / `notContains` - String presence checks
- `status` - Expected status value (can be array for alternatives)
- `evidenceStatus` - For grounded-query (SUPPORTED/PARTIAL/NOT FOUND)
- `hasSource` - Requires source citation

Grading functions are in `tests/lib/graders.sh`. Tests run in isolated temp directories with fixtures copied in.

## Adding a New Skill

1. Create `skills/my-skill/SKILL.md` with required frontmatter
2. Add `skills/my-skill/evaluations/evaluation.json` with test cases
3. Create fixtures in `skills/my-skill/evaluations/fixtures/<case-id>/`
4. Run `./tests/validate.sh my-skill` then `./tests/run.sh my-skill`

## Status Values

For project verification skills:
- `Shipped` - Deployed to production
- `Done` - Code + tests, or merged PR
- `In Review` - Open PR with review
- `In Progress` - Code exists
- `Todo` - Scheduled in Linear
- `Backlog` - Accepted but not scheduled
- `Triage` - Transcript mentions only
- `Unknown` - Insufficient evidence
- `Canceled` - Explicitly closed

For grounded-query:
- `SUPPORTED` - Direct evidence found
- `PARTIAL` - Related but not exact
- `NOT FOUND` - No evidence (unverified, not false)
