#!/bin/bash
#
# validate.sh - Validate evaluation JSON files for entourage-plugin
#
# This script validates the structure and schema of evaluation.json files
# without requiring Claude API calls. Suitable for CI/CD and local development.
#
# Usage:
#   ./tests/validate.sh                 # Validate all skills
#   ./tests/validate.sh grounded-query  # Validate specific skill
#
# Exit codes:
#   0 - All validations passed
#   1 - Validation errors found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$PLUGIN_DIR/skills"

# Colors for output (disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

log_pass() {
    echo -e "${GREEN}  ✓${NC} $1"
    ((PASS_COUNT++))
}

log_fail() {
    echo -e "${RED}  ✗${NC} $1"
    ((FAIL_COUNT++))
}

log_warn() {
    echo -e "${YELLOW}  ⚠${NC} $1"
    ((WARN_COUNT++))
}

log_info() {
    echo -e "${BLUE}  ℹ${NC} $1"
}

# Validate JSON syntax
validate_json_syntax() {
    local file="$1"
    if jq empty "$file" 2>/dev/null; then
        log_pass "Valid JSON syntax"
        return 0
    else
        log_fail "Invalid JSON syntax"
        return 1
    fi
}

# Validate required top-level fields
validate_top_level_fields() {
    local file="$1"
    local has_error=0

    # Check for name field
    if jq -e '.name' "$file" >/dev/null 2>&1; then
        log_pass "Has 'name' field"
    else
        log_fail "Missing required 'name' field"
        has_error=1
    fi

    # Check for description field
    if jq -e '.description' "$file" >/dev/null 2>&1; then
        log_pass "Has 'description' field"
    else
        log_fail "Missing required 'description' field"
        has_error=1
    fi

    # Check for testCases array
    if jq -e '.testCases | type == "array"' "$file" >/dev/null 2>&1; then
        local count
        count=$(jq '.testCases | length' "$file")
        log_pass "Has 'testCases' array ($count cases)"
    else
        log_fail "Missing or invalid 'testCases' array"
        has_error=1
    fi

    return $has_error
}

# Validate each test case has required fields
validate_test_case_fields() {
    local file="$1"
    local has_error=0
    local case_count
    case_count=$(jq '.testCases | length' "$file")

    for ((i=0; i<case_count; i++)); do
        local case_id
        case_id=$(jq -r ".testCases[$i].id // \"(no id)\"" "$file")

        # Check required fields
        local missing_fields=()

        if ! jq -e ".testCases[$i].id" "$file" >/dev/null 2>&1; then
            missing_fields+=("id")
        fi

        if ! jq -e ".testCases[$i].name" "$file" >/dev/null 2>&1; then
            missing_fields+=("name")
        fi

        if ! jq -e ".testCases[$i].input" "$file" >/dev/null 2>&1; then
            missing_fields+=("input")
        fi

        if ! jq -e ".testCases[$i].expectedOutput" "$file" >/dev/null 2>&1; then
            missing_fields+=("expectedOutput")
        fi

        if [[ ${#missing_fields[@]} -gt 0 ]]; then
            log_fail "Case '$case_id' missing required fields: ${missing_fields[*]}"
            has_error=1
        fi
    done

    if [[ $has_error -eq 0 ]]; then
        log_pass "All test cases have required fields (id, name, input, expectedOutput)"
    fi

    return $has_error
}

# Check for duplicate test case IDs
validate_unique_ids() {
    local file="$1"
    local duplicates
    duplicates=$(jq -r '.testCases[].id' "$file" | sort | uniq -d)

    if [[ -z "$duplicates" ]]; then
        log_pass "All test case IDs are unique"
        return 0
    else
        log_fail "Duplicate test case IDs found: $duplicates"
        return 1
    fi
}

# Validate contains/notContains arrays are non-empty when present
validate_assertion_arrays() {
    local file="$1"
    local has_error=0
    local case_count
    case_count=$(jq '.testCases | length' "$file")

    for ((i=0; i<case_count; i++)); do
        local case_id
        case_id=$(jq -r ".testCases[$i].id" "$file")

        # Check contains array if present
        local contains_type
        contains_type=$(jq -r ".testCases[$i].expectedOutput.contains | type" "$file" 2>/dev/null || echo "null")
        if [[ "$contains_type" == "array" ]]; then
            local contains_len
            contains_len=$(jq ".testCases[$i].expectedOutput.contains | length" "$file")
            if [[ "$contains_len" -eq 0 ]]; then
                log_warn "Case '$case_id': 'contains' array is empty (should have at least one value or be removed)"
            fi
        fi

        # Check notContains array if present
        local not_contains_type
        not_contains_type=$(jq -r ".testCases[$i].expectedOutput.notContains | type" "$file" 2>/dev/null || echo "null")
        if [[ "$not_contains_type" == "array" ]]; then
            local not_contains_len
            not_contains_len=$(jq ".testCases[$i].expectedOutput.notContains | length" "$file")
            if [[ "$not_contains_len" -eq 0 ]]; then
                log_warn "Case '$case_id': 'notContains' array is empty (should have at least one value or be removed)"
            fi
        fi
    done

    log_pass "Assertion arrays validated"
    return 0
}

# Validate status values are from allowed set
validate_status_values() {
    local file="$1"
    local skill_name
    skill_name=$(jq -r '.name' "$file")

    # Define allowed status values per skill type
    local allowed_statuses
    case "$skill_name" in
        grounded-query)
            allowed_statuses=("SUPPORTED" "PARTIAL" "NOT FOUND")
            ;;
        local-repo-check|github-repo-check|project-status)
            allowed_statuses=("Shipped" "Complete" "In Progress" "Planned" "Discussed" "Unknown")
            ;;
        *)
            # Unknown skill, skip status validation
            log_info "Skipping status validation for unknown skill type"
            return 0
            ;;
    esac

    local has_error=0
    local case_count
    case_count=$(jq '.testCases | length' "$file")

    for ((i=0; i<case_count; i++)); do
        local case_id
        case_id=$(jq -r ".testCases[$i].id" "$file")

        # Check status field if present (can be string or array)
        local status_type
        status_type=$(jq -r ".testCases[$i].expectedOutput.status | type" "$file" 2>/dev/null || echo "null")

        if [[ "$status_type" == "string" ]]; then
            local status
            status=$(jq -r ".testCases[$i].expectedOutput.status" "$file")
            local valid=0
            for allowed in "${allowed_statuses[@]}"; do
                if [[ "$status" == "$allowed" ]]; then
                    valid=1
                    break
                fi
            done
            if [[ $valid -eq 0 ]]; then
                log_warn "Case '$case_id': Unknown status value '$status'"
            fi
        elif [[ "$status_type" == "array" ]]; then
            # Status is an array of possible values - check each
            local arr_len
            arr_len=$(jq ".testCases[$i].expectedOutput.status | length" "$file")
            for ((j=0; j<arr_len; j++)); do
                local status
                status=$(jq -r ".testCases[$i].expectedOutput.status[$j]" "$file")
                local valid=0
                for allowed in "${allowed_statuses[@]}"; do
                    if [[ "$status" == "$allowed" ]]; then
                        valid=1
                        break
                    fi
                done
                if [[ $valid -eq 0 ]]; then
                    log_warn "Case '$case_id': Unknown status value '$status' in array"
                fi
            done
        fi

        # Also check evidenceStatus for grounded-query
        if [[ "$skill_name" == "grounded-query" ]]; then
            local evidence_status
            evidence_status=$(jq -r ".testCases[$i].expectedOutput.evidenceStatus // \"\"" "$file")
            if [[ -n "$evidence_status" && "$evidence_status" != "null" ]]; then
                local valid=0
                for allowed in "${allowed_statuses[@]}"; do
                    if [[ "$evidence_status" == "$allowed" ]]; then
                        valid=1
                        break
                    fi
                done
                if [[ $valid -eq 0 ]]; then
                    log_warn "Case '$case_id': Unknown evidenceStatus value '$evidence_status'"
                fi
            fi
        fi
    done

    log_pass "Status values validated"
    return 0
}

