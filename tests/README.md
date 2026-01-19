# Evaluation Test Suite

This directory contains the evaluation infrastructure for your-plugin skills, following [Anthropic's agent evaluation methodology](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents).

## Quick Start

### Prerequisites

1. **Claude Code CLI** - Install and authenticate
   ```bash
   # Verify installation
   claude --version
   ```

2. **jq** - JSON processor
   ```bash
   # macOS
   brew install jq
   ```

3. **(Optional) coreutils** - For timeout support on macOS
   ```bash
   brew install coreutils
   ```

### Run Evaluations

```bash
# Run all skills (uses bundled fixtures)
./tests/run.sh

# Run specific skill
./tests/run.sh grounded-query

# Preview without executing
./tests/run.sh --dry-run

# Verbose output (shows inputs and grade details)
./tests/run.sh --verbose grounded-query

# Compare against golden outputs
./tests/run.sh --compare-golden grounded-query

# Multiple trials for pass@k metrics
TRIALS_PER_CASE=3 ./tests/run.sh grounded-query
```

### Validation Only (No API Required)

```bash
# Validate JSON structure and test case definitions
./tests/validate.sh
```

This runs in CI and doesn't require Claude API access.

---

## Test Infrastructure

### Two-Layer Testing

| Layer | Script | Purpose | API Required |
|-------|--------|---------|--------------|
| **Plumbing** | `validate.sh` | JSON syntax, required fields, unique IDs | No |
| **Evaluation** | `run.sh` | Skill execution, output grading | Yes |

### Directory Structure

```
tests/
├── run.sh              # Evaluation harness
├── validate.sh         # Structure validation
├── lib/
│   └── graders.sh      # Code-based grading functions
└── results/            # Output files (gitignored)

skills/[skill-name]/evaluations/
├── evaluation.json     # Test case definitions
├── golden/             # Reference outputs
└── fixtures/           # Test context data
    └── [case-id]/
        ├── .entourage/
        │   └── repos.json
        └── data/
            └── transcripts/
```

---

## Creating Custom Fixtures

Skills need context data to function. Fixtures provide isolated, reproducible test environments.

### Fixture Structure

Each fixture is a directory matching a test case ID:

```
skills/grounded-query/evaluations/fixtures/supported-claim/
└── data/
    └── transcripts/
        └── 2025-12-22-kickoff.md
```

The fixture contents are copied to a temporary working directory before the test runs.

### Example: grounded-query Fixture

For a test case expecting evidence about "Supabase":

```markdown
# Team Kickoff Meeting - December 22, 2025

## Database Decision

We decided to use Supabase as the primary database for the project.
```

### Example: local-repo-check Fixture

```
fixtures/complete-high-confidence/
├── .entourage/
│   └── repos.json
└── mock-repo/
    └── .git/
```

Where `repos.json` contains:
```json
{
  "repositories": [
    {
      "name": "mock-repo",
      "path": "./mock-repo",
      "components": ["auth"]
    }
  ]
}
```

---

## Test Case Format

Test cases in `evaluation.json`:

```json
{
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
        "contains": ["Supabase"],
        "hasSource": true
      }
    }
  ]
}
```

### Assertion Types

| Assertion | Description | Example |
|-----------|-------------|---------|
| `contains` | Output includes strings | `["Supabase", "database"]` |
| `notContains` | Output excludes strings | `["I think", "probably"]` |
| `status` | Status field matches | `"Complete"` or `["Complete", "Shipped"]` |
| `evidenceStatus` | Evidence classification | `"SUPPORTED"`, `"NOT_FOUND"` |
| `hasSource` | Output cites a source | `true` |
| `format` | Output format type | `"table"` |

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_CLI` | `claude` | Path to Claude CLI |
| `EVAL_TIMEOUT` | `60` | Timeout per test case (seconds) |
| `SKIP_CLAUDE` | `0` | Set to `1` to skip Claude execution |
| `TRIALS_PER_CASE` | `1` | Number of trials for pass@k |

---

## Running Linear Skill Evaluations

The `linear-check` and `linear-sync` skills require Linear API access for evaluation.

### Configure API Token

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your Linear credentials:
   ```
   LINEAR_API_TOKEN=lin_api_your_actual_token
   LINEAR_TEAM_ID=TEAM        # Your team key (e.g., "ENG", "PROD")
   LINEAR_WORKSPACE=my-workspace  # From your Linear URL
   ```

3. Generate a token at: https://linear.app/settings/api

### Run Evaluations

```bash
# Run linear-check evaluations
./tests/run.sh linear-check

# Run linear-sync evaluations
./tests/run.sh linear-sync

# Both skills with verbose output
./tests/run.sh linear-check linear-sync --verbose
```

The test runner automatically injects tokens from `.env` into test fixtures.

### Why API Token Instead of MCP?

MCP requires interactive OAuth approval which cannot happen in automated test subprocesses. The API token fallback enables automated testing while MCP remains the recommended approach for interactive use.

---

## Troubleshooting

### "Claude CLI not found"

Ensure Claude Code is installed and in your PATH:
```bash
which claude
```

Or specify the path:
```bash
CLAUDE_CLI=/path/to/claude ./tests/run.sh
```

### "timeout: command not found" (macOS)

Install coreutils:
```bash
brew install coreutils
```

Or run without timeout (tests won't be time-limited):
```bash
./tests/run.sh  # Works but won't timeout hung tests
```

### Tests fail with "no evidence found"

The skill needs fixture data. Check that:
1. Fixture exists: `skills/[skill]/evaluations/fixtures/[case-id]/`
2. Fixture contains expected data matching `setup.description`

### View detailed results

```bash
# See what Claude returned
cat tests/results/[skill]_[case-id].txt

# See which assertions failed
cat tests/results/[skill]_[case-id].grade
```

---

## Contributing

When adding test cases:

1. Add case to `evaluation.json` with clear `setup.description`
2. Create fixture in `fixtures/[case-id]/` if context is needed
3. Run evaluation to verify: `./tests/run.sh --verbose [skill]`
4. Optionally add golden output to `golden/[case-id].md`

See [Anthropic's eval methodology](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) for best practices on test case design.
