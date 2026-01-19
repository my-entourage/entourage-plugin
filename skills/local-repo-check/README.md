# local-repo-check Skill

Scans local Git repositories to verify implementation status of components/features.

## Overview

This skill checks local repositories for code evidence to determine if a component is actually implemented. It searches for:

1. **Source files** - Code matching the component name
2. **Test files** - Tests for the component
3. **Git history** - Commits and branches related to the component

## Status Levels

| Status | Evidence Required |
|--------|-------------------|
| Complete | Code + tests found on main branch |
| In Progress | Code found but no tests, or feature branch exists |
| Unknown | No code evidence found |

## When to Use

- Directly: `/local-repo-check authentication`
- Automatically invoked by `/project-status` when repos are configured

## Prerequisites

Repository configuration in `.entourage/repos.json`:

```json
{
  "repos": [
    {
      "name": "my-project",
      "path": "~/code/my-project",
      "mainBranch": "main"
    }
  ]
}
```

## Testing the Skill

### Running Evaluations

1. Navigate to your context database:
   ```bash
   cd ~/my-context   # or ~/other-context
   ```

2. Start Claude Code with the plugin:
   ```bash
   claude --plugin-dir ~/your-plugin
   ```

3. Test directly:
   ```
   /local-repo-check authentication
   /local-repo-check user-dashboard payments
   ```

### Example Test Queries

| Test Case | Query |
|-----------|-------|
| Single component | `/local-repo-check auth` |
| Multiple components | `/local-repo-check auth dashboard payments` |
| Non-existent component | `/local-repo-check nonexistent-feature` |

### Expected Output Format

```markdown
## Repository Scan: auth

| Repository | Evidence | Status | Confidence |
|------------|----------|--------|------------|
| my-project | Code + tests on main | Complete | High |

### Scan Details

**my-project:**
- File found: `src/auth/AuthProvider.tsx`
- Test found: `src/auth/__tests__/AuthProvider.test.tsx`
- Git status: On main branch, last commit 2 days ago
```

## Naming Convention Search

The skill searches for files using multiple naming conventions:
- Original: `UserAuth`
- snake_case: `user_auth`
- kebab-case: `user-auth`
- lowercase: `userauth`

## Error Handling

| Error | Behavior |
|-------|----------|
| Repository not found | Reports error, continues with other repos |
| Git command fails | Falls back to file existence checks |
| No repos configured | Returns "No repository configuration found" message |

## Evaluation Logs

This skill is typically invoked by `/project-status`. Evaluation logs are stored with project-status results:

```
~/my-context/evaluations/project-status/
~/other-context/evaluations/project-status/
```

## Test Cases

See `evaluations/evaluation.json` for the full test suite covering:
- File existence checks
- Test file detection
- Git history analysis
- Multiple naming conventions
- Error scenarios