# Validate a single skill's evaluation file
validate_skill() {
    local skill_name="$1"
    local eval_file="$SKILLS_DIR/$skill_name/evaluations/evaluation.json"

    echo ""
    echo -e "${BLUE}=== Validating: $skill_name ===${NC}"

    if [[ ! -f "$eval_file" ]]; then
        log_fail "evaluation.json not found at $eval_file"
        return 1
    fi

    local skill_errors=0

    validate_json_syntax "$eval_file" || ((skill_errors++))

    # Only continue if JSON is valid
    if [[ $skill_errors -eq 0 ]]; then
        validate_top_level_fields "$eval_file" || ((skill_errors++))
        validate_test_case_fields "$eval_file" || ((skill_errors++))
        validate_unique_ids "$eval_file" || ((skill_errors++))
        validate_assertion_arrays "$eval_file" || true  # Warnings only
        validate_status_values "$eval_file" || true      # Warnings only
    fi

    return $skill_errors
}

# Main execution
main() {
    local skill_filter="${1:-}"
    local total_errors=0

    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   entourage-plugin Evaluation Validator            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"

    # Check plugin.json exists
    if [[ ! -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ]]; then
        echo -e "${RED}Error: Not a valid Claude Code plugin (missing .claude-plugin/plugin.json)${NC}"
        exit 1
    fi

    # Find all skills with evaluations
    local skills=()
    for skill_dir in "$SKILLS_DIR"/*/; do
        local skill_name
        skill_name=$(basename "$skill_dir")

        # Skip if filter specified and doesn't match
        if [[ -n "$skill_filter" && "$skill_name" != "$skill_filter" ]]; then
            continue
        fi

        # Only include skills with evaluation files
        if [[ -d "$skill_dir/evaluations" ]]; then
            skills+=("$skill_name")
        fi
    done

    if [[ ${#skills[@]} -eq 0 ]]; then
        if [[ -n "$skill_filter" ]]; then
            echo -e "${RED}Error: No skill found matching '$skill_filter'${NC}"
        else
            echo -e "${YELLOW}Warning: No skills with evaluations/ directory found${NC}"
        fi
        exit 1
    fi

    # Validate each skill
    for skill in "${skills[@]}"; do
        validate_skill "$skill" || ((total_errors++))
    done

    # Print summary
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "Summary:"
    echo -e "  Skills validated: ${#skills[@]}"
    echo -e "  ${GREEN}Passed:${NC} $PASS_COUNT"
    echo -e "  ${RED}Failed:${NC} $FAIL_COUNT"
    echo -e "  ${YELLOW}Warnings:${NC} $WARN_COUNT"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"

    if [[ $FAIL_COUNT -gt 0 ]]; then
        echo -e "${RED}Validation failed with $FAIL_COUNT error(s)${NC}"
        exit 1
    else
        echo -e "${GREEN}All validations passed!${NC}"
        exit 0
    fi
}

main "$@"
