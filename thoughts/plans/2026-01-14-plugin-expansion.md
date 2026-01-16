# Plugin Expansion Implementation Plan

## Overview

Expand entourage-plugin from a verification-focused plugin to a comprehensive data management toolkit by adding:
1. Session tracking hooks (from claude-logger)
2. `import-hyprnote` skill (from sort-hyprnote command)
3. `update-timeline` skill (from viran-context)
4. `import-notion` skill (from notion-exporter scripts) - **last, still being updated**

Plus: Unified configuration system with enable/disable controls and project discovery.

## Current State Analysis

### Existing Plugin Structure
```
entourage-plugin/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   ├── grounded-query/
│   ├── project-status/
│   ├── local-repo-check/
│   └── github-repo-check/
├── commands/
│   └── hello.md
├── tests/
└── thoughts/
```

### Source Projects to Migrate

| Source | Location | Type |
|--------|----------|------|
| claude-logger | `/Users/ia/Documents/code/@orgs/my-entourage/claude-logger` | Hooks + scripts |
| sort-hyprnote | `/Users/ia/.claude/commands/sort-hyprnote.md` | Single command file |
| update-timeline | `/Users/ia/Documents/code/@orgs/viranhq/viran-context/.claude/skills/update-timeline/` | Skill directory |
| notion-exporter | `/Users/ia/.claude/scripts/notion-exporter/` | Python scripts |

### Key Discoveries

- Plugin hooks can write to `${CLAUDE_PROJECT_DIR}` - session logging works as plugin
- Skills support multiple files per directory (SKILL.md + supporting .md files)
- Current plugin uses `.entourage/repos.json` for repository config
- Notion-exporter is still being updated - migrate last

## Desired End State

After this plan is complete:

```
entourage-plugin/
├── .claude-plugin/
│   ├── plugin.json          # Updated with hooks path
│   └── marketplace.json     # Single plugin (monorepo)
├── hooks/
│   └── hooks.json           # SessionStart, SessionEnd
├── scripts/
│   ├── session-start.sh
│   └── session-end.sh
├── skills/
│   ├── grounded-query/      # Existing
│   ├── project-status/      # Existing
│   ├── local-repo-check/    # Existing
│   ├── github-repo-check/   # Existing
│   ├── import-hyprnote/     # NEW
│   │   └── SKILL.md
│   ├── update-timeline/     # NEW
│   │   ├── SKILL.md
│   │   ├── processing-rules.md
│   │   ├── source-formats.md
│   │   ├── output-template.md
│   │   └── sources/
│   │       └── _registry.json
│   └── import-notion/       # NEW (last)
│       ├── SKILL.md
│       ├── scripts/
│       │   ├── exporter.py
│       │   ├── converter.py
│       │   └── requirements.txt
│       └── README.md
├── commands/
│   └── hello.md
└── examples/
    └── config.json.example  # NEW
```

### Verification

1. `/import-hyprnote` successfully sorts transcripts to context repos
2. `/update-timeline` processes multiple source types and flags unknown formats
3. Session logging works when plugin is installed (controllable via config)
4. `/import-notion` exports and converts Notion pages (after migration)

## What We're NOT Doing

- **NOT** creating a separate plugin for claude-logger (monorepo instead)
- **NOT** implementing bidirectional Notion sync (future `export-notion`)
- **NOT** adding new data source parsers beyond current 4 (Hyprnote, Notion, WhatsApp, Hailer)
- **NOT** changing existing skills (grounded-query, project-status, etc.)
- **NOT** migrating notion-exporter until it's stable (Phase 6)

## Implementation Approach

1. Build infrastructure first (hooks, config schema)
2. Migrate simplest component (hooks)
3. Build import-hyprnote with project discovery
4. Migrate update-timeline with source registry
5. Checkpoint: verify notion-exporter is ready
6. Migrate import-notion last

---

## Phase 1: Infrastructure Setup

### Overview

Create the directory structure, configuration schema, and hooks infrastructure needed for all subsequent phases.

### Changes Required

#### 1. Create hooks directory structure

**Create**: `hooks/hooks.json`
```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [{
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/session-start.sh"
        }]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [{
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/session-end.sh"
        }]
      }
    ]
  }
}
```

