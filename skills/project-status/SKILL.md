---
name: project-status
description: Reports implementation status of project components with evidence. Use when asked about what's done, in progress, or planned for a project.
---

## Purpose

Provide accurate project status by distinguishing between what was discussed versus what is actually implemented.

## When to Use

Apply when user asks:
- "What's the status of X?"
- "Is Y complete?"
- "What has been implemented?"
- "Show me project progress"

## Status Levels

| Status | Definition | Evidence Required |
|--------|------------|-------------------|
| `Discussed` | Mentioned in meetings/messages | Transcript/message reference |
| `Planned` | Explicit decisions documented | Decision in transcript + rationale |
| `In Progress` | Implementation started | Code in repo (requires repo config) |
| `Complete` | Working implementation | Code + tests passing (requires repo) |
| `Unknown` | Insufficient evidence | N/A |

## Workflow

1. Identify components/features in query
2. Check for repository configuration (see below)
3. Search data files for mentions of each component
4. If repos configured, scan for code evidence
5. Classify evidence type and determine status
6. Output status table with sources

---

## Repository Configuration

Before checking implementation status, look for repository configuration:

### Step 1: Check for Config File

Use the Read tool to check if `.entourage/repos.json` exists in the current working directory.

### Step 2: Parse Configuration

If the file exists, it contains a `repos` array. Each repo has:
- `name`: Human-readable identifier
- `path`: Local filesystem path (may contain `~`)
- `mainBranch`: Branch name for "shipped" status (default: "main")

Example config:
```json
{
  "repos": [
    {
      "name": "entourage-web",
      "path": "~/Documents/code/entourage-web",
      "mainBranch": "main"
    }
  ]
}
```

### Step 3: Expand Paths

Replace `~` with the user's home directory using Bash:
```bash
echo ~/path/to/repo
```

### Step 4: Verify Access

For each repo, confirm the path exists:
```bash
test -d "/expanded/path" && echo "exists" || echo "missing"
```

---

## Local Repository Scanning

For each component/feature being queried, perform these checks against each configured repository:

### 1. File Existence Check

Use Glob to find files matching the component name (try multiple patterns):
```
**/*ComponentName*
**/*component_name*
**/*component-name*
```

### 2. Test File Detection

Search for test files:
```
**/*ComponentName*.test.*
**/*ComponentName*.spec.*
**/test*/*ComponentName*
**/__tests__/*ComponentName*
```

### 3. Git History Analysis

Check recent commits mentioning the component:
```bash
cd /path/to/repo && git log --oneline --all --since="3 months ago" --grep="ComponentName" | head -20
```

Check for feature branches:
```bash
cd /path/to/repo && git branch -a | grep -i "component"
```

Check if component code is on main branch:
```bash
cd /path/to/repo && git log main --oneline -- "**/ComponentName*" | head -5
```

### 4. Migration/Schema Detection (for database components)

Look for migration files:
```
**/migrations/*component*
**/db/*component*
```

---

## Evidence Synthesis

Apply this decision tree to determine component status:

```
1. Code + tests found + on main branch?
   YES -> Status: Complete (High confidence)

2. Code + tests found (any branch)?
   YES -> Status: Complete (Medium confidence)

3. Code found but no tests?
   YES -> Status: In Progress (Medium confidence)

4. Feature branch exists with commits?
   YES -> Status: In Progress (Low confidence)

5. Discussed in meeting transcripts?
   YES -> Status: Discussed (High confidence)

6. No evidence found?
   -> Status: Unknown
```

---

## Error Handling

### Repository Not Found
If a configured repo path doesn't exist:
- Report in output: "Repository 'name' not accessible at path"
- Continue with other repos
- Don't fail the entire status check

### Git Command Failures
If git commands fail (not a git repo, permissions):
- Report: "Could not access git history for 'name'"
- Fall back to file existence checks only

### Path Expansion Failures
If `~` expansion fails:
- Try `$HOME/rest/of/path` as fallback
- Report: "Could not expand path for 'name'"

## Output Format

```
## Status: [Project Name]

| Component | Status | Evidence | Source | Confidence |
|-----------|--------|----------|--------|------------|
| [Name] | Discussed/Planned/etc | [Brief description] | [Repo name or "Transcripts"] | High/Med/Low |

### Notes
- [Any caveats about verification limitations]
```

## Critical Rule

**Never mark a component as "Complete" or "In Progress" based solely on meeting transcripts.**

Meeting transcripts can only support `Discussed` or `Planned` status. Higher statuses require code evidence from repositories.

If repos are not configured, add this note:
> Repository verification not configured. Maximum verifiable status is "Planned". Add repos to `.entourage/repos.json` for implementation status.

## Evidence Hierarchy

When determining status, use this hierarchy (strongest to weakest evidence):

| Evidence Type | Max Status Level |
|--------------|------------------|
| Meeting discussion only | Discussed |
| Architecture decisions documented | Planned |
| Code exists (no tests) | In Progress |
| Code + passing tests | Complete |
| Merged to main + deployed | Shipped |

## Example Output

### With Repository Verification

**Query:** "What's the status of authentication?"

```
## Status: Entourage

| Component | Status | Evidence | Source | Confidence |
|-----------|--------|----------|--------|------------|
| Clerk auth | Complete | Tests passing, merged to main | entourage-web | High |
| User dashboard | In Progress | Code exists, no tests | entourage-web | Medium |
| Email notifications | Discussed | Mentioned Dec 21 meeting | Transcripts | High |

### Evidence Details

**Clerk auth (Complete)**
- File: `src/auth/ClerkProvider.tsx` found
- Tests: `src/auth/__tests__/ClerkProvider.test.tsx` - exists
- Git: On main branch, last commit 2 days ago
```

### Without Repository Configuration

**Query:** "What's the status of the database?"

```
## Status: Entourage

| Component | Status | Evidence | Source | Confidence |
|-----------|--------|----------|--------|------------|
| Database schema | Planned | Architecture decided Dec 22 | Transcripts | Medium |
| Clerk auth | Discussed | Mentioned Dec 21 | Transcripts | Low |
| API endpoints | Unknown | No mentions found | - | Low |

### Notes
- Repository verification not configured. Maximum verifiable status is "Planned". Add repos to `.entourage/repos.json` for implementation status.
- "Complete" and "In Progress" require code evidence from repositories.
```
