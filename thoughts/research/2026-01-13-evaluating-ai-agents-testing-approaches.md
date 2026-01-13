# Evaluating AI Agents: From Legacy Testing Patterns to Modern LLM Evals

**Date:** January 13, 2026
**Author:** Jared Sisk
**Context:** Research notes for developer presentation on AI agent evaluation strategies

---

## Executive Summary

Anthropic's recent engineering blog post ["Demystifying Evals for AI Agents"](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) has sparked renewed interest in how to systematically test AI systems. This document examines the testing approaches recommended by Anthropic, traces their origins in traditional software testing, and explores how they apply to real-world AI agent development.

**Key insight:** The "new" techniques for evaluating AI agents aren't new at all—they're adaptations of proven software testing patterns, reimagined for non-deterministic systems.

---

## The Challenge: Why AI Agents Are Hard to Test

Traditional software testing relies on determinism: given input X, expect output Y. AI agents break this assumption in several ways:

| Traditional Software | AI Agents |
|---------------------|-----------|
| Deterministic outputs | Variable responses to same input |
| Binary pass/fail | Spectrum of acceptable answers |
| Unit-testable functions | Multi-turn, stateful interactions |
| Isolated components | Tool calls that modify external state |

As Anthropic notes:

> "Agents use tools across many turns, modifying state in the environment and adapting as they go—which means mistakes can propagate and compound."

This creates a testing paradox: we need rigorous verification, but traditional assertion-based testing doesn't fit.

---

## Anthropic's Three-Layer Grading Strategy

Anthropic recommends a layered approach to grading AI outputs:

### Layer 1: Code-Based Graders (Fastest, Cheapest)

Programmatic checks that verify specific properties:

```python
# Example assertions
assert "Supabase" in output          # Contains expected content
assert "I think" not in output        # Avoids hedging language
assert output.count("|") >= 6         # Has table structure
```

**When to use:** Objective, rule-based criteria. Fast feedback in CI/CD.

**Limitation:** Can't assess subjective quality like "is this response helpful?"

### Layer 2: LLM-Based Graders (Flexible, Scalable)

Use a separate AI model to evaluate outputs:

```
Prompt: "Rate this response's accuracy on a scale of 1-5.
         Consider: factual correctness, completeness, source attribution."
```

**When to use:** Subjective assessments, nuanced correctness, tone/style evaluation.

**Limitation:** Adds cost and latency. Requires calibration against human judgment.

### Layer 3: Human Graders (Gold Standard)

Manual review by domain experts.

**When to use:** Initial calibration, edge cases, high-stakes decisions.

**Limitation:** Doesn't scale. Expensive. Slow.

### The Recommended Balance

Anthropic suggests:
1. Start with **code-based graders** for clear-cut criteria
2. Add **LLM-based graders** for quality dimensions
3. Use **human review** to calibrate and validate the automated graders

---

## Historical Context: These Patterns Aren't New

The AI evaluation community has largely reinvented techniques that software engineers have used for decades. Understanding this lineage helps us apply these patterns more effectively.

### Golden Master Testing (2004)

