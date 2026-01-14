#!/bin/bash
#
# graders.sh - Output grading helpers for entourage-plugin evaluations
#
# This library provides functions for validating Claude's output against
# expected criteria defined in evaluation.json files.
#
# Usage:
#   source tests/lib/graders.sh
#   check_contains "$output" "expected text"
#   check_not_contains "$output" "forbidden text"
#
# All functions return 0 on success, 1 on failure

# Check if output contains expected string (case-insensitive)
# Usage: check_contains "$output" "$expected"
check_contains() {
    local output="$1"
    local expected="$2"

    if echo "$output" | grep -qi "$expected"; then
        return 0
    else
        return 1
    fi
}

# Check if output does NOT contain forbidden string (case-insensitive)
# Usage: check_not_contains "$output" "$forbidden"
check_not_contains() {
    local output="$1"
    local forbidden="$2"

    if echo "$output" | grep -qi "$forbidden"; then
        return 1
    else
        return 0
    fi
}

# Check if output contains a markdown table (|...|...|)
# Usage: check_has_table "$output"
check_has_table() {
    local output="$1"

    # Look for at least one row with pipe separators
    if echo "$output" | grep -qE '\|.*\|.*\|'; then
        return 0
    else
        return 1
    fi
}

# Check if output ends with a markdown table
# Usage: check_ends_with_table "$output"
check_ends_with_table() {
    local output="$1"

    # Get last non-empty lines and check for table pattern
    local last_content
    last_content=$(echo "$output" | sed '/^[[:space:]]*$/d' | tail -5)

    if echo "$last_content" | grep -qE '\|.*\|.*\|'; then
        return 0
    else
        return 1
    fi
}

# Check if output has a table with specific headers
# Usage: check_table_headers "$output" "Header1" "Header2" "Header3"
check_table_headers() {
    local output="$1"
    shift
    local headers=("$@")

    # Find the header row (first row with pipes)
    local header_row
    header_row=$(echo "$output" | grep -E '^\|.*\|' | head -1)

    if [[ -z "$header_row" ]]; then
        return 1
    fi

    # Check each expected header
    for header in "${headers[@]}"; do
        if ! echo "$header_row" | grep -qi "$header"; then
            return 1
        fi
    done

    return 0
}

# Check if table has at least N rows (excluding header and separator)
# Usage: check_table_rows "$output" 3
check_table_rows() {
    local output="$1"
    local min_rows="$2"

    # Count rows with pipes, excluding separator row (|---|---|)
    local row_count
    row_count=$(echo "$output" | grep -E '^\|.*\|' | grep -v -E '^\|[-:| ]+\|$' | wc -l | tr -d ' ')

    # Subtract 1 for header row
    local data_rows=$((row_count - 1))

    if [[ $data_rows -ge $min_rows ]]; then
        return 0
    else
        return 1
    fi
}

# Check status field value matches expected
# Usage: check_status "$output" "Complete"
# Looks for patterns like "Status: Complete" or "**Status:** Complete"
check_status() {
    local output="$1"
    local expected_status="$2"

    # Check various status formats (using POSIX character classes, not \s)
    # Matches: "Status: Complete", "**Status**: Complete", "**Status:** Complete"
    if echo "$output" | grep -qiE "(status[: ]*\**[: ]*$expected_status|\"status\":[[:space:]]*\"$expected_status\")"; then
        return 0
    fi

    # Also check in table format
    if echo "$output" | grep -qiE "\|[^|]*$expected_status[^|]*\|"; then
        return 0
    fi

    return 1
}

# Check confidence level matches expected
# Usage: check_confidence "$output" "High"
check_confidence() {
    local output="$1"
    local expected_confidence="$2"

    # Check various confidence formats:
    # - "confidence: High" or "**confidence:** High"
    # - "Confidence Level: High"
    # - In table format: "| Complete | High |"
    # - JSON: "confidence": "High"
    if echo "$output" | grep -qiE "(confidence[:\s]*\**\s*$expected_confidence|Confidence Level[:\s]*\**\s*$expected_confidence|\"confidence\":\s*\"$expected_confidence\")"; then
        return 0
    fi

    # Also check in table format (column after Status)
    if echo "$output" | grep -qiE "\|[^|]*\|[^|]*$expected_confidence[^|]*\|"; then
        return 0
    fi

    return 1
}

