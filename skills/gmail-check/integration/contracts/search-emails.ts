import { z } from 'zod';

/**
 * Schema for gmail_search_emails tool output.
 *
 * This defines the contract that any Gmail MCP must conform to
 * for the /gmail-check skill to work correctly.
 */
export const SearchEmailResultSchema = z.object({
  /** Message ID - used for gmail_read_email calls */
  id: z.string(),

  /** Thread ID - used for grouping related emails */
  threadId: z.string(),

  /** Sender email/name - displayed in evidence table */
  from: z.string(),

  /** Email subject - displayed in evidence table */
  subject: z.string(),

  /** Send date in ISO 8601 format - used for sorting and display */
  date: z.string(),

  /** Preview text (~200 chars) - used for evidence classification */
  snippet: z.string(),

  /** Gmail labels - used for filtering (optional) */
  labels: z.array(z.string()).optional(),
});

export type SearchEmailResult = z.infer<typeof SearchEmailResultSchema>;

/**
 * Schema for the full response from gmail_search_emails.
 * Returns an array of search results.
 */
export const SearchEmailsResponseSchema = z.array(SearchEmailResultSchema);

export type SearchEmailsResponse = z.infer<typeof SearchEmailsResponseSchema>;