**Origin:** Michael Feathers coined "Characterization Tests" in *[Working Effectively with Legacy Code](https://books.google.com/books/about/Working_Effectively_with_Legacy_Code.html?id=CQlRAAAAMAAJ)* (2004).

> "A characterization test is a test that characterizes the actual behavior of a piece of code."

The idea: capture what code *actually does*, then detect unintended changes during refactoring.

**In AI context:** "Golden datasets" serve the same purpose—reference outputs that define what "correct" looks like.

| Traditional Name | AI/LLM Name |
|-----------------|-------------|
| Golden Master Testing | Golden Dataset Evaluation |
| Characterization Tests | Baseline Comparison |
| Snapshot Testing | Output Regression Testing |
| Approval Testing | Human-in-the-loop Validation |

### The Terminology Evolution

| Year | Development |
|------|-------------|
| Pre-2000 | "Golden Master" used in manufacturing (the prototype all copies compare against) |
| 2004 | Michael Feathers formalizes "Characterization Tests" |
| 2010s | Frontend popularizes "Snapshot Testing" (Jest, Flutter) |
| 2023-2025 | AI community adopts "Golden Datasets" for LLM evaluation |
| 2025 | Anthropic publishes comprehensive eval guidance |

### Why LLMs Require Adaptation

Traditional golden master testing uses **exact comparison**. LLM outputs are non-deterministic, so we need:

1. **Fuzzy matching** (semantic similarity instead of string equality)
2. **Property-based assertions** (check characteristics, not exact content)
3. **Statistical evaluation** (pass@k metrics, confidence intervals)

---

## Assertion-Based vs Reference-Based Testing

Two complementary approaches emerge from this analysis:

### Assertion-Based (evaluation.json criteria)

Define properties the output must satisfy:

```json
{
  "expectedOutput": {
    "contains": ["Supabase", "database"],
    "notContains": ["I think", "probably"],
    "evidenceStatus": "SUPPORTED",
    "format": "table"
  }
}
```

**Characteristics:**
- Flexible—output can vary as long as criteria are met
- Easy to maintain—adding features means adding assertions
- Tests **behavior** ("does it cite sources?")

### Reference-Based (Golden Comparisons)

Compare entire output against a known-good example:

```markdown
<!-- golden/supported-claim.md -->
Based on the meeting transcripts, the team chose **Supabase**...

| Claim | Status | Source |
|-------|--------|--------|
| Team chose Supabase | SUPPORTED | 2025-12-22-kickoff.md |
```

**Characteristics:**
- Holistic—catches formatting, tone, structural changes
- Brittle—any change (even improvements) triggers failure
- Tests **regression** ("did something change unexpectedly?")

### When to Use Each

| Approach | Best For |
|----------|----------|
| Assertions | CI/CD gates, defining requirements, allowing flexibility |
| Golden | Regression detection, preserving approved outputs, style consistency |

**Recommendation:** Use assertions as primary verification, golden comparisons as secondary regression detection.

---

## Case Study: entourage-plugin

The [entourage-plugin](https://github.com/my-entourage/entourage-plugin) project provides a practical example of implementing these evaluation patterns for a Claude Code plugin.

### Project Context

A Claude Code marketplace plugin with 4 skills:
- **grounded-query** — Verify claims against source documents
- **project-status** — Report implementation status with evidence
- **local-repo-check** — Scan local git repositories
- **github-repo-check** — Query GitHub API for project activity

### Evaluation Infrastructure Implemented

```
entourage-plugin/
├── skills/
│   └── [skill-name]/
│       └── evaluations/
│           ├── evaluation.json      # Assertion-based test cases
│           └── golden/              # Reference outputs
├── tests/
│   ├── validate.sh                  # CI validation (no API needed)
│   ├── run.sh                       # Full eval runner
│   └── lib/
│       └── graders.sh               # Output checking helpers
└── .github/
    └── workflows/
        └── evals.yml                # CI pipeline
```

### Evaluation Schema Design

Each skill defines test cases with layered assertions:

```json
{
  "name": "grounded-query",
  "testCases": [
    {
      "id": "supported-claim",
      "name": "Direct evidence found",
      "input": "What database did the team choose?",
      "setup": {
        "description": "Transcript contains: 'We decided to use Supabase'"
      },
      "expectedOutput": {
        "evidenceStatus": "SUPPORTED",
        "contains": ["Supabase", "database"],
        "hasSource": true
      }
    },
    {
      "id": "status-inflation-prevention",
      "name": "Prevents status inflation",
      "input": "Is authentication complete?",
      "setup": {
        "description": "Transcript says 'we'll implement Clerk' but no code"
      },
      "expectedOutput": {
        "notContains": ["Complete", "Done", "Finished"],
        "contains": ["discussed", "planned"]
      }
    }
  ]
}
```

### Key Design Decisions

1. **JSON over YAML** — No additional dependencies, native parsing everywhere
2. **Co-located evaluations** — Test cases live alongside skills they test
3. **Separation of validation and execution** — CI runs structure checks; full evals require API access
4. **Layered grading** — Code-based assertions first, golden comparison optional

### Test Coverage

| Skill | Test Cases | Focus Areas |
|-------|-----------|-------------|
| grounded-query | 11 | Hallucination prevention, evidence verification |
| github-repo-check | 18 | API error handling, status inference |
| project-status | 15 | Multi-source synthesis, conflict resolution |
| local-repo-check | 10 | File pattern matching, git integration |

**Total: 54 test cases** across 4 skills, all validatable in CI without API costs.

---

## Practical Recommendations

Based on Anthropic's guidance and real-world implementation:

### 1. Start with Code-Based Graders

Define clear, unambiguous assertions:

```python
# Good - objective, verifiable
"contains": ["error code 401", "authentication"]

# Bad - subjective, ambiguous
"contains": ["good explanation"]
```

Anthropic's heuristic: *"A good task is one where two domain experts would independently reach the same pass/fail verdict."*

### 2. Separate Validation from Execution

- **CI runs structural validation** — JSON syntax, required fields, no duplicates
- **Local/manual runs execute against Claude** — Requires API access, generates results

This lets contributors verify their changes without API keys.

### 3. Design for Non-Determinism

Accept that the same input may produce different (but equally valid) outputs:

```json
{
  "status": ["Complete", "Shipped"],  // Either is acceptable
  "confidence": ["High", "Very High"]
}
```

### 4. Use Golden Comparisons Sparingly

Reserve for:
- Critical paths (hallucination prevention)
- Regression detection after major changes
- Style/formatting consistency

Avoid for:
- Exploratory features still evolving
- Cases where output flexibility is desired

### 5. Prioritize Adversarial Cases

Anthropic emphasizes testing failure modes:

> "When a novel failure mode is discovered, it is analyzed, a correction is applied, and a new test case is codified into the golden dataset."

The entourage-plugin includes explicit adversarial cases:
- `status-inflation-prevention` — Ensures discussion ≠ completion
- `hallucination-prevention` — Verifies "NOT FOUND" when no evidence exists
- `no-data-files` — Tests graceful degradation

---

## Emerging Tools and Frameworks

Several tools have emerged to support AI evaluation:

| Tool | Approach | Best For |
|------|----------|----------|
| [DeepEval](https://deepeval.com/) | Python framework with metrics | Programmatic evaluation in code |
| [Promptfoo](https://promptfoo.dev/) | YAML-based test definitions | CI/CD integration, prompt comparison |
| [Braintrust](https://braintrust.dev/) | Platform with logging + evals | Production monitoring, A/B testing |
| [LangSmith](https://smith.langchain.com/) | LangChain ecosystem | Tracing + evaluation for chains |
| [Confident AI](https://confident-ai.com/) | Golden dataset management | Dataset curation, LLM-as-judge |

For lightweight needs (like entourage-plugin), shell scripts with `jq` provide sufficient infrastructure without adding dependencies.

---

## Conclusion

The core insight from examining Anthropic's evaluation guidance alongside traditional testing patterns:

**AI agent evaluation isn't a new discipline—it's software testing adapted for non-determinism.**

The techniques that work:
1. **Assertion-based verification** (adapted from unit testing)
2. **Golden master comparison** (adapted from characterization tests)
3. **Layered grading strategies** (code → LLM → human)
4. **Adversarial test cases** (adapted from security testing)

What's genuinely new is the need to embrace variability. Traditional tests fail on any deviation; AI evals must distinguish between *acceptable variation* and *actual regression*.

The entourage-plugin demonstrates that meaningful evaluation infrastructure can be built with minimal dependencies, following patterns proven over decades of software engineering practice.

---

## References

### Primary Sources

- [Demystifying Evals for AI Agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) — Anthropic Engineering Blog (2025)
- [Working Effectively with Legacy Code](https://books.google.com/books/about/Working_Effectively_with_Legacy_Code.html?id=CQlRAAAAMAAJ) — Michael Feathers (2004)
- [Characterization Test - Wikipedia](https://en.wikipedia.org/wiki/Characterization_test)

### LLM Evaluation Resources

- [Test Cases, Goldens, and Datasets](https://www.confident-ai.com/docs/llm-evaluation/core-concepts/test-cases-goldens-datasets) — Confident AI
- [Testing for LLM Applications](https://langfuse.com/blog/2025-10-21-testing-llm-applications) — Langfuse
- [LLM Regression Testing Tutorial](https://www.evidentlyai.com/blog/llm-regression-testing-tutorial) — Evidently AI
- [Golden Datasets for GenAI Testing](https://www.techment.com/blogs/golden-datasets-for-genai-testing/) — Techment

### Traditional Testing Background

- [Testing Legacy Code with Golden Master](https://www.codurance.com/publications/2012/11/11/testing-legacy-code-with-golden-master) — Codurance (2012)
- [Golden Files - Why You Should Use Them](https://medium.com/@jarifibrahim/golden-files-why-you-should-use-them-47087ec994bf) — Medium
- [What is the Golden Master Technique](https://stevenschwenke.de/whatIsTheGoldenMasterTechnique) — Steven Schwenke

### Case Study

- [entourage-plugin](https://github.com/my-entourage/entourage-plugin) — Claude Code marketplace plugin with evaluation infrastructure

---

## Appendix: Quick Reference

### Assertion Types Supported in entourage-plugin

| Assertion | Purpose | Example |
|-----------|---------|---------|
| `contains` | Output includes strings | `["Supabase", "database"]` |
| `notContains` | Output excludes strings | `["I think", "probably"]` |
| `status` | Status field matches | `"Complete"` or `["Complete", "Shipped"]` |
| `confidence` | Confidence level matches | `"High"` |
| `evidenceStatus` | Evidence verification result | `"SUPPORTED"` |
| `hasSource` | Output cites a source | `true` |
| `format` | Output format type | `"table"` |
| `tableHeaders` | Table has specific columns | `["Claim", "Status", "Source"]` |

### Running Evaluations

```bash
# Validate structure (CI-safe, no API)
./tests/validate.sh

# Run all evals (requires Claude CLI)
./tests/run.sh

# Run single skill
./tests/run.sh grounded-query

# Compare against golden outputs
./tests/run.sh --compare-golden grounded-query

# Preview without executing
./tests/run.sh --dry-run
```

---

## Addendum: Implementation Plan Analysis (2026-01-13)

### Key Findings from run.sh Analysis

The current evaluation harness (`tests/run.sh`) has the **correct architecture** but **broken implementation**:

| Issue | Root Cause | Impact |
|-------|------------|--------|
| macOS incompatibility | Uses GNU `timeout` command | 100% failure on macOS |
| Wrong invocation | `claude --print "$input"` | Skills never loaded |
| No plugin loading | Missing `--plugin-dir` | Skills unavailable |
| Missing context | No fixture data | Skills can't access required files |

The 8.33% pass rate (1/11) reflects infrastructure failure, not skill quality.

### Two-Layer Testing Strategy

**Layer 1: Plumbing Tests (validate.sh)**
- JSON schema validation
- Required fields check
- Unique ID verification
- Status value validation
- **Runs in CI without API access**

**Layer 2: LLM Output Evaluation (run.sh)**
- Skill invocation with proper context
- Output grading against assertions
- Transcript capture
- pass@k metrics
- **Requires Claude CLI and API access**

### Two-Phase Implementation

| Phase | Focus | Grading | Success Criteria |
|-------|-------|---------|------------------|
| **Phase 1** | Fix evaluation harness | Code-based only | >80% pass rate |
| **Phase 2** | Add semantic evaluation | LLM-as-judge | Rubric scoring, groundedness |

**Architecture Note:** Phase 1 design supports Phase 2 without modification. Extensions are additive:
- `evaluation.json` → add `rubric` field
- `run.sh` → add `--llm-grade` flag
- New `llm-grader.sh` → alongside existing `graders.sh`

### Critical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Fixture data | Minimal per test case | Just enough to satisfy skill |
| CI execution | Defer to Phase 2 | Focus on local harness first |
| Transcript format | Claude Code native | Compatibility |
| Phase 2 trigger | >80% pass + user approval | Validate Phase 1 before complexity |

### Reference

Full implementation plan: `/Users/jaredsisk/.claude/plans/glistening-dancing-sprout.md`
