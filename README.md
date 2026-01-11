# entourage-plugin

Shared Claude Code skills for the Entourage team. This repository is a Claude Code **plugin** containing reusable skills that can be invoked with `/skill-name`.

## Installation

### Option A: Local Plugin (Recommended for Development)

Run Claude Code with the plugin directory:

```bash
claude --plugin-dir ~/entourage-plugin
```

Add an alias to your shell config (`~/.zshrc` or `~/.bashrc`) for convenience:

```bash
alias claude-entourage='claude --plugin-dir ~/entourage-plugin'
```

### Option B: Project-Level Installation

Install the plugin for a specific project:

```bash
cd /path/to/your/project
claude plugin install entourage-skills --source ~/entourage-plugin --scope project
```

This adds the plugin to `.claude/settings.json`, which can be committed to share with your team.

## Available Skills

| Skill | Command | Description |
|-------|---------|-------------|
| Grounded Query | `/grounded-query` | Verify claims against source documents |
| Project Status | `/project-status` | Report implementation status with evidence |

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
│   └── plugin.json          # Plugin manifest
├── skills/
│   ├── grounded-query/
│   │   └── SKILL.md
│   └── project-status/
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