#### 2. Create scripts directory (placeholder)

**Create**: `scripts/.gitkeep`

#### 3. Create configuration example

**Create**: `examples/config.json.example`
```json
{
  "sessionLogging": true,
  "projects": [
    {
      "name": "example-context",
      "path": "~/Documents/code/example-context",
      "description": "Example project for demonstration",
      "keywords": ["example", "demo", "test"]
    }
  ]
}
```

#### 4. Update plugin.json

**File**: `.claude-plugin/plugin.json`
**Changes**: Add hooks path

```json
{
  "name": "entourage",
  "version": "1.1.0",
  "description": "Skills for grounded queries, project status, data import, and session tracking",
  "author": {
    "name": "My Entourage",
    "email": "blaze46593@gmail.com"
  },
  "repository": "https://github.com/my-entourage/entourage-plugin",
  "hooks": "./hooks/hooks.json"
}
```

#### 5. Update marketplace.json (remove claude-logger reference if any)

**File**: `.claude-plugin/marketplace.json`
**Changes**: Ensure single plugin, update description

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "entourage-marketplace",
  "version": "1.1.0",
  "description": "Comprehensive toolkit for context management, verification, and session tracking",
  "owner": {
    "name": "My Entourage",
    "email": "blaze46593@gmail.com",
    "url": "https://github.com/my-entourage/entourage-plugin"
  },
  "plugins": [
    {
      "name": "entourage",
      "description": "Skills for grounded queries, project status, data import, and session tracking",
      "version": "1.1.0",
      "source": { "source": "github", "repo": "my-entourage/entourage-plugin" },
      "category": "productivity",
      "tags": ["project-status", "grounded-query", "import", "timeline", "session-tracking"]
    }
  ]
}
```

### Success Criteria

#### Automated Verification:
- [ ] `hooks/hooks.json` exists and is valid JSON
- [ ] `examples/config.json.example` exists and is valid JSON
- [ ] `.claude-plugin/plugin.json` has `"hooks"` field
- [ ] Plugin validates: `claude plugin validate .`

#### Manual Verification:
- [ ] Directory structure matches expected layout

---

## Phase 2: Session Tracking Hooks

### Overview

Migrate claude-logger hooks to the plugin. These hooks capture session state at start/end for meta-optimization analysis.

### Changes Required

#### 1. Create session-start.sh

**Create**: `scripts/session-start.sh`

Migrate from `/Users/ia/Documents/code/@orgs/my-entourage/claude-logger/hooks/session_start.sh` with these modifications:
- Update header comment to: `# Session tracking hook - part of entourage plugin`
- Add config check for `sessionLogging` disable
- Use `${CLAUDE_PROJECT_DIR}` instead of hardcoded paths

```bash
#!/bin/bash
# Session tracking hook - part of entourage plugin
# https://github.com/my-entourage/entourage-plugin

set -e

# Check if logging is disabled via environment variable
if [ "$CLAUDE_LOGGER_DISABLED" = "1" ]; then
    exit 0
fi

# Check if logging is disabled via config file
CONFIG_FILE="${CLAUDE_PROJECT_DIR}/.entourage/config.json"
if [ -f "$CONFIG_FILE" ]; then
    SESSION_LOGGING=$(cat "$CONFIG_FILE" | grep -o '"sessionLogging"[[:space:]]*:[[:space:]]*\(true\|false\)' | grep -o '\(true\|false\)' || echo "true")
    if [ "$SESSION_LOGGING" = "false" ]; then
        exit 0
    fi
fi

# Check for required GITHUB_NICKNAME
if [ -z "$GITHUB_NICKNAME" ]; then
    exit 0
fi

# Read hook input from stdin
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [ -z "$SESSION_ID" ]; then
    exit 0
fi

# Create sessions directory
SESSIONS_DIR="${CLAUDE_PROJECT_DIR}/.claude/sessions/${GITHUB_NICKNAME}"
mkdir -p "$SESSIONS_DIR"

SESSION_FILE="${SESSIONS_DIR}/${SESSION_ID}.json"

# Capture initial state
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null || echo "")
GIT_COMMIT=$(git -C "$CLAUDE_PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo "")

# Read CLAUDE.md if exists
CLAUDE_MD=""
if [ -f "${CLAUDE_PROJECT_DIR}/CLAUDE.md" ]; then
    CLAUDE_MD=$(cat "${CLAUDE_PROJECT_DIR}/CLAUDE.md" | head -100 | jq -Rs .)
fi

# Create session JSON
cat > "$SESSION_FILE" << EOF
{
  "session_id": "$SESSION_ID",
  "nickname": "$GITHUB_NICKNAME",
  "started_at": "$TIMESTAMP",
  "project_dir": "$CLAUDE_PROJECT_DIR",
  "git": {
    "branch": "$GIT_BRANCH",
    "commit": "$GIT_COMMIT"
  },
  "claude_md_preview": $CLAUDE_MD,
  "hook_input": $INPUT
}
EOF

exit 0
```

