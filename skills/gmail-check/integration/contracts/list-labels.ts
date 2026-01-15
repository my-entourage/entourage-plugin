import { z } from 'zod';

/**
 * Schema for gmail_list_labels tool output.
 *
 * This defines the contract that any Gmail MCP must conform to
 * for listing available Gmail labels.
 */
export const LabelSchema = z.object({
  /** Label ID - used for filtering in search queries */
  id: z.string(),

  /** Label display name */
  name: z.string(),

  /** Label type: system (built-in) or user (custom) */
  type: z.enum(['system', 'user']).optional(),

  /** Number of messages with this label (optional) */
  messageCount: z.number().optional(),
});

export type Label = z.infer<typeof LabelSchema>;

/**
 * Schema for the full response from gmail_list_labels.
 * Returns an array of labels.
 */
export const ListLabelsResponseSchema = z.array(LabelSchema);

export type ListLabelsResponse = z.infer<typeof ListLabelsResponseSchema>;
