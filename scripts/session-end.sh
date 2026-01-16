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
