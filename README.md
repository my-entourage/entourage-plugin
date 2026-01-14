# entourage-plugin

Shared Claude Code skills for the Entourage team. This repository is a Claude Code **plugin** containing reusable skills that can be invoked with `/skill-name`.

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

| Skill | Command | Description |
|-------|---------|-------------|
| Grounded Query | `/grounded-query` | Verify claims against source documents |
| Project Status | `/project-status` | Report implementation status with evidence |
| Local Repo Check | `/local-repo-check` | Scan local repositories for implementation evidence |
| GitHub Repo Check | `/github-repo-check` | Query GitHub API for PRs, issues, Actions, deployments |
| Linear Check | `/linear-check` | Query Linear API for issue tracking status |

## Repository Configuration (Optional)

The `/local-repo-check`, `/github-repo-check`, `/linear-check`, and `/project-status` skills can verify implementation status by scanning local git repositories, querying GitHub, and checking Linear issues. To enable this:

1. Create a `.entourage/` directory in your working project (where you run Claude Code)

2. Create `.entourage/repos.json` with your repository configuration:

```json
{
  "github": {
    "token": "ghp_xxxxxxxxxxxx",
    "defaultOrg": "my-org"
  },
  "linear": {
    "teamId": "TEAM",
    "workspace": "my-workspace"
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

Top-level `linear` object (optional):
- `teamId`: Linear team key (e.g., "ENG", "PROD")
- `workspace`: Linear workspace slug from your Linear URL
- `token`: API token (only needed if Linear MCP is not configured)

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

**What Linear scanning does (`linear` configured):**
- Queries issues by component name
- Maps workflow states (Triage, Backlog, Todo, In Progress, In Review, Done, Canceled)
- Checks assignees and due dates
- Uses Linear MCP if available, falls back to API token

**Without configuration:**
The skills still work but limit status to "Triage" (transcript evidence only).

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

## Linear Authentication

The `/linear-check` skill needs access to the Linear API. There are two options:

### Option 1: Linear MCP (Recommended)

Configure the Linear MCP server in `~/.claude.json` or project `.mcp.json`:

```json
{
  "mcpServers": {
    "linear": {
      "type": "sse",
      "url": "https://mcp.linear.app/sse"
    }
  }
}
```

This uses OAuth via browser - no token stored in config files.

### Option 2: API Token

If Linear MCP is unavailable, add a token to `.entourage/repos.json`:

```json
{
  "linear": {
    "token": "lin_api_xxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "teamId": "TEAM",
    "workspace": "my-workspace"
  }
}
```

**Generate a token:** Go to https://linear.app/settings/api and create a Personal API Key.

---

## Plugin Structure

```
entourage-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── skills/
│   ├── grounded-query/
│   │   └── SKILL.md
│   ├── project-status/
│   │   └── SKILL.md
│   ├── local-repo-check/
│   │   └── SKILL.md
│   ├── github-repo-check/
│   │   └── SKILL.md
│   └── linear-check/
│       └── SKILL.md
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
