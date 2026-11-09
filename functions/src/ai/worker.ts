import Anthropic from "@anthropic-ai/sdk";
import {zodOutputFormat} from "@anthropic-ai/sdk/helpers/zod";
import {z} from "zod";

/** The part of the Anthropic client a worker uses; tests pass a fake. */
export type ClaudeClient = Pick<Anthropic, "messages">;

/** What a worker gets for one run. */
export interface WorkerContext {
  client: ClaudeClient;
  /** Records token use for cost tracking; never includes user content. */
  logUsage(usage: Record<string, unknown>): void;
}

/**
 * One AI worker: a single job the app can ask for, such as exercise search
 * or program building. Add a worker by writing one of these and listing it
 * in registry.ts. Workers must check model output against app data before
 * returning it; the app trusts what a worker returns.
 */
export interface AiWorker<Input, Output> {
  name: string;
  /** Requests charged against the account's daily AI quota. */
  quotaCost: number;
  /** Validates untrusted app input; throws HttpsError("invalid-argument"). */
  parseInput(data: unknown): Input;
  run(input: Input, context: WorkerContext): Promise<Output>;
}

export type AnyWorker = AiWorker<unknown, unknown>;

export interface StructuredCall<Schema extends z.ZodType> {
  model: string;
  effort: "low" | "medium" | "high" | "xhigh" | "max";
  maxTokens: number;
  /** Stable instructions first, then a cached block (e.g. a catalog). */
  system: Anthropic.TextBlockParam[];
  user: string;
  schema: Schema;
}

/**
 * One Claude call that must return JSON matching [schema]. Returns null
 * when Claude declines, runs out of tokens or the reply doesn't parse, so
 * workers can degrade instead of failing the request.
 */
export async function askStructured<Schema extends z.ZodType>(
  context: WorkerContext,
  call: StructuredCall<Schema>,
): Promise<z.infer<Schema> | null> {
  const response = await context.client.messages.parse({
    model: call.model,
    max_tokens: call.maxTokens,
    system: call.system,
    messages: [{role: "user", content: call.user}],
    output_config: {effort: call.effort, format: zodOutputFormat(call.schema)},
  });
  context.logUsage({
    model: call.model,
    stopReason: response.stop_reason,
    inputTokens: response.usage.input_tokens,
    outputTokens: response.usage.output_tokens,
    cacheReadTokens: response.usage.cache_read_input_tokens ?? 0,
    cacheWriteTokens: response.usage.cache_creation_input_tokens ?? 0,
    refusalCategory: response.stop_reason === "refusal" ?
      response.stop_details?.category ?? null : undefined,
  });
  if (response.stop_reason !== "end_turn") return null;
  return response.parsed_output ?? null;
}
