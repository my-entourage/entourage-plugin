#!/bin/bash
#
# run.sh - Full evaluation runner for entourage-plugin
#
# This script executes skill evaluations by running test cases against Claude
# and grading the outputs. Requires Claude Code CLI and API access.
#
# Usage:
#   ./tests/run.sh                          # Run all skill evals
#   ./tests/run.sh grounded-query           # Run specific skill
#   ./tests/run.sh --compare-golden skill   # Compare against golden outputs
#   ./tests/run.sh --dry-run skill          # Show what would run without executing
#
# Environment:
#   CLAUDE_CLI          Path to Claude CLI (default: claude)
#   EVAL_TIMEOUT        Timeout per test case in seconds (default: 60)
#   SKIP_CLAUDE         Set to 1 to skip Claude execution (validation only)
#
# Exit codes:
#   0 - All tests passed
#   1 - Some tests failed
#   2 - Configuration/setup error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$PLUGIN_DIR/skills"
RESULTS_DIR="$SCRIPT_DIR/results"
LIB_DIR="$SCRIPT_DIR/lib"

# Source graders library
source "$LIB_DIR/graders.sh"

# Configuration
CLAUDE_CLI="${CLAUDE_CLI:-claude}"
EVAL_TIMEOUT="${EVAL_TIMEOUT:-60}"
SKIP_CLAUDE="${SKIP_CLAUDE:-0}"
TRIALS_PER_CASE="${TRIALS_PER_CASE:-1}"

# Detect timeout command (GNU coreutils vs macOS)
if command -v gtimeout &> /dev/null; then
    TIMEOUT_CMD="gtimeout"
elif command -v timeout &> /dev/null; then
    TIMEOUT_CMD="timeout"
else
    TIMEOUT_CMD=""
fi

# Colors for output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

# Counters
TOTAL_CASES=0
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Options
COMPARE_GOLDEN=0
DRY_RUN=0
VERBOSE=0

# Parse arguments
parse_args() {
    local positional_args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --compare-golden)
                COMPARE_GOLDEN=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --verbose|-v)
                VERBOSE=1
                shift
                ;;
            --help|-h)
                print_help
                exit 0
                ;;
            -*)
                echo "Unknown option: $1"
                print_help
                exit 2
                ;;
            *)
                positional_args+=("$1")
                shift
                ;;
        esac
    done

    SKILL_FILTER="${positional_args[0]:-}"
}

print_help() {
    cat << EOF
Usage: ./tests/run.sh [OPTIONS] [SKILL]

Run skill evaluations against Claude.

Options:
  --compare-golden    Compare outputs against golden files
  --dry-run          Show what would run without executing
  --verbose, -v      Show detailed output
  --help, -h         Show this help message

Arguments:
  SKILL              Specific skill to test (optional, defaults to all)

Environment Variables:
  CLAUDE_CLI         Path to Claude CLI (default: claude)
  EVAL_TIMEOUT       Timeout per test case in seconds (default: 60)
  SKIP_CLAUDE        Set to 1 to skip Claude execution (validation only)
  TRIALS_PER_CASE    Number of trials per test case for pass@k (default: 1)

Examples:
  ./tests/run.sh                        # Run all evals
  ./tests/run.sh grounded-query         # Run single skill
  ./tests/run.sh --dry-run              # Preview without running
  SKIP_CLAUDE=1 ./tests/run.sh          # Validation only

EOF
}

log_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASS_COUNT++))
}

log_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((FAIL_COUNT++))
}

log_skip() {
    echo -e "  ${YELLOW}○${NC} $1"
    ((SKIP_COUNT++))
}

log_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

log_verbose() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "  ${CYAN}→${NC} $1"
    fi
}

# Check prerequisites
check_prerequisites() {
    # Check jq
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed.${NC}"
        exit 2
    fi

    # Check Claude CLI (unless skipping)
    if [[ $SKIP_CLAUDE -eq 0 && $DRY_RUN -eq 0 ]]; then
        if ! command -v "$CLAUDE_CLI" &> /dev/null; then
            echo -e "${RED}Error: Claude CLI not found at '$CLAUDE_CLI'${NC}"
            echo "Install Claude Code or set CLAUDE_CLI environment variable"
            echo "Or use SKIP_CLAUDE=1 to run validation only"
            exit 2
        fi
    fi

    # Create results directory
    mkdir -p "$RESULTS_DIR"
}

