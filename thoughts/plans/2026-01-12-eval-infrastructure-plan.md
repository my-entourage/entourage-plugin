# Eval Infrastructure Plan for entourage-plugin

**Date:** 2026-01-12
**Status:** Draft - Awaiting Approval
**Context:** Based on Anthropic's "Demystifying Evals for AI Agents" best practices

---

## Executive Summary

Implement a lightweight, shell-based evaluation infrastructure that:
1. Keeps eval definitions co-located with skills (visible to contributors)
2. Uses GitHub Actions for CI/CD automation
3. Avoids adding JavaScript/Node.js dependencies to a Markdown/JSON-only plugin
4. Follows Anthropic's guidance on grading outputs rather than prescribing tool sequences

---

## Proposed Directory Structure

```
entourage-plugin/
├── skills/
│   └── [skill-name]/
│       ├── SKILL.md
│       ├── README.md
│       └── evals/
│           ├── cases.yaml          # Test case definitions (migrate from evaluation.json)
│           └── golden/             # Optional reference outputs
├── tests/
│   ├── run.sh                      # Main entry point
│   ├── graders/
│   │   └── check-output.sh         # Output validation helpers
│   ├── fixtures/                   # Sparse recorded responses (if needed)
│   └── results/                    # Gitignored - local results only
├── .github/
│   └── workflows/
│       └── evals.yml               # CI/CD pipeline
└── .gitignore                      # Add tests/results/
```

---

## Key Design Decisions

### 1. Co-located Eval Definitions

**Why:** Contributors see test cases alongside the skills they're testing. Changes to skills naturally prompt updates to related evals.

**Format:** Migrate from `evaluation.json` to `cases.yaml` for readability:

```yaml
# skills/grounded-query/evals/cases.yaml
name: grounded-query
description: Verify claims against source documents

cases:
  - id: supported-claim
    name: Direct evidence found
    input: "What database did the team choose?"
    setup:
      description: "Transcript contains: 'We decided to use Supabase'"
    expected:
      evidence_status: SUPPORTED
      contains:
        - Supabase
        - database
      not_contains:
        - I think
        - might be
        - probably

  - id: hallucination-prevention
    name: No evidence - should not hallucinate
    input: "What did the team decide about quantum computing?"
    setup:
      description: "No transcripts mention quantum computing"
    expected:
      evidence_status: NOT FOUND
      not_contains:
        - decided
        - chose
        - quantum computing integration
```

### 2. Shell-Based Test Runner

**Why:** Matches the project's dependency-free nature. No Node.js/Python required.

```bash
#!/bin/bash
# tests/run.sh

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="$PLUGIN_DIR/tests/results"
mkdir -p "$RESULTS_DIR"

# Parse arguments
SKILL_FILTER="${1:-}"
QUICK_MODE="${QUICK_MODE:-false}"

for cases_file in "$PLUGIN_DIR"/skills/*/evals/cases.yaml; do
  skill_dir=$(dirname $(dirname "$cases_file"))
  skill_name=$(basename "$skill_dir")

  # Skip if filter specified and doesn't match
  [[ -n "$SKILL_FILTER" && "$skill_name" != "$SKILL_FILTER" ]] && continue

  echo "=== Evaluating: $skill_name ==="

  # Run cases (implementation depends on YAML parser choice)
  # Options: yq, python one-liner, or simple grep-based parsing
done
```

### 3. Code-Based Graders (Shell)

**Why:** Deterministic checks don't need complex frameworks.

```bash
#!/bin/bash
# tests/graders/check-output.sh

check_contains() {
  local output="$1"
  local expected="$2"
  echo "$output" | grep -qi "$expected"
}

check_not_contains() {
  local output="$1"
  local forbidden="$2"
  ! echo "$output" | grep -qi "$forbidden"
}

check_has_table() {
  local output="$1"
  echo "$output" | grep -qE '\|.*\|.*\|'
}
```

### 4. GitHub Actions CI/CD

**Why:** Automated verification on every PR. Visible to contributors.

```yaml
# .github/workflows/evals.yml
name: Skill Evaluations

on:
  pull_request:
    paths:
      - 'skills/**'
  workflow_dispatch:
  schedule:
    - cron: '0 6 * * 1'  # Weekly on Monday

jobs:
  validate-structure:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate plugin structure
        run: |
          # Check required files exist
          test -f .claude-plugin/plugin.json
          jq empty .claude-plugin/plugin.json

          # Validate each skill has required files
          for skill in skills/*/; do
            test -f "$skill/SKILL.md" || (echo "Missing SKILL.md in $skill" && exit 1)
          done

  run-evals:
    runs-on: ubuntu-latest
    needs: validate-structure
    # Note: Requires Claude Code CLI or alternative execution method
    steps:
      - uses: actions/checkout@v4
      - name: Run evaluations
        run: ./tests/run.sh
```

### 5. What Gets Gitignored

```gitignore
# Add to .gitignore
tests/results/
*.eval.log
```

---

## Migration Path

### Phase 1: Infrastructure Setup
1. Create `tests/` directory structure
2. Create `run.sh` skeleton
3. Create basic graders
4. Add GitHub Actions workflow (structure validation only initially)
5. Update `.gitignore`

### Phase 2: Migrate Eval Definitions
1. Convert `skills/grounded-query/evaluations/evaluation.json` to `evals/cases.yaml`
2. Convert `skills/project-status/evaluations/evaluation.json` to `evals/cases.yaml`
3. Convert `skills/local-repo-check/evaluations/evaluation.json` to `evals/cases.yaml`
4. Convert `skills/github-repo-check/evaluations/evaluation.json` to `evals/cases.yaml`
5. Delete old `evaluations/` directories

### Phase 3: Add Adversarial Cases
Add negative/adversarial test cases to each skill:
- Hallucination prevention tests
- Edge case handling
- Malformed input handling

### Phase 4: CI/CD Execution (Future)
- Determine how to run Claude Code in CI (may require API key, Claude Code CLI installation)
- Implement pass@k testing for reliability metrics
- Add PR comment reporting

---

## What This Plan Does NOT Include

1. **VCR/tape recording** - Rejected as solving the wrong problem
2. **Node.js/npm dependencies** - Project is Markdown/JSON only
3. **Complex eval frameworks** (Braintrust, Promptfoo) - Overkill for current needs
4. **LLM-as-judge grading** - Can add later if needed
5. **Separate eval repository** - Co-location is simpler for single plugin

---

## Open Questions

1. **YAML parsing in shell:** Use `yq`? Python one-liner? Keep JSON format?
2. **CI execution:** How to run Claude Code CLI in GitHub Actions? API key management?
3. **pass@k implementation:** Defer to Phase 4 or include in Phase 1?
4. **Golden outputs:** Include reference solutions now or defer?

---

## Success Criteria

- [ ] `./tests/run.sh` executes all skill evals
- [ ] GitHub Actions validates plugin structure on every PR
- [ ] Eval definitions are visible alongside skills
- [ ] No new dependencies added to the plugin
- [ ] Contributors can easily add new test cases

---

## References

- [Anthropic: Demystifying Evals for AI Agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
- [Braintrust: Best AI evals tools for CI/CD in 2025](https://www.braintrust.dev/articles/best-ai-evals-tools-cicd-2025)
- [DEV Community: Integrating AI Evals into CI/CD](https://dev.to/kuldeep_paul/a-practical-guide-to-integrating-ai-evals-into-your-cicd-pipeline-3mlb)
- [GitHub: Claude Code Plugin Template](https://github.com/ivan-magda/claude-code-plugin-template)
