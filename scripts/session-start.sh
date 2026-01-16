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