# Setup test context from fixtures if available
setup_test_context() {
    local skill_name="$1"
    local case_id="$2"
    local workdir="$3"

    local fixture_dir="$SKILLS_DIR/$skill_name/evaluations/fixtures/$case_id"
    if [[ -d "$fixture_dir" ]]; then
        log_verbose "Loading fixtures from $fixture_dir"
        cp -r "$fixture_dir"/* "$workdir/" 2>/dev/null || true
        return 0
    fi
    return 1
}

# Execute a single test case
run_test_case() {
    local skill_name="$1"
    local case_json="$2"
    local trial_num="${3:-1}"
    local case_id
    local case_name
    local input

    case_id=$(echo "$case_json" | jq -r '.id')
    case_name=$(echo "$case_json" | jq -r '.name')
    input=$(echo "$case_json" | jq -r '.input')
    expected=$(echo "$case_json" | jq -c '.expectedOutput')

    ((TOTAL_CASES++))

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "Would run: $case_id - $case_name"
        log_verbose "Input: /$skill_name $input"
        return 0
    fi

    if [[ $SKIP_CLAUDE -eq 1 ]]; then
        log_skip "$case_id - $case_name (Claude skipped)"
        return 0
    fi

    local trial_suffix=""
    if [[ $TRIALS_PER_CASE -gt 1 ]]; then
        trial_suffix="_trial${trial_num}"
    fi

    log_verbose "Running: $case_id - $case_name (trial $trial_num)"
    log_verbose "Input: /$skill_name $input"

    # Create temp working directory for this test case
    local workdir
    workdir=$(mktemp -d)
    trap "rm -rf '$workdir'" EXIT

    # Setup test context from fixtures
    setup_test_context "$skill_name" "$case_id" "$workdir"

    # Create output file
    local output_file="$RESULTS_DIR/${skill_name}_${case_id}${trial_suffix}.txt"

    # Build the skill invocation command
    local skill_input="/$skill_name $input"

    # Run Claude with the test input (invoke skill properly)
    local output
    local exit_code=0
    local cmd_args=("--plugin-dir" "$PLUGIN_DIR" "--print" "$skill_input")

    # Use timeout if available
    if [[ -n "$TIMEOUT_CMD" ]]; then
        if "$TIMEOUT_CMD" "$EVAL_TIMEOUT" "$CLAUDE_CLI" "${cmd_args[@]}" > "$output_file" 2>&1; then
            output=$(cat "$output_file")
        else
            exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                log_fail "$case_id - $case_name (timeout after ${EVAL_TIMEOUT}s)"
                rm -rf "$workdir"
                return 1
            else
                output=$(cat "$output_file" 2>/dev/null || echo "")
                # Continue with grading even if non-zero exit
            fi
        fi
    else
        # No timeout command available - run without timeout
        log_verbose "Warning: No timeout command available, running without timeout"
        if "$CLAUDE_CLI" "${cmd_args[@]}" > "$output_file" 2>&1; then
            output=$(cat "$output_file")
        else
            output=$(cat "$output_file" 2>/dev/null || echo "")
        fi
    fi

    # Clean up workdir
    rm -rf "$workdir"

    # Grade the output
    local grade_failures=0
    grade_test_case "$output" "$expected" 2>"$RESULTS_DIR/${skill_name}_${case_id}${trial_suffix}.grade" || grade_failures=$?

    # Check golden comparison if enabled
    if [[ $COMPARE_GOLDEN -eq 1 ]]; then
        local golden_file="$SKILLS_DIR/$skill_name/evaluations/golden/${case_id}.md"
        if [[ -f "$golden_file" ]]; then
            if ! compare_golden "$output" "$golden_file" 2>>"$RESULTS_DIR/${skill_name}_${case_id}${trial_suffix}.grade"; then
                ((grade_failures++))
            fi
        fi
    fi

    # Report result
    if [[ $grade_failures -eq 0 ]]; then
        log_pass "$case_id - $case_name"
    else
        log_fail "$case_id - $case_name ($grade_failures assertion(s) failed)"
        if [[ $VERBOSE -eq 1 ]]; then
            cat "$RESULTS_DIR/${skill_name}_${case_id}${trial_suffix}.grade" 2>/dev/null | sed 's/^/    /'
        fi
    fi

    return $grade_failures
}

# Run all test cases for a skill
run_skill_evals() {
    local skill_name="$1"
    local eval_file="$SKILLS_DIR/$skill_name/evaluations/evaluation.json"

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Skill: $skill_name${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

    if [[ ! -f "$eval_file" ]]; then
        log_skip "No evaluation.json found"
        return 0
    fi

    # Get skill info
    local skill_desc
    skill_desc=$(jq -r '.description' "$eval_file")
    echo -e "  ${CYAN}$skill_desc${NC}"
    if [[ $TRIALS_PER_CASE -gt 1 ]]; then
        echo -e "  ${CYAN}Running $TRIALS_PER_CASE trials per case (pass@k mode)${NC}"
    fi
    echo ""

    # Run each test case
    local case_count
    case_count=$(jq '.testCases | length' "$eval_file")

    local skill_failures=0
    for ((i=0; i<case_count; i++)); do
        local case_json
        case_json=$(jq -c ".testCases[$i]" "$eval_file")

        # Run multiple trials if TRIALS_PER_CASE > 1
        for ((trial=1; trial<=TRIALS_PER_CASE; trial++)); do
            run_test_case "$skill_name" "$case_json" "$trial" || ((skill_failures++))
        done
    done

    return $skill_failures
}

# Generate results summary
generate_summary() {
    local summary_file="$RESULTS_DIR/summary.json"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$summary_file" << EOF
{
  "timestamp": "$timestamp",
  "total": $TOTAL_CASES,
  "passed": $PASS_COUNT,
  "failed": $FAIL_COUNT,
  "skipped": $SKIP_COUNT,
  "passRate": $(echo "scale=2; $PASS_COUNT * 100 / ($TOTAL_CASES - $SKIP_COUNT + 1)" | bc 2>/dev/null || echo "0")
}
EOF

    log_verbose "Results written to $summary_file"
}

# Main execution
main() {
    parse_args "$@"

    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   entourage-plugin Evaluation Runner                   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"

    if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "${YELLOW}  DRY RUN - No tests will be executed${NC}"
    fi

    if [[ $SKIP_CLAUDE -eq 1 ]]; then
        echo -e "${YELLOW}  SKIP_CLAUDE=1 - Claude execution disabled${NC}"
    fi

    check_prerequisites

    # Find skills to test
    local skills=()
    for skill_dir in "$SKILLS_DIR"/*/; do
        local skill_name
        skill_name=$(basename "$skill_dir")

        # Skip if filter specified and doesn't match
        if [[ -n "$SKILL_FILTER" && "$skill_name" != "$SKILL_FILTER" ]]; then
            continue
        fi

        # Only include skills with evaluation files
        if [[ -f "$skill_dir/evaluations/evaluation.json" ]]; then
            skills+=("$skill_name")
        fi
    done

    if [[ ${#skills[@]} -eq 0 ]]; then
        if [[ -n "$SKILL_FILTER" ]]; then
            echo -e "${RED}Error: No skill found matching '$SKILL_FILTER'${NC}"
        else
            echo -e "${YELLOW}Warning: No skills with evaluations found${NC}"
        fi
        exit 2
    fi

    # Run evaluations
    local total_skill_failures=0
    for skill in "${skills[@]}"; do
        run_skill_evals "$skill" || ((total_skill_failures++))
    done

    # Generate summary
    generate_summary

    # Print final summary
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "  ${CYAN}Results Summary${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "  Skills tested:  ${#skills[@]}"
    echo -e "  Total cases:    $TOTAL_CASES"
    echo -e "  ${GREEN}Passed:${NC}         $PASS_COUNT"
    echo -e "  ${RED}Failed:${NC}         $FAIL_COUNT"
    echo -e "  ${YELLOW}Skipped:${NC}        $SKIP_COUNT"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

    if [[ $FAIL_COUNT -gt 0 ]]; then
        echo -e "${RED}  $FAIL_COUNT test(s) failed${NC}"
        echo ""
        echo "  See detailed results in: $RESULTS_DIR"
        exit 1
    elif [[ $SKIP_COUNT -eq $TOTAL_CASES ]]; then
        echo -e "${YELLOW}  All tests skipped${NC}"
        exit 0
    else
        echo -e "${GREEN}  All tests passed!${NC}"
        exit 0
    fi
}

main "$@"
