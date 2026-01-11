# Organization Skills Repository Setup Plan

**Date:** 2026-01-11
**Purpose:** Set up a shared Claude Code skills repository for the my-entourage organization
**Estimated Complexity:** Low (mostly configuration)

---

## Overview

This plan details how to create an organization-level Claude Code skills repository that all team members can clone and use across projects. Skills are reusable prompt templates that can be invoked with `/skill-name` in Claude Code.

---

## Step 1: Create the GitHub Repository

1. Go to GitHub and navigate to the `my-entourage` organization
2. Click **New repository**
3. Configure the repository:
   - **Name:** `claude-code-skills` (or `claude-skills`, `org-skills`)
   - **Visibility:** Private (recommended for org-specific skills)
   - **Initialize with:** README
   - **Description:** "Shared Claude Code skills for the my-entourage organization"
4. Click **Create repository**

---

## Step 2: Clone the Repository Locally

```bash
cd ~/Documents/code/@orgs/my-entourage
git clone git@github.com:my-entourage/claude-code-skills.git
cd claude-code-skills
```

---

## Step 3: Create the Skills Directory Structure

Skills must be in a `.claude/skills/` directory at the repository root.

```bash
mkdir -p .claude/skills
```

The structure should look like:
```
claude-code-skills/
├── .claude/
│   └── skills/
│       ├── grounded-query.md
│       ├── project-status.md
│       └── [other-skill-name].md
├── CLAUDE.md           # Optional: instructions for this repo
└── README.md           # Documentation for team
```

---

## Step 4: Create Skill Files

Each skill is a Markdown file with frontmatter. Here's the template:

```markdown
---
name: skill-name
description: Brief description shown in skill listings
user_invocable: true  # Set to true if users can invoke with /skill-name
---

# Skill Name

Instructions for Claude when this skill is invoked...
```

### Example Skills to Include

Copy any existing skills from `entourage-context/.claude/skills/` or create new ones:

**grounded-query.md** - Verify claims against source documents
**project-status.md** - Report implementation status with evidence

---

## Step 5: Add README Documentation

Create a `README.md` explaining:
- What skills are available
- How team members should set up their local environment
- How to add new skills

Example:
```markdown
# Claude Code Skills - my-entourage

Shared skills for Claude Code across our organization's projects.

## Setup

1. Clone this repository to your local machine
2. Add the path to your `~/.claude.json` configuration (see below)
3. Skills will be available in all your Claude Code sessions

## Available Skills

| Skill | Command | Description |
|-------|---------|-------------|
| Grounded Query | `/grounded-query` | Verify claims against documents |
| Project Status | `/project-status` | Report implementation status |

## Adding New Skills

1. Create a new `.md` file in `.claude/skills/`
2. Include frontmatter with name, description, user_invocable
3. Commit and push
4. Team members pull to get the new skill
```

---

## Step 6: Configure Local Claude Code to Use the Skills

Each team member needs to add the skills repository path to their `~/.claude.json`:

```json
{
  "projects": {
    "/Users/[username]/Documents/code/@orgs/my-entourage/entourage-web": {
      "skillsSearchPaths": [
        "/Users/[username]/Documents/code/@orgs/my-entourage/claude-code-skills/.claude/skills"
      ]
    },
    "/Users/[username]/Documents/code/@orgs/my-entourage/entourage-context": {
      "skillsSearchPaths": [
        "/Users/[username]/Documents/code/@orgs/my-entourage/claude-code-skills/.claude/skills"
      ]
    }
  }
}
```

**Alternative: Global configuration** (applies to all projects):
```json
{
  "skillsSearchPaths": [
    "/Users/[username]/Documents/code/@orgs/my-entourage/claude-code-skills/.claude/skills"
  ]
}
```

---

## Step 7: Test the Setup

1. Open Claude Code in any configured project
2. Type `/` to see available skills
3. Verify org skills appear in the list
4. Test invoking a skill: `/grounded-query What decisions were made about the MVP?`

---

## Step 8: Team Onboarding

Share with team members:
1. Clone the `claude-code-skills` repository
2. Add `skillsSearchPaths` to their `~/.claude.json`
3. Pull periodically to get new/updated skills

---

## Maintenance Workflow

### Adding a New Skill
1. Create the skill file in `.claude/skills/`
2. Test locally
3. Commit and push to main
4. Notify team to `git pull`

### Updating a Skill
1. Edit the skill file
2. Test locally
3. Commit and push
4. Team pulls to get updates

---

## Key Points

- Skills are **not** automatically synced - team members must `git pull`
- The `skillsSearchPaths` setting tells Claude Code where to find additional skills
- Skills in the org repo are **merged** with any project-local skills
- Skill names must be unique across all search paths

---

## Verification Checklist

- [ ] Repository created in my-entourage organization
- [ ] `.claude/skills/` directory exists
- [ ] At least one skill file added with correct frontmatter
- [ ] README documents setup and usage
- [ ] Local `~/.claude.json` configured with `skillsSearchPaths`
- [ ] Skills appear when typing `/` in Claude Code
- [ ] Skills execute correctly when invoked
