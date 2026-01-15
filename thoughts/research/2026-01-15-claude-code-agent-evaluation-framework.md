# Agent Evaluation Framework

> Reference guide for building evaluation plans for AI agents. Based on Anthropic's evaluation methodology. 
> Last updated: 2026-01-16
> Source: https://docs.anthropic.com/en/docs/agents/evaluation/overview

---

## Core Concepts

| Term | Definition |
|------|------------|
| **Task** | Single test case with defined inputs and success criteria |
| **Trial** | One execution attempt of a task (run multiple per task) |
| **Grader** | Logic that scores agent performance |
| **Transcript** | Complete record of interactions, tool calls, reasoning |
| **Outcome** | Final environmental state after task completion |

---

## Evaluation Types

### Single-Turn
- One prompt → one response → grade
- Use for: isolated tool calls, simple queries

### Multi-Turn (Agent Evals)
- Multiple steps, state changes, environment interactions
- Use for: autonomous agents, complex workflows
- **Grade outcomes, not intermediate steps**

---

## Grader Selection

| Grader Type | Use When | Avoid When |
|-------------|----------|------------|
| **Code-based** | Deterministic outcomes, file outputs, test results | Open-ended responses, creative solutions |
| **Model-based** | Rubric scoring, natural language quality, flexibility needed | Strict correctness required, high-stakes decisions |
| **Human** | Gold-standard calibration, novel domains, ambiguous criteria | High volume, fast iteration needed |

### Code-Based Grader Patterns
```
- String/regex matching (exact outputs)
- File existence/content checks
- Test suite execution (pass/fail)
- Static analysis (lint, type check)
- State verification (DB records, API responses)
```

### Model-Based Grader Patterns
```
- Rubric scoring (1-5 scale with criteria)
- Binary assertions ("Does response contain X?")
- Comparative ranking (A vs B)
- Multi-aspect evaluation (accuracy, completeness, tone)
```

---

## Metrics

### pass@k
**Definition**: Probability of at least 1 success in k trials

**Use when**: One correct answer is sufficient
- Code generation (just need one working solution)
- Research tasks (finding any valid approach)

**Formula**: `1 - (1 - p)^k` where p = single-trial pass rate

### pass^k
**Definition**: Probability ALL k trials succeed

**Use when**: Consistency/reliability is critical
- Production deployments
- Safety-critical operations
- User-facing applications

**Formula**: `p^k` where p = single-trial pass rate

### Divergence Warning
At k=10 trials with p=0.5:
- pass@10 = 99.9%
- pass^10 = 0.1%

**Always report both metrics for agent evals.**

---

## Task Design Checklist

### Must Have
- [ ] Clear, unambiguous success criteria
- [ ] Domain expert would agree on pass/fail
- [ ] Isolated environment (no shared state between trials)
- [ ] Both positive cases (should do) AND negative cases (should NOT do)

### Must Avoid
- [ ] Grading specific tool sequences (grade outcomes only)
- [ ] Overly strict matching (e.g., "96.12" vs "96.124991")
- [ ] Tasks where success threshold ≠ grading threshold
- [ ] Shared state that leaks between trials

### Starting Point
- Begin with 20-50 tasks from **real failures**
- Don't wait for perfect dataset
- Iterate based on failure analysis

---

## Agent-Type Specific Approaches

### Coding Agents
```
Graders: Code-based (unit tests, static analysis)
Metrics: pass@k for generation, pass^k for reliability
Tasks: Real bug fixes, feature implementations
Watch for: Valid alternative solutions being marked wrong
```

### Conversational Agents
```
Graders: Model-based (rubrics) + code (outcome verification)
Metrics: Multi-aspect (accuracy, helpfulness, safety)
Tasks: Simulated user personas across multi-turn scenarios
Watch for: Interaction quality vs. final outcome tradeoffs
```

### Research Agents
```
Graders: Model-based with human calibration
Metrics: Groundedness (claims supported by sources), coverage
Tasks: Expert-validated reference answers
Watch for: Subjectivity—calibrate LLM judges against humans
```

### Computer Use Agents
```
Graders: Code-based (state verification)
Metrics: pass^k (reliability critical), token efficiency
Tasks: Real/sandboxed environments
Watch for: Screenshot-based vs DOM extraction tradeoffs
```

---

## Common Pitfalls

| Pitfall | Example | Fix |
|---------|---------|-----|
| Rigid grading | Failing "96.12" when answer is "96.124991" | Use tolerance ranges, normalize outputs |
| Threshold mismatch | Task says "optimize to X" but grader requires exceeding X | Align task wording with grader logic exactly |
| Shared state | Model exploits git history from previous trials | Isolate each trial in fresh environment |
| Prescriptive paths | Checking specific tool call sequence | Grade final outcome only |
| Creative solutions | Agent finds valid approach not in expected list | Review failures manually before assuming wrong |

---

## Eval-Driven Development Workflow

1. **Identify capability** to build
2. **Write eval tasks** before implementation
3. **Establish baseline** (expect 0% or low pass rate)
4. **Implement capability**
5. **Iterate** until eval passes
6. **Graduate** to regression suite
7. **Monitor** for saturation (100% = add harder tasks)

---

## Multi-Layer Validation (Swiss Cheese Model)

No single eval catches everything. Combine:

| Layer | Purpose |
|-------|---------|
| Automated evals | Fast iteration, regression detection |
| Production monitoring | Real user behavior signals |
| A/B testing | Statistical validation |
| User feedback | Unexpected failure discovery |
| Manual transcript review | Build intuition, find patterns |
| Human studies | Calibrate LLM judges |

---

## Quick Reference: Building an Eval Plan

```
1. DEFINE scope
   - What capability/behavior?
   - Single-turn or multi-turn?
   - What agent type?

2. SOURCE tasks
   - Start with real failures (20-50)
   - Include positive AND negative cases
   - Ensure unambiguous pass/fail criteria

3. SELECT graders
   - Deterministic outcomes → code-based
   - Open-ended quality → model-based
   - Calibrate model graders against human judgment

4. CHOOSE metrics
   - Need one success? → pass@k
   - Need reliability? → pass^k
   - Report both

5. ISOLATE trials
   - Fresh environment per trial
   - No shared state
   - Multiple trials per task (3-5 minimum)

6. VALIDATE
   - Review failed trials manually
   - Check for creative valid solutions
   - Verify grader matches task spec exactly

7. ITERATE
   - Add tasks from new failures
   - Monitor for eval saturation
   - Graduate stable evals to regression
```

---

## Source
Anthropic Engineering: [Demystifying Evals for AI Agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
