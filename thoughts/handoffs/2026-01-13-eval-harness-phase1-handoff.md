# Evaluation Harness Phase 1 & 1.5 Handoff

**Date:** 2026-01-13
**Status:** Phase 1.5 Complete - Iteration Required for >80% Pass Rate

---

## Summary

Fixed the evaluation harness (`tests/run.sh`) to properly invoke skills and work on macOS. Created fixture data for 10 representative test cases. Ran initial evaluations and documented results. The infrastructure now follows Anthropic's agent evaluation methodology.

---

## Phase 1: Harness Fixes (Complete)

### 1. Fixed macOS Compatibility
- Added timeout command detection (gtimeout vs timeout vs none)
- Gracefully handles systems without timeout command

### 2. Fixed Skill Invocation
- Changed from `claude --print "$input"` to `claude --plugin-dir $PLUGIN_DIR --print "/$skill_name $input"`
- Skills are now properly loaded via `--plugin-dir`
- Input is now prefixed with skill name (e.g., `/grounded-query What database...`)

### 3. Added Fixture Data Support
- Added `setup_test_context()` function
- Looks for fixtures in `skills/[skill]/evaluations/fixtures/[case-id]/`
- Copies fixture data to temp working directory before test

### 4. Added pass@k Support
- Added `TRIALS_PER_CASE` environment variable (default: 1)
- Results include trial number suffix when running multiple trials
- Summary reports aggregate across all trials

### 5. Cleaned Up Old Results
- Cleared `tests/results/` directory of broken test artifacts
- `.gitignore` already covers `tests/results/`

---

## Phase 1.5: Fixtures & Initial Evaluation (Complete)

### Fixtures Created (10 total)

| Skill | Fixtures | Purpose |
|-------|----------|---------|
| **grounded-query** | `supported-claim`, `not-found`, `status-inflation-prevention` | Core evidence verification patterns |
| **local-repo-check** | `complete-high-confidence`, `unknown-component` | Success + failure code scanning paths |
| **github-repo-check** | `shipped-deployment`, `unknown-no-evidence` | Success + failure GitHub API paths |
| **project-status** | `both-sources`, `discussed-only`, `unknown-component` | Multi-source + single source patterns |

### Documentation Created

- `tests/README.md` - Getting started guide for third-party developers

### Evaluation Results

| Skill | Pass Rate | Passing | Failing | Notes |
|-------|-----------|---------|---------|-------|
| grounded-query | **55%** | 6/11 | 5/11 | Skill works correctly; assertions too strict |
| local-repo-check | **30%** | 3/10 | 7/10 | Most cases lack fixtures |
| github-repo-check | — | — | — | Not yet run (requires GitHub auth) |
| project-status | — | — | — | Not yet run |

**Current aggregate: ~40% (9/21 tested)**
**Target: >80% before Phase 2**

### Failure Analysis

Failures fall into three categories:

1. **Assertions too strict** (e.g., `status-inflation-prevention`)
   - Skill output is semantically correct
   - Test expects exact phrases like "will implement" but skill says "planned but not yet implemented"
   - **Fix:** Relax assertions or add alternative accepted phrases

2. **Missing fixture data** (e.g., `partial-evidence`, `no-data-files`)
   - Test case defined but no fixture created
   - Skill runs against wrong context
   - **Fix:** Create fixture or mark test as requiring fixture

3. **LLM output variation** (e.g., `person-attribution`)
   - Non-deterministic output phrasing
   - **Fix:** Use more flexible assertions or multiple acceptable values

---

## Verification Completed

| Test | Result |
|------|--------|
| `./tests/validate.sh` | ✓ All 32 checks pass |
| `./tests/run.sh --dry-run grounded-query` | ✓ Shows correct skill invocation format |
| `./tests/run.sh --dry-run --verbose grounded-query` | ✓ Shows `/grounded-query <input>` format |
| `SKIP_CLAUDE=1 ./tests/run.sh grounded-query` | ✓ All 11 cases skipped correctly |
| `./tests/run.sh grounded-query` | ✓ Runs, 6/11 pass |
| `./tests/run.sh local-repo-check` | ✓ Runs, 3/10 pass |

---

## Files Modified/Created

| File | Changes |
|------|---------|
| `tests/run.sh` | Fixed timeout, skill invocation, added fixtures + pass@k |
| `tests/README.md` | **NEW** - Getting started guide |
| `tests/results/` | Cleared old artifacts, new results generated |
| `skills/*/evaluations/fixtures/` | **NEW** - 10 fixture directories |
| `thoughts/research/2026-01-13-evaluating-ai-agents-testing-approaches.md` | Added implementation notes |

---

## Architecture Notes

The Phase 1 architecture supports Phase 2 (LLM-as-judge) without modification:

| Component | Phase 1 | Phase 2 Extension |
|-----------|---------|-------------------|
| `evaluation.json` | Test case definitions | Add `rubric` field |
| `run.sh` | Execute skills, code graders | Add `--llm-grade` flag |
| `graders.sh` | Code-based assertions | Keep as-is |
| New `llm-grader.sh` | N/A | Model-based grading |

---

## Next Steps to Reach >80% Pass Rate

### Priority 1: Adjust Test Assertions
Review failing tests where skill output is semantically correct but wording differs:
- `status-inflation-prevention` - accepts "NOT complete" language
- `not-found` - accepts "not find any evidence" language
- `person-attribution` - accepts "suggested" without "mentioned"

### Priority 2: Add Missing Fixtures
Create fixtures for test cases that currently lack context:
- `partial-evidence` - needs transcript with indirect evidence
- `no-data-files` - needs empty data directory
- Additional local-repo-check and project-status cases

### Priority 3: Run Full Evaluation Suite
```bash
./tests/run.sh --verbose  # All skills
```

### Phase 2 Trigger
When aggregate pass rate exceeds 80%:
1. Document final metrics
2. Request user approval
3. Proceed with LLM-as-judge implementation

---

## Commits

| Hash | Description |
|------|-------------|
| `53598dd` | Add README documentation for local-repo-check and github-repo-check skills |
| `629cb90` | Add evaluation fixtures and tests README for Phase 1.5 |

---

## Reference

- Plan file: `/Users/jaredsisk/.claude/plans/glistening-dancing-sprout.md`
- Research: `/thoughts/research/2026-01-13-evaluating-ai-agents-testing-approaches.md`
- Anthropic methodology: https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