#### 2. Create session-end.sh

**Create**: `scripts/session-end.sh`

```bash
#!/bin/bash
# Session tracking hook - part of entourage plugin
# https://github.com/my-entourage/entourage-plugin

set -e

# Check if logging is disabled
if [ "$CLAUDE_LOGGER_DISABLED" = "1" ]; then
    exit 0
fi

CONFIG_FILE="${CLAUDE_PROJECT_DIR}/.entourage/config.json"
if [ -f "$CONFIG_FILE" ]; then
    SESSION_LOGGING=$(cat "$CONFIG_FILE" | grep -o '"sessionLogging"[[:space:]]*:[[:space:]]*\(true\|false\)' | grep -o '\(true\|false\)' || echo "true")
    if [ "$SESSION_LOGGING" = "false" ]; then
        exit 0
    fi
fi

if [ -z "$GITHUB_NICKNAME" ]; then
    exit 0
fi

# Read hook input
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

if [ -z "$SESSION_ID" ]; then
    exit 0
fi

SESSIONS_DIR="${CLAUDE_PROJECT_DIR}/.claude/sessions/${GITHUB_NICKNAME}"
SESSION_FILE="${SESSIONS_DIR}/${SESSION_ID}.json"

if [ ! -f "$SESSION_FILE" ]; then
    exit 0
fi

# Update session with end time
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TEMP_FILE=$(mktemp)

jq --arg ended_at "$TIMESTAMP" \
   --arg transcript_path "$TRANSCRIPT_PATH" \
   '. + {ended_at: $ended_at, transcript_path: $transcript_path}' \
   "$SESSION_FILE" > "$TEMP_FILE"

mv "$TEMP_FILE" "$SESSION_FILE"

# Copy transcript if path provided and exists
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    cp "$TRANSCRIPT_PATH" "${SESSIONS_DIR}/${SESSION_ID}.transcript.jsonl"
fi

exit 0
```

#### 3. Make scripts executable

```bash
chmod +x scripts/session-start.sh scripts/session-end.sh
```

### Success Criteria

#### Automated Verification:
- [ ] `scripts/session-start.sh` exists and is executable
- [ ] `scripts/session-end.sh` exists and is executable
- [ ] Scripts pass shellcheck: `shellcheck scripts/*.sh`
- [ ] Scripts have correct header comment (not "DO NOT MODIFY")

#### Manual Verification:
- [ ] Start a Claude Code session in a test project with plugin installed
- [ ] Verify `.claude/sessions/{nickname}/{session_id}.json` is created
- [ ] End the session and verify `ended_at` is added
- [ ] Test with `CLAUDE_LOGGER_DISABLED=1` - no session file created
- [ ] Test with `.entourage/config.json` `sessionLogging: false` - no session file created

### Implementation Note:
After completing this phase and all automated verification passes, pause here for manual confirmation that session tracking works correctly.

---

## Phase 3: import-hyprnote Skill

### Overview

Convert the sort-hyprnote command to a skill that imports Hyprnote transcripts from the local app to project-specific context repositories. Includes project discovery via `.entourage/config.json`.

### Changes Required

#### 1. Create skill directory

**Create**: `skills/import-hyprnote/SKILL.md`