# Check evidence status for grounded-query skill
# Usage: check_evidence_status "$output" "SUPPORTED"
check_evidence_status() {
    local output="$1"
    local expected_status="$2"

    # Look for evidence status in various formats
    if echo "$output" | grep -qi "$expected_status"; then
        return 0
    fi

    return 1
}

# Check if output has a source reference (file path or URL)
# Usage: check_has_source "$output"
check_has_source() {
    local output="$1"

    # Check for file paths or source references
    if echo "$output" | grep -qE '(\.md|\.txt|\.json|transcripts/|data/|https?://|Source:|source:)'; then
        return 0
    fi

    return 1
}

# Validate all contains assertions from an array
# Usage: validate_contains "$output" '["text1", "text2"]'
validate_contains() {
    local output="$1"
    local contains_json="$2"
    local failures=0

    # Parse JSON array and check each item
    local items
    items=$(echo "$contains_json" | jq -r '.[]' 2>/dev/null)

    if [[ -z "$items" ]]; then
        return 0  # No items to check
    fi

    while IFS= read -r item; do
        if [[ -n "$item" ]] && ! check_contains "$output" "$item"; then
            echo "  Missing expected: '$item'" >&2
            ((failures++))
        fi
    done <<< "$items"

    return $failures
}

# Validate all notContains assertions from an array
# Usage: validate_not_contains "$output" '["forbidden1", "forbidden2"]'
validate_not_contains() {
    local output="$1"
    local not_contains_json="$2"
    local failures=0

    # Parse JSON array and check each item
    local items
    items=$(echo "$not_contains_json" | jq -r '.[]' 2>/dev/null)

    if [[ -z "$items" ]]; then
        return 0  # No items to check
    fi

    while IFS= read -r item; do
        if [[ -n "$item" ]] && ! check_not_contains "$output" "$item"; then
            echo "  Found forbidden: '$item'" >&2
            ((failures++))
        fi
    done <<< "$items"

    return $failures
}

# Compare output against a golden file
# Usage: compare_golden "$output" "/path/to/golden.md"
# Returns 0 if similar enough, 1 if significantly different
compare_golden() {
    local output="$1"
    local golden_file="$2"

    if [[ ! -f "$golden_file" ]]; then
        echo "  Golden file not found: $golden_file" >&2
        return 2  # File not found (different from mismatch)
    fi

    local golden_content
    golden_content=$(cat "$golden_file")

    # For now, do a simple diff
    # Future: could use semantic similarity or LLM-based comparison
    local diff_result
    diff_result=$(diff <(echo "$output") <(echo "$golden_content") 2>/dev/null || true)

    if [[ -z "$diff_result" ]]; then
        return 0  # Exact match
    fi

    # Calculate similarity (very basic - count matching lines)
    local output_lines golden_lines matching_lines
    output_lines=$(echo "$output" | wc -l | tr -d ' ')
    golden_lines=$(echo "$golden_content" | wc -l | tr -d ' ')
    matching_lines=$(diff <(echo "$output") <(echo "$golden_content") 2>/dev/null | grep -c '^[<>]' || true)

    # If more than 50% different, fail
    local diff_ratio
    if [[ $golden_lines -gt 0 ]]; then
        diff_ratio=$((matching_lines * 100 / golden_lines))
        if [[ $diff_ratio -gt 50 ]]; then
            echo "  Output differs significantly from golden (${diff_ratio}% changed)" >&2
            return 1
        fi
    fi

    return 0
}

