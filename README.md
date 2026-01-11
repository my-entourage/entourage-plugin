# entourage-plugin

Shared Claude Code skills for the my-entourage organization. Skills are reusable prompt templates that can be invoked with `/skill-name` in Claude Code.

## Setup

1. Clone this repository to your local machine:
   ```bash
   git clone git@github.com:my-entourage/entourage-agent-skills.git
   ```

2. Add the path to your `~/.claude.json` configuration:
   ```json
   {
     "skillsSearchPaths": [
       "/path/to/entourage-agent-skills/.claude/skills"
     ]
   }
   ```
   Replace `/path/to` with the actual path to where you cloned this repository.

3. Skills will now be available in all your Claude Code sessions.

## Available Skills

| Skill | Command | Description |
|-------|---------|-------------|
| Grounded Query | `/grounded-query` | Verify claims against source documents |
| Project Status | `/project-status` | Report implementation status with evidence |

## Adding New Skills

1. Create a new `.md` file in `.claude/skills/`
2. Include frontmatter with `name`, `description`, and `user_invocable`:
   ```markdown
   ---
   name: my-skill
   description: Brief description shown in skill listings
   user_invocable: true
   ---

   # My Skill

   Instructions for Claude when this skill is invoked...
   ```
3. Commit and push to main
4. Team members run `git pull` to get the new skill

## Keeping Skills Updated

Skills are **not** automatically synced. Team members should periodically run `git pull` to get the latest updates.
