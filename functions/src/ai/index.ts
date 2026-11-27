import Anthropic from "@anthropic-ai/sdk";
import {onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {requireUser} from "../security";
import {aiEnabled, consumeAiQuota, runWorker} from "./run";

const anthropicKey = defineSecret("ANTHROPIC_API_KEY");
let client: Anthropic | undefined;

/**
 * The app's single entry point for AI workers:
 * runAiWorker({worker: "exerciseSearch", input: {query: "pec deck"}}).
 */
export const runAiWorker = onCall(
  {secrets: [anthropicKey], timeoutSeconds: 60, memory: "512MiB"},
  async (request) => {
    const caller = requireUser(request);
    return runWorker(caller.uid, request.data, {
      client: () => (client ??= new Anthropic({apiKey: anthropicKey.value(), maxRetries: 1, timeout: 45_000})),
      isEnabled: () => aiEnabled(),
      consumeQuota: (uid, cost) => consumeAiQuota(uid, cost),
      log: (entry) => console.log(JSON.stringify({type: "ai_worker", ...entry})),
    });
  },
);