# Grade a single test case output against expected criteria
# Usage: grade_test_case "$output" "$expected_output_json"
# Returns: number of failed assertions
grade_test_case() {
    local output="$1"
    local expected_json="$2"
    local failures=0

    # Check contains
    local contains
    contains=$(echo "$expected_json" | jq -c '.contains // []')
    if [[ "$contains" != "[]" ]]; then
        validate_contains "$output" "$contains" || ((failures+=$?))
    fi

    # Check notContains
    local not_contains
    not_contains=$(echo "$expected_json" | jq -c '.notContains // []')
    if [[ "$not_contains" != "[]" ]]; then
        validate_not_contains "$output" "$not_contains" || ((failures+=$?))
    fi

    # Check status if specified
    local status
    status=$(echo "$expected_json" | jq -r '.status // empty')
    if [[ -n "$status" && "$status" != "null" ]]; then
        # Handle array of acceptable statuses
        local status_type
        status_type=$(echo "$expected_json" | jq -r '.status | type')
        if [[ "$status_type" == "array" ]]; then
            local found=0
            while IFS= read -r s; do
                if check_status "$output" "$s"; then
                    found=1
                    break
                fi
            done < <(echo "$expected_json" | jq -r '.status[]')
            if [[ $found -eq 0 ]]; then
                echo "  Status mismatch: expected one of $(echo "$expected_json" | jq -c '.status')" >&2
                ((failures++))
            fi
        else
            if ! check_status "$output" "$status"; then
                echo "  Status mismatch: expected '$status'" >&2
                ((failures++))
            fi
        fi
    fi

    # Check confidence if specified
    local confidence
    confidence=$(echo "$expected_json" | jq -r '.confidence // empty')
    if [[ -n "$confidence" && "$confidence" != "null" ]]; then
        # Handle array of acceptable confidence levels
        local confidence_type
        confidence_type=$(echo "$expected_json" | jq -r '.confidence | type')
        if [[ "$confidence_type" == "array" ]]; then
            local found=0
            while IFS= read -r c; do
                if check_confidence "$output" "$c"; then
                    found=1
                    break
                fi
            done < <(echo "$expected_json" | jq -r '.confidence[]')
            if [[ $found -eq 0 ]]; then
                echo "  Confidence mismatch: expected one of $(echo "$expected_json" | jq -c '.confidence')" >&2
                ((failures++))
            fi
        else
            if ! check_confidence "$output" "$confidence"; then
                echo "  Confidence mismatch: expected '$confidence'" >&2
                ((failures++))
            fi
        fi
    fi

    # Check evidenceStatus if specified (grounded-query)
    local evidence_status
    evidence_status=$(echo "$expected_json" | jq -r '.evidenceStatus // empty')
    if [[ -n "$evidence_status" && "$evidence_status" != "null" ]]; then
        if ! check_evidence_status "$output" "$evidence_status"; then
            echo "  Evidence status mismatch: expected '$evidence_status'" >&2
            ((failures++))
        fi
    fi

    # Check hasSource if specified
    local has_source
    has_source=$(echo "$expected_json" | jq -r '.hasSource // empty')
    if [[ "$has_source" == "true" ]]; then
        if ! check_has_source "$output"; then
            echo "  Expected source reference not found" >&2
            ((failures++))
        fi
    fi

    # Check format requirements
    local format
    format=$(echo "$expected_json" | jq -r '.format // empty')
    if [[ "$format" == "table" || "$format" == "markdown" ]]; then
        if ! check_has_table "$output"; then
            echo "  Expected table format not found" >&2
            ((failures++))
        fi
    fi

    # Check endsWithTable
    local ends_with_table
    ends_with_table=$(echo "$expected_json" | jq -r '.endsWithTable // empty')
    if [[ "$ends_with_table" == "true" ]]; then
        if ! check_ends_with_table "$output"; then
            echo "  Expected output to end with table" >&2
            ((failures++))
        fi
    fi

    # Check tableHeaders if specified
    local table_headers
    table_headers=$(echo "$expected_json" | jq -c '.tableHeaders // empty')
    if [[ -n "$table_headers" && "$table_headers" != "null" && "$table_headers" != "" ]]; then
        local headers_array=()
        while IFS= read -r header; do
            headers_array+=("$header")
        done < <(echo "$table_headers" | jq -r '.[]')

        if ! check_table_headers "$output" "${headers_array[@]}"; then
            echo "  Table headers mismatch: expected $table_headers" >&2
            ((failures++))
        fi
    fi

    return $failures
}

# Export functions for use in other scripts
export -f check_contains
export -f check_not_contains
export -f check_has_table
export -f check_ends_with_table
export -f check_table_headers
export -f check_table_rows
export -f check_status
export -f check_confidence
export -f check_evidence_status
export -f check_has_source
export -f validate_contains
export -f validate_not_contains
export -f compare_golden
export -f grade_test_case
