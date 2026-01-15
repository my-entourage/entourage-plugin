# Agent Evaluation Assessment - Handoff Document

**Date:** 2026-01-15
**Updated:** 2026-01-15 15:45
**Status:** Reliability Analysis Complete
**Branch:** `claude-agent-eval-analysis`

---

## Summary

Comprehensive assessment of the Entourage plugin evaluation system against Anthropic's agent evaluation framework. Created metrics dashboard structure and parallelized execution plan.

---

## Current Status

### Completed ✅

| Task | Details |
|------|---------|
| Framework research | Read Anthropic eval guide, extracted key concepts |
| Infrastructure audit | Mapped existing test harness to framework recommendations |
| Coverage analysis | 25 active tests, 64 pending across 6 skills |
| Metrics dashboard | Created visual template with pass@k, pass^k explanations |
| Parallelization plan | Designed 6-worktree execution strategy |

### Ready for Execution 🚀

| Step | Priority | Work |
|------|----------|------|
| **Step 0** | FIRST | Build metrics dashboard → **Check in with user** |
| Step 1 | After approval | Run evals (parallel worktrees) |
| Step 2 | After evals | Build new tests (parallel worktrees) |

### Pending ⏳

- Run baseline evaluations
- Populate metrics dashboard with real data
- Create additional test fixtures
- Add negative/edge case tests
- Implement pass^k metric in `run.sh`

---

## Evaluation Results (2026-01-15)

```
┌─────────────────────────────────────────────────────────────────────┐
│                       BASELINE METRICS (k=3)                         │
│                                                                      │
│   Overall:  Single: 58%    pass@3: 79%    pass^3: 40%               │
│                                                                      │
├─────────────────┬────────┬────────┬────────┬────────────────────────┤
│ Skill           │ Single │ pass@3 │ pass^3 │ Status                 │
├─────────────────┼────────┼────────┼────────┼────────────────────────┤
│ grounded-query  │  83%   │ 100%   │  58%   │ ⚠️ Moderate            │
│ project-status  │ 100%   │ 100%   │ 100%   │ ✅ Reliable            │
│ local-repo-check│ 100%   │ 100%   │ 100%   │ ✅ Reliable            │
│ github-repo-check│100%   │ 100%   │ 100%   │ ✅ Reliable            │
│ linear-check    │   7%   │  19%   │  <1%   │ ❌ Failing             │
│ linear-sync     │   8%   │  23%   │  <1%   │ ❌ Failing             │
└─────────────────┴────────┴────────┴────────┴────────────────────────┘
```

### Key Findings
- **3 skills at 100%** - project-status, local-repo-check, github-repo-check
- **2 skills failing** - linear-check (7%), linear-sync (23%) need investigation
- **39% gap** between pass@3 and pass^3 indicates reliability issues

### Reliability Analysis (Completed)

**Why reliable skills succeed (100% pass^3):**
- Test negative cases ("component not found" → deterministic "Unknown")
- Use local fixtures only, no external API dependencies
- Structured field assertions (not free-text substring matching)

**Why linear-* skills fail (7-8%):**
- MCP auth fails in subprocess - tests can't authorize with Linear API
- Assertions expect real API data that's unavailable

**Why grounded-query is moderate (83%, 58% pass^3):**
- Non-deterministic claim extraction (LLM phrases claims differently)
- `notContains` assertions can't distinguish "NOT complete" from "complete"

**Full analysis:** `thoughts/research/2026-01-13-evaluating-ai-agents-testing-approaches.md` (Addendum: Reliability Analysis)

---

## Framework Alignment

```
Implemented                     Gaps
───────────────────────────    ───────────────────────────
✅ Clear success criteria      ❌ pass^k metric not calculated
✅ Outcome-based grading       ❌ Model-based graders
✅ Isolated environments       ❌ Human calibration
✅ Multi-trial support         ⚠️ Need more negative tests
✅ Code-based graders          ⚠️ Most tests from design, not failures
```

---

## Key Files

### Plan & Report
- `thoughts/plans/2026-01-15-eval-assessment-plan.md` - Execution plan
- `tests/results/eval-report.md` - Metrics dashboard template

### Reference
- `thoughts/research/2026-01-15-claude-code-agent-evaluation-framework.md` - Framework guide

### Infrastructure
- `tests/run.sh` - Evaluation harness
- `tests/validate.sh` - Structure validation
- `tests/lib/graders.sh` - Code-based graders

---

## Execution Plan

### Phase 1: Metrics & Baseline (Parallel)

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  WORKTREE 1  │  │  WORKTREE 2  │  │  WORKTREE 3  │
│              │  │              │  │              │
│  Dashboard   │  │  Run Evals   │  │  Run Evals   │
│  Creation    │  │  Skills 1-3  │  │  Skills 4-6  │
│              │  │              │  │              │
│  Branch:     │  │  Branch:     │  │  Branch:     │
│  eval-       │  │  eval-run-   │  │  eval-run-   │
│  dashboard   │  │  batch-1     │  │  batch-2     │
└──────────────┘  └──────────────┘  └──────────────┘
```

### Phase 2: Build Tests (Parallel)

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  WORKTREE 4  │  │  WORKTREE 5  │  │  WORKTREE 6  │
│              │  │              │  │              │
│  New Tests   │  │  New Tests   │  │  Fixtures    │
│  (Positive)  │  │  (Negative)  │  │  Creation    │
│              │  │              │  │              │
│  Branch:     │  │  Branch:     │  │  Branch:     │
│  eval-new-   │  │  eval-new-   │  │  eval-new-   │
│  positive    │  │  negative    │  │  fixtures    │
└──────────────┘  └──────────────┘  └──────────────┘
```

---

## Next Steps for Incoming Agent

1. **Review plan** at `thoughts/plans/2026-01-15-eval-assessment-plan.md`
2. **Run baseline** with `./tests/run.sh --verbose`
3. **Populate dashboard** in `tests/results/eval-report.md`
4. **Execute worktree strategy** or adapt as needed

---

## Commands to Resume

```bash
# Validate structure (no API)
./tests/validate.sh

# Run all active evals
./tests/run.sh --verbose

# Run specific skill
./tests/run.sh grounded-query

# Multi-trial for pass@k
TRIALS_PER_CASE=3 ./tests/run.sh
```

---

## Related Documents

- Previous handoff: `2026-01-15-gmail-integration-orchestration-handoff.md`
- Eval infrastructure plan: `thoughts/plans/2026-01-12-eval-infrastructure-plan.md`
- Framework reference: `thoughts/research/2026-01-15-claude-code-agent-evaluation-framework.md`
