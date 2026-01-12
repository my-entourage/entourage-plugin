# project-status Skill

Reports implementation status of project components with evidence from transcripts, local repositories, and GitHub.

## Overview

This skill provides accurate project status by distinguishing between what was discussed versus what is actually implemented. It combines evidence from three sources:

1. **Transcripts** - Meeting notes, voice memos, messages
2. **Local repositories** - Code files, tests, git history
3. **GitHub** - PRs, issues, CI/CD status, deployments

## Status Levels

| Status | Definition | Evidence Required |
|--------|------------|-------------------|
| Discussed | Mentioned in meetings/messages | Transcript/message reference |
| Planned | Explicit decisions documented | Decision in transcript + rationale, or GitHub Issue |
| In Progress | Implementation started | Code in repo or open PR |
| Complete | Working implementation | Code + tests, or merged PR with CI passing |
| Shipped | Deployed to production | Deployment evidence from GitHub |
| Unknown | Insufficient evidence | N/A |

## Testing the Skill

### Prerequisites

1. A context database directory with:
   - `data/` folder containing transcripts
   - `.entourage/repos.json` (optional, for code verification)

2. Repository configuration (if testing code verification):
   ```json
   {
     "repos": [
       {
         "name": "my-project",
         "path": "~/code/my-project",
         "github": "org/my-project"
       }
     ]
   }
   ```

### Running Evaluations

1. Navigate to your context database:
   ```bash
   cd ~/entourage-context   # or ~/viran-context
   ```

2. Start Claude Code with the plugin:
   ```bash
   claude --plugin-dir ~/entourage-plugin
   ```

3. Test individual cases:
   - **No config**: Remove `.entourage/repos.json`, ask "What's the status of authentication?"
   - **Transcript only**: With transcripts but no repos.json, ask about a discussed feature
   - **Full verification**: With complete config, ask "Give me the project status"

### Example Test Queries

| Test Case | Query |
|-----------|-------|
| Single component | "What's the status of authentication?" |
| Multiple components | "Status of auth, dashboard, and payments" |
| Full project | "Give me the complete project status" |

### Expected Output Format

The skill outputs a markdown table with:
- Component name
- Status (Discussed/Planned/In Progress/Complete/Shipped/Unknown)
- Evidence description
- Source (Transcripts/Local/GitHub)
- Confidence level (Low/Medium/High/Very High)

Example:
```
## Status: My Project

| Component | Status | Evidence | Source | Confidence |
|-----------|--------|----------|--------|------------|
| Auth | Complete | PR #42 merged, CI passing | GitHub | Very High |
| Dashboard | In Progress | Code exists, no tests | Local | Medium |
| Analytics | Discussed | Mentioned Dec 21 meeting | Transcripts | High |
```

## Evaluation Logs

Test results are stored in the context database (not the plugin):

```
~/entourage-context/evaluations/project-status/
~/viran-context/evaluations/project-status/
```

Each evaluation run produces a timestamped JSON log with pass/fail results for each test case.

## Test Cases

See `evaluations/evaluation.json` for the full test suite covering:
- Configuration scenarios (no config, local only, GitHub only, both)
- All status levels (Discussed through Shipped)
- Edge cases (unknown components, conflicts between sources)
- Multi-component queries
