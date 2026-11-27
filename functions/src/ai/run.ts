import {HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {createHash} from "crypto";
import {WORKERS} from "./registry";
import {AnyWorker, ClaudeClient} from "./worker";

/** AI requests one account may make per UTC day, across all workers. */
export const DAILY_AI_LIMIT = 60;

export interface RunDeps {
  client: () => ClaudeClient;
  /** False when AI is switched off in Firestore (_config/ai.enabled). */
  isEnabled: () => Promise<boolean>;
  consumeQuota: (uid: string, cost: number) => Promise<void>;
  log: (entry: Record<string, unknown>) => void;
  workers?: Readonly<Record<string, AnyWorker>>;
}

function hashed(uid: string): string {
  return createHash("sha256").update(uid).digest("hex");
}

/**
 * Runs one named worker for a signed-in account: checks the kill switch,
 * input and quota, then calls the worker. Claude API failures become
 * "unavailable" so the app falls back to its own search.
 */
export async function runWorker(uid: string, data: unknown, deps: RunDeps) {
  const body = (data && typeof data === "object" ? data : {}) as Record<string, unknown>;
  const name = typeof body.worker === "string" ? body.worker : "";
  const worker = (deps.workers ?? WORKERS)[name];
  if (!worker) throw new HttpsError("invalid-argument", "Unknown AI worker");
  const input = worker.parseInput(body.input);
  if (!await deps.isEnabled()) {
    throw new HttpsError("unavailable", "AI is turned off right now");
  }
  await deps.consumeQuota(uid, worker.quotaCost);
  const started = Date.now();
  try {
    const result = await worker.run(input, {
      client: deps.client(),
      logUsage: (usage) => deps.log({worker: name, account: hashed(uid), ...usage}),
    });
    deps.log({worker: name, account: hashed(uid), ms: Date.now() - started, ok: true});
    return {worker: name, result};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    deps.log({
      worker: name,
      account: hashed(uid),
      ms: Date.now() - started,
      ok: false,
      error: error instanceof Error ? error.name : "unknown",
    });
    throw new HttpsError("unavailable", "AI couldn't answer right now");
  }
}

/** Firestore-backed daily quota, one document per account. Fails closed. */
export async function consumeAiQuota(
  uid: string,
  cost: number,
  firestore = admin.firestore(),
  now = new Date(),
) {
  const day = now.toISOString().slice(0, 10);
  const ref = firestore.collection("_aiQuotas").doc(hashed(uid));
  await firestore.runTransaction(async (transaction) => {
    const previous = (await transaction.get(ref)).data();
    const used = previous?.day === day ? Number(previous.used) || 0 : 0;
    if (used + cost > DAILY_AI_LIMIT) {
      throw new HttpsError("resource-exhausted", "Daily AI limit reached; try again tomorrow");
    }
    transaction.set(ref, {day, used: used + cost});
  });
}

/** AI is on unless _config/ai has enabled: false. Read errors keep it off. */
export async function aiEnabled(firestore = admin.firestore()): Promise<boolean> {
  try {
    const snapshot = await firestore.collection("_config").doc("ai").get();
    return snapshot.data()?.enabled !== false;
  } catch {
    return false;
  }
}