```markdown
---
name: import-hyprnote
description: Import Hyprnote meeting transcripts to project-specific context repositories
---

# Import Hyprnote

Import Hyprnote meeting transcripts from the local app to the appropriate project context repositories.

## When to Use

- After recording meetings in Hyprnote
- When transcripts need to be sorted to project-specific data directories
- Periodically to keep context repos up to date

## Configuration

Requires `.entourage/config.json` with project definitions:

```json
{
  "projects": [
    {
      "name": "entourage-context",
      "path": "~/Documents/code/@orgs/my-entourage/entourage-context",
      "description": "AI agent development and product specs",
      "keywords": ["agent", "spec", "inbox", "timeline", "Jared"]
    }
  ]
}
```

## Workflow

### Step 1: Load Configuration

1. Read `.entourage/config.json` from current working directory
2. If not found, prompt user to create configuration:
   - Scan `~/Documents/` for `*-context/` directories
   - Present found projects for confirmation
   - Ask for description and keywords for each
   - Save to `.entourage/config.json`

### Step 2: Discover Hyprnote Sessions

1. List all sessions in `~/Library/Application Support/hyprnote/sessions/`
2. For each session, check for:
   - `_meta.json` (required)
   - `_transcript.json` (required)
   - `_memo.md` (optional)

3. Skip sessions that are empty (no transcript content)

### Step 3: Classify Sessions

For each session:

1. Read `_transcript.json` and reconstruct text:
   ```
   words.map(w => w.text).join('').trim()
   ```

2. Read `_memo.md` if exists

3. Match against project keywords (case-insensitive)

4. Assign to best matching project, or "unclassified" if no match

### Step 4: Present Classification for Approval

Present a table to the user:

```markdown
## Session Classification

| Session | Date | Title | Assigned To | Confidence |
|---------|------|-------|-------------|------------|
| abc123 | 2026-01-14 | Team standup | entourage-context | High (5 keywords) |
| def456 | 2026-01-13 | Procurement call | viran-context | Medium (2 keywords) |
| ghi789 | 2026-01-12 | Personal notes | unclassified | Low (0 keywords) |

Proceed with this classification? (You can reassign any session)
```

Wait for user confirmation or adjustments.

### Step 5: Execute Import

For each confirmed session:

1. Create destination directory: `{project_path}/data/transcripts/hyprnote/{session_id}/`

2. Copy files:
   - `_meta.json`
   - `_transcript.json`
   - `_memo.md` (if exists)

3. Do NOT delete source files (user can clean up manually)

### Step 6: Commit Changes (Optional)

For each affected project:

1. Ask user if they want to commit the changes

2. If yes:
   ```bash
   git -C {project_path} add data/transcripts/hyprnote/
   git -C {project_path} commit -m "Import Hyprnote transcripts from {date}"
   ```

## Output

Summary of what was imported:

```markdown
## Import Complete

Imported 3 sessions:
- entourage-context: 2 sessions
- viran-context: 1 session

Skipped:
- 1 unclassified session (ghi789)
- 2 empty sessions

Run `/update-timeline` in each context repo to process these transcripts.
```

## Error Handling

- **No config found**: Guide user through setup wizard
- **No Hyprnote sessions**: Report "No sessions found in Hyprnote"
- **Project path doesn't exist**: Warn and skip that project
- **Git not available**: Skip commit step, warn user

## Execution Behavior

This skill returns results to the calling context and does NOT stop execution.
```

### Success Criteria

#### Automated Verification:
- [ ] `skills/import-hyprnote/SKILL.md` exists
- [ ] SKILL.md has valid frontmatter with `name` and `description`
- [ ] File is valid Markdown

#### Manual Verification:
- [ ] Run `/import-hyprnote` in a test project
- [ ] Verify setup wizard runs if no config exists
- [ ] Verify sessions are discovered from Hyprnote app
- [ ] Verify classification table is presented
- [ ] Verify files are copied to correct destination
- [ ] Verify commit prompt works

### Implementation Note:
After completing this phase, test the full import flow manually before proceeding.

---

## Phase 4: update-timeline Skill

### Overview

Migrate the update-timeline skill from viran-context, adding the source registry pattern for extensibility and unknown source detection.

### Changes Required

#### 1. Create skill directory structure

```
skills/update-timeline/
├── SKILL.md
├── processing-rules.md
├── source-formats.md
├── output-template.md
└── sources/
    └── _registry.json
```

