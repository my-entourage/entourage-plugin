/**
 * Gmail MCP Contract Schemas
 *
 * These Zod schemas define the contract that any Gmail MCP server must
 * conform to for compatibility with the /gmail-check skill.
 *
 * The skill is MCP-agnostic - it references tools by name, not server name.
 * Any MCP that provides gmail_search_emails, gmail_read_email, and
 * gmail_list_labels tools with outputs matching these schemas will work.
 *
 * @example
 * ```typescript
 * import { SearchEmailResultSchema } from './contracts';
 *
 * // Validate MCP response
 * const result = SearchEmailResultSchema.safeParse(mcpResponse);
 * if (!result.success) {
 *   console.error('MCP response does not match contract:', result.error);
 * }
 * ```
 */

// Search emails tool
export {
  SearchEmailResultSchema,
  SearchEmailsResponseSchema,
  type SearchEmailResult,
  type SearchEmailsResponse,
} from './search-emails';

// Read email tool
export {
  AttachmentSchema,
  EmailBodySchema,
  EmailContentSchema,
  type Attachment,
  type EmailBody,
  type EmailContent,
} from './read-email';

// List labels tool
export {
  LabelSchema,
  ListLabelsResponseSchema,
  type Label,
  type ListLabelsResponse,
} from './list-labels';
