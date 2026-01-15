# Agent Evaluation Assessment Plan

**Date:** 2026-01-15
**Status:** In Progress
**Reference:** [Anthropic Evaluation Guide](https://docs.anthropic.com/en/docs/agents/evaluation/overview)

---

## Objective

1. Create metrics dashboard with pass@k and pass^k visualization
2. Run evaluations to populate dashboard
3. Build additional tests for comprehensive coverage

---

## Execution Strategy

```
┌─────────────────────────────────────────────────────────────────────┐
│                        EXECUTION WORKFLOW                            │
│                                                                       │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  STEP 0: BUILD DASHBOARD (First Priority)                    │   │
│   │                                                              │   │
│   │  → Create metrics dashboard in tests/results/dashboard.md    │   │
│   │  → Include: Single pass rate, pass@k, pass^k visualizations  │   │
│   │  → CHECK IN WITH USER before proceeding                      │   │
│   │                                                              │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│                    ┌──────────────────┐                             │
│                    │  USER REVIEW     │                             │
│                    │  Dashboard OK?   │                             │
│                    └────────┬─────────┘                             │
│                              │                                       │
│                              ▼                                       │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  STEP 1: RUN EVALUATIONS (Parallel Worktrees)               │   │
│   │                                                              │   │
│   │  ┌──────────────┐  ┌──────────────┐                         │   │
│   │  │  WORKTREE 1  │  │  WORKTREE 2  │                         │   │
│   │  │  Skills 1-3  │  │  Skills 4-6  │                         │   │
│   │  └──────────────┘  └──────────────┘                         │   │
│   │                                                              │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  STEP 2: BUILD NEW TESTS (Parallel Worktrees)               │   │
│   │                                                              │   │
│   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │   │
│   │  │  Positive    │  │  Negative    │  │  Fixtures    │      │   │
│   │  │  Tests       │  │  Tests       │  │  Creation    │      │   │
│   │  └──────────────┘  └──────────────┘  └──────────────┘      │   │
│   │                                                              │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│                    ┌──────────────────┐                             │
│                    │  MERGE & REPORT  │                             │
│                    └──────────────────┘                             │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Step 0: Build Metrics Dashboard (FIRST)

### Deliverable
Create `tests/results/dashboard.md` with:
- Single pass rate per skill
- pass@k calculation (at least one success in k trials)
- pass^k calculation (all k trials succeed)
- Visual bar charts
- Per-skill breakdown

### Checkpoint
**→ CHECK IN WITH USER to review dashboard before proceeding**
- Show dashboard structure
- Get feedback on visualization
- Confirm metrics are correct
- Only proceed after user approval

---

## Step 1: Run Evaluations (After Dashboard Approval)

### Worktree 1: Dashboard Creation
**Branch:** `eval-metrics-dashboard`
**Agent:** Dashboard Builder

```bash
# Create worktree
git worktree add ../eval-dashboard eval-metrics-dashboard

# Task: Create metrics dashboard with:
# - Single pass rate display
# - pass@k calculation & visualization
# - pass^k calculation & visualization
# - Per-skill breakdown
# - Time series tracking
```

**Deliverable:** `tests/results/dashboard.md` with real-time metrics

### Worktree 2: Run Evals (Skills 1-3)
**Branch:** `eval-run-batch-1`
**Agent:** Eval Runner 1

```bash
# Create worktree
git worktree add ../eval-batch-1 eval-run-batch-1

# Task: Run evaluations for:
# - grounded-query
# - project-status
# - local-repo-check

# Command:
TRIALS_PER_CASE=3 ./tests/run.sh grounded-query project-status local-repo-check
```

### Worktree 3: Run Evals (Skills 4-6)
**Branch:** `eval-run-batch-2`
**Agent:** Eval Runner 2

```bash
# Create worktree
git worktree add ../eval-batch-2 eval-run-batch-2

# Task: Run evaluations for:
# - github-repo-check
# - linear-check
# - linear-sync

# Command:
TRIALS_PER_CASE=3 ./tests/run.sh github-repo-check linear-check linear-sync
```

---

## Phase 2: Build Additional Tests (Parallel)

### Worktree 4: New Positive Tests
**Branch:** `eval-new-positive-tests`
**Agent:** Test Writer (Positive)

```bash
# Task: Create 5 new positive test cases
# Focus: Happy path scenarios not yet covered
# Skills: grounded-query, project-status
```

### Worktree 5: New Negative Tests
**Branch:** `eval-new-negative-tests`
**Agent:** Test Writer (Negative)

```bash
# Task: Create 5 new negative test cases
# Focus: Error handling, hallucination prevention
# Skills: All
```

### Worktree 6: Fixture Creation
**Branch:** `eval-new-fixtures`
**Agent:** Fixture Builder

```bash
# Task: Create 5 missing fixtures for pending tests
# Priority: partial-evidence, hallucination-attempt, etc.
```

---

## Current State Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    EVALUATION COVERAGE                       │
├─────────────────┬────────┬─────────┬────────────────────────┤
│ Skill           │ Active │ Pending │ Coverage Bar           │
├─────────────────┼────────┼─────────┼────────────────────────┤
│ grounded-query  │   2    │    9    │ ██░░░░░░░░ 18%        │
│ project-status  │   2    │   13    │ █░░░░░░░░░ 13%        │
│ local-repo-check│   2    │    8    │ ██░░░░░░░░ 20%        │
│ github-repo-check│  1    │   17    │ █░░░░░░░░░  6%        │
│ linear-check    │   5    │   12    │ ███░░░░░░░ 29%        │
│ linear-sync     │  13    │    5    │ ███████░░░ 72%        │
├─────────────────┼────────┼─────────┼────────────────────────┤
│ TOTAL           │  25    │   64    │ ███░░░░░░░ 28%        │
└─────────────────┴────────┴─────────┴────────────────────────┘
```

---

## Framework Alignment Checklist

### Core Requirements

| Requirement | Status | Action Needed |
|-------------|:------:|---------------|
| Clear success criteria | ✅ | None |
| Isolated trial environments | ✅ | None |
| Grade outcomes (not tool sequences) | ✅ | None |
| Positive + negative test cases | ⚠️ | Add 10 negative cases |
| Multi-trial support (pass@k) | ✅ | Implement pass^k metric |
| Tasks from real failures | ⚠️ | Source from production bugs |

### Grader Types

```
Currently Implemented          Not Yet Implemented
──────────────────────         ────────────────────
✅ String matching             ❌ Model-based rubrics
✅ Table validation            ❌ Human calibration
✅ Status verification         ❌ Comparative ranking
✅ Evidence classification
✅ Tool invocation checks
```

---

## Phase 1: Immediate Actions

### 1.1 Run Baseline Evaluation

```bash
./tests/run.sh --verbose 2>&1 | tee tests/results/baseline-2026-01-15.log
```

### 1.2 Activate Priority Tests

| Test Case | Skill | Why Priority |
|-----------|-------|--------------|
| `partial-evidence` | grounded-query | Common real-world scenario |
| `hallucination-attempt` | grounded-query | Safety-critical |
| `multi-component` | project-status | Aggregation logic |
| `open-pr-with-reviews` | github-repo-check | Common workflow |
| `in-progress-no-tests` | local-repo-check | Partial implementation |

### 1.3 Add Dual Metrics

Modify `tests/run.sh` to report:

```
pass@k  →  P(at least 1 success in k trials)
pass^k  →  P(all k trials succeed)
```

---

## Phase 2: Comprehensive Coverage

### New Test Categories Needed

```
Error Handling          Edge Cases              Safety
──────────────────     ──────────────────     ──────────────────
• Missing config       • Empty results        • Hallucination
• Invalid input        • Very long input      • Conflicting sources
• API timeout          • Special characters   • Future dates
• Rate limiting        • Unicode/emoji        • Non-existent topics
```

### Proposed Test Distribution

```
            Current                    Target
         ┌───────────┐              ┌───────────┐
         │ Positive  │              │ Positive  │
         │   ~85%    │      →       │   ~60%    │
         └───────────┘              ├───────────┤
                                    │ Negative  │
                                    │   ~25%    │
                                    ├───────────┤
                                    │   Edge    │
                                    │   ~15%    │
                                    └───────────┘
```

---

## Phase 3: Model-Based Graders

### Rubric Scoring (Proposed)

```
Response Quality Rubric
───────────────────────
5 │ Perfect - All claims supported, clear sourcing
4 │ Good - Most claims supported, minor gaps
3 │ Adequate - Key claims supported, some unsourced
2 │ Weak - Many unsupported claims
1 │ Poor - Mostly unsourced or incorrect
```

### Implementation

```bash
# tests/lib/model_graders.sh

grade_with_rubric() {
    local output="$1"
    local rubric="$2"

    claude --print "Score this output 1-5: $rubric\n\nOutput:\n$output"
}
```

---

## Phase 4: CI Pipeline

### Current vs Target

```
CURRENT                         TARGET
────────────────────           ────────────────────
✅ validate.sh (CI)            ✅ validate.sh (CI)
❌ run.sh (manual only)   →    ✅ run.sh (CI on schedule)
❌ No metrics dashboard        ✅ Results artifact upload
```

---

## Success Criteria

| Metric | Current | Target | Priority |
|--------|---------|--------|----------|
| Active tests | 25 | 50 | High |
| Pass rate (baseline) | TBD | >80% | Medium |
| Negative test coverage | ~15% | ~25% | High |
| Model graders | 0 | 2 | Low |
| CI evaluation runs | No | Yes | Medium |

---

## Next Steps

1. [ ] Run baseline evaluation → Record in report
2. [ ] Create 5 missing fixtures
3. [ ] Activate 5 priority pending tests
4. [ ] Implement pass^k metric
5. [ ] Add 3 hallucination-prevention tests

---

## Related Documents

- `thoughts/handoffs/2026-01-15-eval-assessment-handoff.md` - Handoff doc
- `thoughts/research/2026-01-15-claude-code-agent-evaluation-framework.md` - Framework reference
- `tests/README.md` - Test harness documentation
- `tests/results/eval-report.md` - Metrics dashboard