#### 2. Create sources registry

**Create**: `skills/update-timeline/sources/_registry.json`

```json
{
  "sources": [
    {
      "id": "hyprnote",
      "name": "Hyprnote Transcripts",
      "detectPattern": "data/transcripts/hyprnote/*/_meta.json",
      "parser": "See source-formats.md#hyprnote"
    },
    {
      "id": "notion",
      "name": "Notion Pages",
      "detectPattern": "data/transcripts/notion/*.md",
      "parser": "See source-formats.md#notion"
    },
    {
      "id": "whatsapp",
      "name": "WhatsApp Chats",
      "detectPattern": "data/messaging/whatsapp/*/_chat.txt",
      "parser": "See source-formats.md#whatsapp"
    },
    {
      "id": "hailer",
      "name": "Hailer Messages",
      "detectPattern": "data/messaging/hailer/*.md",
      "parser": "See source-formats.md#hailer"
    }
  ],
  "unknownDataPaths": [
    "data/transcripts/*/",
    "data/messaging/*/",
    "data/raw/*/"
  ]
}
```

#### 3. Copy and update SKILL.md

**Create**: `skills/update-timeline/SKILL.md`

Copy from `/Users/ia/Documents/code/@orgs/viranhq/viran-context/.claude/skills/update-timeline/SKILL.md` with these modifications:

1. Add source registry loading step at the beginning
2. Add unknown source detection after loading registry
3. Update paths to be relative (not viran-specific)

Add this section after "When to Use":

```markdown
## Source Registry

This skill uses a source registry to detect and parse different data formats.

### Loading Sources

1. Read `sources/_registry.json` from this skill directory
2. For each registered source, check if `detectPattern` matches any files
3. Track which sources are present

### Unknown Source Detection

After checking registered sources, scan `unknownDataPaths` for directories not in the registry:

```markdown
⚠️ Unknown data sources detected:
- data/messaging/telegram/ (not in registry)
- data/raw/linear/ (not in registry)

To add support, document the format in source-formats.md and add to sources/_registry.json
```

Continue processing known sources, but warn about unknown ones.
```

#### 4. Copy supporting files

**Copy**: `processing-rules.md` from viran-context (no modifications needed)

**Copy**: `source-formats.md` from viran-context (no modifications needed)

**Copy**: `output-template.md` from viran-context (no modifications needed)

### Success Criteria

#### Automated Verification:
- [ ] `skills/update-timeline/SKILL.md` exists with valid frontmatter
- [ ] `skills/update-timeline/sources/_registry.json` is valid JSON
- [ ] `skills/update-timeline/processing-rules.md` exists
- [ ] `skills/update-timeline/source-formats.md` exists
- [ ] `skills/update-timeline/output-template.md` exists

#### Manual Verification:
- [ ] Run `/update-timeline` in a context repo with Hyprnote data
- [ ] Verify it detects and processes Hyprnote transcripts
- [ ] Verify it outputs to `analysis/events-chronological.md`
- [ ] Create a fake `data/messaging/telegram/` directory
- [ ] Verify unknown source warning is displayed
- [ ] Verify state tracking works (`.claude/state/timeline-state.json`)

### Implementation Note:
After completing this phase, test with real data in a context repository.

---

## Phase 5: Pre-Migration Check for notion-exporter

### Overview

Before migrating notion-exporter, verify the current implementation is stable and ready for migration. This is a checkpoint phase.

### Changes Required

#### 1. Review current notion-exporter status

Check `/Users/ia/.claude/scripts/notion-exporter/` for:
- Recent changes to `exporter.py`
- Recent changes to `converter.py`
- Any TODO comments or WIP markers
- Test status

#### 2. Document current state

**Create**: `thoughts/notes/2026-01-14-notion-exporter-migration-status.md`

Document:
- Current features working
- Known issues or limitations
- Pending changes
- Dependencies (Python version, packages)

### Success Criteria

#### Automated Verification:
- [ ] Status document created

#### Manual Verification:
- [ ] User confirms notion-exporter is stable and ready for migration
- [ ] No pending changes that would conflict with migration

### Implementation Note:
**STOP HERE** and get explicit user confirmation that notion-exporter is ready before proceeding to Phase 6.

