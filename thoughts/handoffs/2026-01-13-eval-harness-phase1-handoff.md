# Evaluation Harness Phase 1 Handoff

**Date:** 2026-01-13
**Status:** Complete - Ready for Testing

---

## Summary

Fixed the evaluation harness (`tests/run.sh`) to properly invoke skills and work on macOS. The infrastructure now follows Anthropic's agent evaluation methodology.

---

## What Was Completed

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

## Verification Completed

| Test | Result |
|------|--------|
| `./tests/validate.sh` | ✓ All 32 checks pass |
| `./tests/run.sh --dry-run grounded-query` | ✓ Shows correct skill invocation format |
| `./tests/run.sh --dry-run --verbose grounded-query` | ✓ Shows `/grounded-query <input>` format |
| `SKIP_CLAUDE=1 ./tests/run.sh grounded-query` | ✓ All 11 cases skipped correctly |

---

## What Remains (Not in Phase 1 Scope)

### Fixture Data Creation
The infrastructure supports fixtures, but no fixture data has been created yet. Each test case that requires context (repos.json, transcript files) needs:

```
skills/[skill]/evaluations/fixtures/[case-id]/
├── .entourage/
│   └── repos.json
└── data/
    └── transcripts/
        └── example.md
```

### Actual Claude Execution
Run.sh is ready to execute against Claude, but actual evaluation runs were not performed. To run:

```bash
./tests/run.sh grounded-query  # Single skill
./tests/run.sh                  # All skills
TRIALS_PER_CASE=3 ./tests/run.sh  # Multiple trials
```

### Pass Rate Target
Phase 1 success criteria: >80% pass rate with code-based graders.

Current: Not measured (needs actual Claude execution)

---

## Files Modified

| File | Changes |
|------|---------|
| `tests/run.sh` | Fixed timeout, skill invocation, added fixtures + pass@k |
| `tests/results/` | Cleared old artifacts |
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

## Next Steps

1. **Create fixture data** for test cases that need context
2. **Run actual evaluations** against Claude
3. **Measure pass rate** and iterate on skills or test cases
4. **When >80% pass rate achieved**: Request user approval for Phase 2 (LLM-as-judge)

---

## Reference

- Plan file: `/Users/jaredsisk/.claude/plans/glistening-dancing-sprout.md`
- Research: `/thoughts/research/2026-01-13-evaluating-ai-agents-testing-approaches.md`
- Anthropic methodology: https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
