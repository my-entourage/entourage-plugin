---
date: 2026-01-14T17:00:00-08:00
researcher: ii-vo
git_commit: 388263634020cb3be222d8f0e5d3e1b2b3bfaa59
branch: main
repository: my-entourage/entourage-plugin
topic: "Plugin Expansion: Candidate Projects and Naming Conventions"
tags: [research, plugins, marketplace, connectors, naming]
status: complete
last_updated: 2026-01-14
last_updated_by: ii-vo
---

# Research: Plugin Expansion Candidates

**Date**: 2026-01-14T17:00:00-08:00
**Researcher**: ii-vo
**Git Commit**: 388263634020cb3be222d8f0e5d3e1b2b3bfaa59
**Branch**: main
**Repository**: my-entourage/entourage-plugin

## Research Question

The user wants to add these projects to the plugin:
1. **claude-logger** - Session tracking hooks (separate repo)
2. **update-timeline** - Timeline update skill (from viran-context)
3. **sort-hyprnote** - Transcript sorting command (personal)
4. **notion-exporter** - Notion export scripts (personal)

Additionally: naming conventions for "connectors" with input/output patterns.

## Summary

### Project Classification

| Project | Type | Current Location | Integration Method |
|---------|------|------------------|-------------------|
| claude-logger | Hooks | Separate repo | **Separate plugin in same marketplace** |
| update-timeline | Skill | viran-context/.claude/skills/ | Move to entourage-plugin/skills/ |
| sort-hyprnote | Command | ~/.claude/commands/ | Move to entourage-plugin/skills/ (upgrade) |
| notion-exporter | Scripts | ~/.claude/scripts/ | Move to entourage-plugin/skills/ (upgrade) |

### Marketplace Structure Options

**Option 1: Single Plugin (Recommended)**
All skills in entourage-plugin, claude-logger as separate plugin in same marketplace.

```json
{
  "plugins": [
    {
      "name": "entourage",
      "source": { "source": "github", "repo": "my-entourage/entourage-plugin" }
    },
    {
      "name": "claude-logger",
      "source": { "source": "github", "repo": "my-entourage/claude-logger" }
    }
  ]
}
```

**Option 2: Monorepo with Multiple Plugins**
All components in same repo under `plugins/` directory.

---

## Detailed Findings

### 1. claude-logger

**Location**: `/Users/ia/Documents/code/@orgs/my-entourage/claude-logger`

**Purpose**: Meta-optimization system that captures Claude Code session data for analysis.

**Components**:
- `hooks/session_start.sh` - Captures git state, CLAUDE.md, skills, commands at session start
- `hooks/session_end.sh` - Records final state, copies transcript at session end
- `install.sh` - Installs hooks to target projects
- `hooks-config.json` - Template for Claude Code hooks configuration

**Data Flow**:
1. SessionStart hook reads Claude input, captures state → `.claude/sessions/{nickname}/{session_id}.json`
2. SessionEnd hook updates JSON, copies transcript to project

**Why Separate Plugin**:
- claude-logger installs **hooks** (not skills/commands) to other projects
- It's an installer/meta-tool, not a direct skill
- Users run `./install.sh ~/project` to add hooks to their projects
- Keeping it separate maintains clear separation of concerns

**Marketplace Integration**: Add as second plugin in marketplace.json

---

### 2. update-timeline

**Location**: `/Users/ia/Documents/code/@orgs/viranhq/viran-context/.claude/skills/update-timeline/`

**Purpose**: Update chronological events index with deep understanding of transcripts, messages, and communications.

**Files**:
- `SKILL.md` (main skill definition)
- `processing-rules.md` (deep understanding guidelines)
- `source-formats.md` (parsing reference)
- `output-template.md` (entry format specification)

**Input Sources**:
- Hyprnote transcripts (`data/transcripts/hyprnote/*/_meta.json`)
- Notion files (`data/transcripts/notion/*.md`)
- WhatsApp chats (`data/messaging/whatsapp/*/_chat.txt`)
- Hailer messages (`data/messaging/hailer/*.md`)

**Output**: `analysis/events-chronological.md`

**State Tracking**: `.claude/state/timeline-state.json`