---

## Phase 6: import-notion Skill

### Overview

Migrate notion-exporter Python scripts to the plugin as an embedded skill. The skill wraps the existing Python scripts and handles venv setup.

### Changes Required

#### 1. Create skill directory structure

```
skills/import-notion/
├── SKILL.md
├── README.md
└── scripts/
    ├── exporter.py
    ├── converter.py
    └── requirements.txt
```

#### 2. Copy Python scripts

**Copy**: From `/Users/ia/.claude/scripts/notion-exporter/`:
- `exporter.py` → `skills/import-notion/scripts/exporter.py`
- `converter.py` → `skills/import-notion/scripts/converter.py`
- `requirements.txt` → `skills/import-notion/scripts/requirements.txt`

#### 3. Create SKILL.md

**Create**: `skills/import-notion/SKILL.md`

```markdown
---
name: import-notion
description: Import pages from Notion workspace to local markdown files
---

# Import Notion

Export and convert Notion workspace pages to local markdown files for use in context repositories.

## When to Use

- After making changes in Notion that should be synced locally
- When setting up a new context repository with Notion data
- Periodically to keep local copies in sync

## Configuration

Requires `.entourage/notion.config.json` in the target project:

```json
{
  "apiKeyEnvVar": "NOTION_API_KEY_PROJECTNAME",
  "targetPath": ".",
  "rawExportPath": "data/raw/notion",
  "outputPath": "data/transcripts/notion",
  "excludePatterns": ["Archive", "Template"]
}
```

API keys are stored in `~/.claude/.env`:
```
NOTION_API_KEY_PROJECTNAME=secret_xxx
```

## Prerequisites

1. **Notion Integration**: Create at https://www.notion.so/my-integrations
   - One integration per workspace (project)
   - Share specific pages with the integration

2. **Python Environment**: The skill will set up a venv on first run

## Workflow

### Step 1: Check Configuration

1. Read `.entourage/notion.config.json`
2. If not found, guide user through setup:
   - Ask for API key environment variable name
   - Ask for target paths
   - Create config file

### Step 2: Setup Python Environment

1. Check if venv exists at `~/.claude/venvs/notion-exporter/`
2. If not, create and install dependencies:
   ```bash
   python3 -m venv ~/.claude/venvs/notion-exporter
   ~/.claude/venvs/notion-exporter/bin/pip install -r {skill_dir}/scripts/requirements.txt
   ```

### Step 3: Export from Notion

Run the exporter:
```bash
~/.claude/venvs/notion-exporter/bin/python {skill_dir}/scripts/exporter.py \
  --config .entourage/notion.config.json
```

Output: `{rawExportPath}/{timestamp}/notion_content.json`

### Step 4: Convert to Markdown

Run the converter:
```bash
~/.claude/venvs/notion-exporter/bin/python {skill_dir}/scripts/converter.py \
  --config .entourage/notion.config.json
