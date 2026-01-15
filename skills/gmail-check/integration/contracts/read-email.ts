import { z } from 'zod';

/**
 * Schema for email attachment metadata.
 */
export const AttachmentSchema = z.object({
  /** Attachment filename */
  filename: z.string(),

  /** MIME type (e.g., "application/pdf") */
  mimeType: z.string(),

  /** Size in bytes */
  size: z.number(),
});

export type Attachment = z.infer<typeof AttachmentSchema>;

/**
 * Schema for email body content.
 */
export const EmailBodySchema = z.object({
  /** Plain text body - always present */
  text: z.string(),

  /** HTML body - present if email has HTML version */
  html: z.string().optional(),
});

export type EmailBody = z.infer<typeof EmailBodySchema>;

/**
 * Schema for gmail_read_email tool output.
 *
 * This defines the contract that any Gmail MCP must conform to
 * for reading full email content.
 */
export const EmailContentSchema = z.object({
  /** Message ID */
  id: z.string(),

  /** Thread ID for grouping */
  threadId: z.string(),

  /** Sender email/name */
  from: z.string(),

  /** List of recipient emails */
  to: z.array(z.string()),

  /** List of CC recipients (optional) */
  cc: z.array(z.string()).optional(),

  /** Email subject */
  subject: z.string(),

  /** Send date in ISO 8601 format */
  date: z.string(),

  /** Email body content */
  body: EmailBodySchema,

  /** Attachment metadata (optional) */
  attachments: z.array(AttachmentSchema).optional(),
});

export type EmailContent = z.infer<typeof EmailContentSchema>;