**Key Features**:
- Incremental processing (tracks what's already processed)
- Multi-source aggregation
- Deep content interpretation (summaries, decisions, action items)
- Participant identification
- Relevance rating

**Integration**: This is a proper skill with supporting files. Move entire directory to `entourage-plugin/skills/update-timeline/`.

---

### 3. sort-hyprnote

**Location**: `/Users/ia/.claude/commands/sort-hyprnote.md`

**Purpose**: Sort Hyprnote meeting transcripts from local app to project-specific context repositories.

**Type**: Currently a command (single .md file)

**Workflow**:
1. **Discovery**: List all Hyprnote sessions, discover target projects
2. **Understand Projects**: Read CLAUDE.md files for classification keywords
3. **Analyze Sessions**: Read transcript content, classify based on keywords
4. **Present Classification**: Human-in-the-loop table for approval
5. **Execute**: Copy files to destinations, delete empty sessions
6. **Auto-Commit**: Commit changes to affected projects

**Input**:
- Source: `~/Library/Application Support/hyprnote/sessions/`
- Classification: Project CLAUDE.md files with keywords

**Output**:
- Destinations: `*-context/data/transcripts/hyprnote/`
- Copied files: `_meta.json`, `_transcript.json`, `_memo.md`

**Classification Keywords** (example):
| Project | Keywords |
|---------|----------|
| Entourage | agent, spec, inbox, timeline, Jared |
| Viran | procurement, RFP, Helsinki, public sector |
| Personal | expenses, travel, personal |

**Integration**: Upgrade to skill (directory with SKILL.md and supporting files).

---

### 4. notion-exporter

**Location**: `/Users/ia/.claude/scripts/notion-exporter/`

**Purpose**: Export and convert Notion workspace pages to raw JSON and Markdown.

**Files**:
- `exporter.py` - Raw JSON export from Notion API
- `converter.py` - JSON to Markdown conversion
- `README.md` - Setup and usage docs
- `requirements.txt` - Python dependencies

**Configuration**:
- API keys: `~/.claude/.env` (per-space keys)
- Spaces: `~/.claude/notion-exporter.config.json`

**Data Flow**:
1. **Export**: `python exporter.py <space>` → `{targetPath}/{rawExportPath}/{timestamp}/notion_content.json`
2. **Convert**: `python converter.py <space>` → `{targetPath}/data/notion/*.md`

**Features**:
- Rate-limited API client (350ms between requests)
- Incremental export (saves after each page)
- Asset downloading (images, files)
- Comments extraction
- User resolution
- Nested page hierarchy preservation

**Integration**: Upgrade to skill that wraps the Python scripts.

---

## Naming Conventions for Connectors

The user noted these tools have **input** and **output** patterns - they're "connectors" that move/transform data.

### Current Pattern Analysis

| Tool | Input Source | Output Destination |
|------|-------------|-------------------|
| sort-hyprnote | Hyprnote app | *-context/data/transcripts/hyprnote/ |
| notion-exporter | Notion API | data/raw/notion/, data/notion/ |
| update-timeline | data/transcripts/*, data/messaging/* | analysis/events-chronological.md |

### Naming Convention Recommendations

**Option A: Action-First (Current Style)**
```
sort-hyprnote
export-notion
update-timeline
```
Pros: Clear action, familiar
Cons: Inconsistent pattern

**Option B: Source-Sink Pattern**
```
hyprnote-import       # hyprnote → context repos
notion-export         # notion API → local files
sources-timeline      # multiple sources → timeline
```
Pros: Clear data flow direction
Cons: "import" vs "export" can be confusing (import TO where?)

**Option C: Connector Pattern (Recommended)**
```
connector-hyprnote    # Connects Hyprnote app to context repos
connector-notion      # Connects Notion API to local files
connector-timeline    # Aggregates sources into timeline
```
Pros: Consistent prefix, clear category
Cons: Verbose

**Option D: Sync Pattern**
```
sync-hyprnote         # Syncs Hyprnote → context
sync-notion           # Syncs Notion → local
sync-timeline         # Syncs sources → timeline (aggregate)
```
Pros: Simple, action-oriented
Cons: "sync" implies bidirectional, which these aren't

**Option E: Ingest/Publish Pattern**
```
ingest-hyprnote       # Ingests from Hyprnote
ingest-notion         # Ingests from Notion
publish-timeline      # Publishes aggregated timeline
```
Pros: Clear direction (ingest = bring in, publish = put out)
Cons: Two different prefixes

### Recommended Naming Convention

**Use `ingest-` for data importers, `publish-` for aggregators/exporters:**

| Current | Proposed | Rationale |
|---------|----------|-----------|
| sort-hyprnote | `ingest-hyprnote` | Ingests transcripts from Hyprnote app |
| notion-exporter | `ingest-notion` | Ingests pages from Notion API |
| update-timeline | `publish-timeline` | Publishes aggregated timeline |

**Alternative: Use `sync-` uniformly if simpler:**
- `sync-hyprnote`
- `sync-notion`
- `sync-timeline`

---

## Marketplace Configuration

### Current marketplace.json

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "entourage-marketplace",
  "version": "1.0.0",
  "description": "Shared skills for the Entourage team",
  "owner": {
    "name": "My Entourage",
    "email": "blaze46593@gmail.com",
    "url": "https://github.com/my-entourage/entourage-plugin"
  },
  "plugins": [
    {
      "name": "entourage",
      "source": { "source": "github", "repo": "my-entourage/entourage-plugin" },
      "category": "productivity",
      "tags": ["project-status", "grounded-query", "github", "verification"]
    }
  ]
}
```

### Proposed marketplace.json (with claude-logger)

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "entourage-marketplace",
  "version": "1.0.0",
  "description": "Shared tools for the Entourage team - skills, connectors, and session tracking",
  "owner": {
    "name": "My Entourage",
    "email": "blaze46593@gmail.com",
    "url": "https://github.com/my-entourage/entourage-plugin"
  },
  "plugins": [
    {
      "name": "entourage",
      "description": "Skills for grounded queries, project status, and data sync",
      "version": "1.0.0",
      "source": { "source": "github", "repo": "my-entourage/entourage-plugin" },
      "category": "productivity",
      "tags": ["project-status", "grounded-query", "github", "verification", "sync"]
    },
    {
      "name": "claude-logger",
      "description": "Session tracking hooks for meta-optimization",
      "version": "1.0.0",
      "source": { "source": "github", "repo": "my-entourage/claude-logger" },
      "category": "developer-tools",
      "tags": ["hooks", "session-tracking", "meta"]
    }
  ]
}
```

---

## Integration Plan

### Phase 1: Add New Skills to entourage-plugin

1. **Create skill directories**:
   ```
   skills/
   ├── ingest-hyprnote/
   │   └── SKILL.md
   ├── ingest-notion/
   │   └── SKILL.md
   ├── publish-timeline/
   │   ├── SKILL.md
   │   ├── processing-rules.md
   │   ├── source-formats.md
   │   └── output-template.md
   ```

2. **Move update-timeline** from viran-context (rename to publish-timeline)

3. **Convert sort-hyprnote** from command to skill

4. **Create wrapper skill** for notion-exporter Python scripts

### Phase 2: Add claude-logger to Marketplace

1. **Add plugin.json** to claude-logger repo:
   ```json
   {
     "name": "claude-logger",
     "version": "1.0.0",
     "description": "Session tracking hooks for meta-optimization"
   }
   ```

2. **Update marketplace.json** in entourage-plugin to include claude-logger

### Phase 3: Update Documentation

1. Update README.md with new skills
2. Update tags in marketplace.json
3. Create skill READMEs

---

## Code References

- Existing marketplace: `.claude-plugin/marketplace.json`
- Existing plugin manifest: `.claude-plugin/plugin.json`
- Claude-logger hooks: `/Users/ia/Documents/code/@orgs/my-entourage/claude-logger/hooks/`
- Update-timeline skill: `/Users/ia/Documents/code/@orgs/viranhq/viran-context/.claude/skills/update-timeline/SKILL.md`
- Sort-hyprnote command: `/Users/ia/.claude/commands/sort-hyprnote.md`
- Notion-exporter scripts: `/Users/ia/.claude/scripts/notion-exporter/`

## Related Research

- `thoughts/research/2026-01-14-project-analysis.md` - Full project analysis

## Open Questions

1. **Naming convention decision**: `ingest-`/`publish-` vs `sync-` for all connectors?
2. **Python scripts**: Should notion-exporter Python scripts be copied into the plugin, or remain external with skill as wrapper?
3. **Configuration files**: How to handle `~/.claude/notion-exporter.config.json` - keep external or move to `.entourage/`?
4. **claude-logger structure**: Does it need a `.claude-plugin/plugin.json` to be listed in marketplace?