```

Output: `{outputPath}/*.md`

### Step 5: Report Results

```markdown
## Import Complete

Exported from Notion:
- Pages: 42
- Databases: 3
- Assets: 15

Converted to Markdown:
- Files created: 45
- Location: data/transcripts/notion/

Run `/update-timeline` to process these files.
```

## Error Handling

- **No config**: Guide through setup wizard
- **Invalid API key**: Report authentication error with link to Notion integrations
- **Rate limited**: Report and suggest waiting
- **Python not found**: Report requirement for Python 3.8+

## Execution Behavior

This skill returns results to the calling context and does NOT stop execution.
```

#### 4. Create README

**Create**: `skills/import-notion/README.md`

```markdown
# import-notion

Import Notion workspace pages to local markdown files.

## Setup

### 1. Create Notion Integration

1. Go to https://www.notion.so/my-integrations
2. Create a new integration for your workspace
3. Copy the API key

### 2. Share Pages with Integration

In Notion, for each page you want to export:
1. Click "..." menu → "Add connections"
2. Select your integration

### 3. Configure API Key

Add to `~/.claude/.env`:
```
NOTION_API_KEY_MYPROJECT=secret_xxx
```

### 4. Create Project Config

Create `.entourage/notion.config.json` in your project:
```json
{
  "apiKeyEnvVar": "NOTION_API_KEY_MYPROJECT",
  "targetPath": ".",
  "rawExportPath": "data/raw/notion",
  "outputPath": "data/transcripts/notion",
  "excludePatterns": []
}
```

## Usage

```
/import-notion
```

## How It Works

1. Exports all shared pages to raw JSON
2. Converts JSON to clean markdown
3. Preserves page hierarchy in filenames
4. Downloads and stores assets locally

## Dependencies

- Python 3.8+
- Packages: notion-client, httpx, python-dotenv
```

### Success Criteria

#### Automated Verification:
- [ ] `skills/import-notion/SKILL.md` exists with valid frontmatter
- [ ] `skills/import-notion/scripts/exporter.py` exists
- [ ] `skills/import-notion/scripts/converter.py` exists
- [ ] `skills/import-notion/scripts/requirements.txt` exists
- [ ] `skills/import-notion/README.md` exists

#### Manual Verification:
- [ ] Run `/import-notion` in a test project
- [ ] Verify venv is created on first run
- [ ] Verify export from Notion succeeds
- [ ] Verify conversion to markdown succeeds
- [ ] Verify files appear in correct location

### Implementation Note:
This phase requires notion-exporter to be stable. Only proceed after Phase 5 confirmation.

---

## Phase 7: Documentation and Cleanup

### Overview

Update all documentation, archive old source locations, and finalize the plugin.

### Changes Required

#### 1. Update main README.md

**File**: `README.md`

Add sections for new skills:
- import-hyprnote
- update-timeline
- import-notion
- Session tracking hooks

#### 2. Archive notification

Create notes in original source locations pointing to new home:

**Create**: `/Users/ia/.claude/commands/sort-hyprnote.md.archived`
```markdown
# ARCHIVED

This command has been migrated to the entourage plugin.

Use: `/import-hyprnote` (after installing entourage plugin)

Install: `/plugin install entourage@entourage-marketplace`
```

#### 3. Update examples/repos.json.example

Add example showing full config structure with projects and sessionLogging.

### Success Criteria

#### Automated Verification:
- [ ] README.md updated with new skills
- [ ] All skill directories have README.md files
- [ ] examples/config.json.example exists

#### Manual Verification:
- [ ] Documentation is clear and complete
- [ ] Installation instructions work
- [ ] All skills appear in `/help` or plugin listing

---

## Testing Strategy

### Unit Tests

No automated unit tests for skills (they're prompt-based). Rely on manual testing.

### Integration Tests

For each skill, test the full workflow:

1. **import-hyprnote**:
   - No config → setup wizard
   - With config → classification table
   - Confirm → files copied

2. **update-timeline**:
   - No sources → appropriate message
   - Known sources → processed correctly
   - Unknown sources → warning displayed

3. **import-notion**:
   - No config → setup wizard
   - No venv → venv created
   - With config → export and convert

4. **Session tracking**:
   - Enabled → files created
   - Disabled via env → no files
   - Disabled via config → no files

### Manual Testing Steps

1. Install plugin fresh: `/plugin install entourage@entourage-marketplace`
2. Start session, verify session logging works
3. Run each skill and verify output
4. Test disable mechanisms

## Migration Notes

### Source Locations to Archive After Migration

| Source | Action |
|--------|--------|
| `/Users/ia/Documents/code/@orgs/my-entourage/claude-logger` | Keep repo, add README pointing to plugin |
| `/Users/ia/.claude/commands/sort-hyprnote.md` | Rename to `.archived` |
| `/Users/ia/Documents/code/@orgs/viranhq/viran-context/.claude/skills/update-timeline/` | Keep for now, can remove later |
| `/Users/ia/.claude/scripts/notion-exporter/` | Keep as development location until stable |

### Rollback Plan

If issues arise:
1. Skills can be deleted from plugin without affecting others
2. Original sources remain in place
3. Users can reinstall previous plugin version

## References

- Research: `thoughts/research/2026-01-14-plugin-expansion-candidates.md`
- Research: `thoughts/research/2026-01-14-project-analysis.md`
- Claude Code plugin docs: https://code.claude.com/docs/en/plugins.md
- Claude Code hooks docs: https://code.claude.com/docs/en/hooks-guide.md
