/**
 * Gmail MCP Contract Validator
 *
 * This module provides functions to validate that a Gmail MCP server
 * conforms to the expected contract schemas.
 *
 * Usage:
 * 1. Configure a Gmail MCP in your Claude settings
 * 2. Run the contract validator in a Claude session
 * 3. Check that all tools pass schema validation
 *
 * Note: This validator requires MCP tools to be available, which means
 * it must be run in an interactive Claude session, not in automated tests.
 */

import {
  SearchEmailsResponseSchema,
  EmailContentSchema,
  ListLabelsResponseSchema,
  type SearchEmailsResponse,
  type EmailContent,
  type ListLabelsResponse,
} from './contracts';

export interface ValidationResult {
  tool: string;
  pass: boolean;
  errors: string[];
  response?: unknown;
}

export interface ContractValidationReport {
  timestamp: string;
  allPassed: boolean;
  results: {
    search_emails: ValidationResult;
    read_email: ValidationResult;
    list_labels: ValidationResult;
  };
}

/**
 * Validates the gmail_search_emails tool response against the contract schema.
 */
export function validateSearchEmails(response: unknown): ValidationResult {
  const result = SearchEmailsResponseSchema.safeParse(response);

  return {
    tool: 'gmail_search_emails',
    pass: result.success,
    errors: result.success ? [] : result.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`),
    response: result.success ? result.data : undefined,
  };
}

/**
 * Validates the gmail_read_email tool response against the contract schema.
 */
export function validateReadEmail(response: unknown): ValidationResult {
  const result = EmailContentSchema.safeParse(response);

  return {
    tool: 'gmail_read_email',
    pass: result.success,
    errors: result.success ? [] : result.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`),
    response: result.success ? result.data : undefined,
  };
}

/**
 * Validates the gmail_list_labels tool response against the contract schema.
 */
export function validateListLabels(response: unknown): ValidationResult {
  const result = ListLabelsResponseSchema.safeParse(response);

  return {
    tool: 'gmail_list_labels',
    pass: result.success,
    errors: result.success ? [] : result.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`),
    response: result.success ? result.data : undefined,
  };
}

/**
 * Formats a validation report as a markdown table for display.
 */
export function formatValidationReport(report: ContractValidationReport): string {
  const lines: string[] = [
    '# Gmail MCP Contract Validation Report',
    '',
    `**Timestamp:** ${report.timestamp}`,
    `**Overall Status:** ${report.allPassed ? 'PASS' : 'FAIL'}`,
    '',
    '## Results',
    '',
    '| Tool | Status | Errors |',
    '|------|--------|--------|',
  ];

  for (const [, result] of Object.entries(report.results)) {
    const status = result.pass ? 'PASS' : 'FAIL';
    const errors = result.errors.length > 0 ? result.errors.join('; ') : '-';
    lines.push(`| ${result.tool} | ${status} | ${errors} |`);
  }

  return lines.join('\n');
}

/**
 * Example usage instructions for manual validation.
 *
 * Since MCP tools aren't available in automated tests, this provides
 * instructions for validating in an interactive Claude session.
 */
export const VALIDATION_INSTRUCTIONS = `
# Manual Contract Validation

To validate a Gmail MCP against the contract:

1. **Configure your Gmail MCP** in Claude settings (~/.claude.json or .mcp.json)

2. **Start a Claude session** with MCP access

3. **Run these commands** to get tool responses:
   - \`gmail_list_labels\` (no params)
   - \`gmail_search_emails\` with \`{ query: "test", maxResults: 5 }\`
   - \`gmail_read_email\` with a message ID from search results

4. **Validate responses** against the schemas in this directory

5. **Check for**:
   - All required fields present
   - Correct field types (string, number, array)
   - Date format is ISO 8601
   - Optional fields handled correctly

If validation fails, check the MCP implementation against the schema definitions.
`;
