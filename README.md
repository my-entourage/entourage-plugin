# entourage-plugin

Comprehensive Claude Code plugin for context management, verification, data import, and session tracking. Contains reusable skills that can be invoked with `/skill-name`.

## Installation

### Option 1: Marketplace (Recommended)

Add the marketplace and install the plugin:

```bash
/plugin marketplace add my-entourage/entourage-plugin
/plugin install entourage@entourage-marketplace
```

Or use the interactive menu:
1. Run `/plugin`
2. Select "Discover" > "entourage-marketplace"
3. Select "entourage" to install

### Option 2: Local Plugin (For Development)

Run Claude Code with the plugin directory:

```bash
claude --plugin-dir ~/entourage-plugin
```

Add an alias to your shell config (`~/.zshrc` or `~/.bashrc`) for convenience:

```bash
alias claude-entourage='claude --plugin-dir ~/entourage-plugin'
```

### Option 3: Project-Level Installation

Install the plugin for a specific project:

```bash
cd /path/to/your/project
claude plugin install entourage --source ~/entourage-plugin --scope project
```

This adds the plugin to `.claude/settings.json`, which can be committed to share with your team.

## Available Skills

### Verification Skills

| Skill | Command | Description |
|-------|---------|-------------|
| Grounded Query | `/grounded-query` | Verify claims against source documents |
| Project Status | `/project-status` | Report implementation status with evidence |
| Local Repo Check | `/local-repo-check` | Scan local repositories for implementation evidence |
| GitHub Repo Check | `/github-repo-check` | Query GitHub API for PRs, issues, Actions, deployments |

### Data Import Skills

| Skill | Command | Description |
|-------|---------|-------------|
| Import Hyprnote | `/import-hyprnote` | Import Hyprnote meeting transcripts to context repositories |
| Import Notion | `/import-notion` | Export and convert Notion pages to local markdown |
| Update Timeline | `/update-timeline` | Process transcripts and build chronological events index |

## Session Tracking

This plugin includes session tracking hooks that automatically log Claude Code sessions to your project. Session data is stored in `.claude/sessions/{nickname}/`.

**To enable:** Set `GITHUB_NICKNAME` environment variable in your shell profile.

**To disable:**
- Set `CLAUDE_LOGGER_DISABLED=1` environment variable, or
- Add `"sessionLogging": false` to `.entourage/config.json`

## Repository Configuration (Optional)

The `/local-repo-check`, `/github-repo-check`, and `/project-status` skills can verify implementation status by scanning local git repositories and querying GitHub. To enable this:

1. Create a `.entourage/` directory in your working project (where you run Claude Code)

2. Create `.entourage/repos.json` with your repository configuration:

```json
{
  "github": {
    "token": "ghp_xxxxxxxxxxxx",
    "defaultOrg": "my-org"
  },
  "repos": [
    {
      "name": "entourage-web",
      "path": "~/Documents/code/entourage-web",
      "mainBranch": "main",
      "github": "my-org/entourage-web"
    },
    {
      "name": "entourage-api",
      "path": "~/Documents/code/entourage-api",
      "github": "my-org/entourage-api"
    }
  ]
}
```

**Configuration fields:**

Top-level `github` object (optional):
- `token`: Personal access token (only needed if `gh` CLI is not installed)
- `defaultOrg`: Default organization for repo lookups

Per-repo fields:
- `name` (required): Display name for the repository
- `path` (optional): Local filesystem path for local scanning (supports `~`)
- `mainBranch` (optional): Primary branch name, defaults to "main"
- `github` (optional): GitHub repo identifier in `owner/repo` format

**What local scanning does (`path` configured):**
- Searches repositories for files matching component names
- Detects test files to verify implementation completeness
- Checks git history for recent commits and feature branches

**What GitHub scanning does (`github` configured):**
- Queries PRs (open, merged, reviews)
- Checks GitHub Issues
- Verifies GitHub Actions workflow status
- Checks deployments and releases

**Without configuration:**
The skills still work but limit status to "Discussed" or "Planned" (transcript evidence only).

See `examples/repos.json.example` for a template.

---

## GitHub Authentication

The `/github-repo-check` skill needs access to the GitHub API. There are two options:

### Option 1: gh CLI (Recommended)

Install and authenticate with the GitHub CLI:

```bash
# Install (macOS)
brew install gh

# Authenticate (opens browser)
gh auth login
```

This is the recommended approach because:
- No token stored in config files
- Credentials stored securely in system keychain
- Automatically refreshes authentication
- Works with all your organizations

**Verify it's working:**
```bash
gh auth status
gh api user/orgs --jq '.[].login'  # List your orgs
```

### Option 2: Personal Access Token

If `gh` CLI is unavailable, add a token to `.entourage/repos.json`:

```json
{
  "github": {
    "token": "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  },
  "repos": [...]
}
```

**Generate a PAT:**
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo`, `read:org`, `workflow`
4. Copy the token to your config

**Important:** Add `.entourage/repos.json` to your `.gitignore` if it contains a token.

---

## Accessing Organization Repos

Both authentication methods work with organization repositories. If you're a member of an org, you automatically have access to repos you can see.

```bash
# List orgs you belong to
gh api user/orgs --jq '.[].login'

# List repos in an org
gh api orgs/YOUR_ORG/repos --jq '.[].full_name'
```

## Keeping Skills Updated

```bash
cd ~/entourage-plugin && git pull
```

Then restart Claude Code to pick up the changes.

## Adding New Skills

1. Create a **subdirectory** in `skills/` with your skill name:
   ```bash
   mkdir skills/my-skill
   ```

2. Create a file named exactly `SKILL.md` (case-sensitive) inside the directory:
   ```bash
   touch skills/my-skill/SKILL.md
   ```

3. Add frontmatter with `name` and `description`:
   ```markdown
   ---
   name: my-skill
   description: Brief description shown in skill listings. Claude uses this to decide when to apply the skill.
   ---

   # My Skill

   Instructions for Claude when this skill is invoked...
   ```

4. Commit and push to main
5. Team members run `git pull` and restart Claude Code

**Important:** The directory name should match the `name` field in frontmatter. The file **must** be named `SKILL.md`.

## Plugin Structure

```
entourage-plugin/
├── .claude-plugin/
│   ├── plugin.json          # Plugin manifest
│   └── marketplace.json     # Marketplace listing
├── hooks/
│   └── hooks.json           # Session tracking hooks
├── scripts/
│   ├── session-start.sh     # Session start hook
│   └── session-end.sh       # Session end hook
├── skills/
│   ├── grounded-query/
│   ├── project-status/
│   ├── local-repo-check/
│   ├── github-repo-check/
│   ├── import-hyprnote/     # NEW: Hyprnote transcript import
│   ├── import-notion/       # NEW: Notion page import
│   │   └── scripts/         # Python exporter/converter
│   └── update-timeline/     # NEW: Chronological events indexer
│       └── sources/         # Source registry
├── examples/
│   └── config.json.example  # Configuration template
└── README.md
```

## Troubleshooting

**Skills not appearing?**
- Ensure you're running Claude with `--plugin-dir` flag
- Restart Claude Code after changes
- Check that SKILL.md files have valid YAML frontmatter

**Testing changes locally:**
```bash
claude --plugin-dir ~/entourage-plugin
```

Type `/grounded-query` to verify the skill appears in autocomplete.
