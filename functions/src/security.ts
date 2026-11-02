import {CallableRequest, HttpsError, Request} from "firebase-functions/v2/https";
import {Response} from "express";
import * as admin from "firebase-admin";
import {createHash} from "crypto";

/** Callable framework verifies the token signature before supplying auth. */
export function requireUser(request: CallableRequest) {
  if (!request.auth || request.auth.token.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("unauthenticated", "Sign in with a non-anonymous account");
  }
  return request.auth;
}

type VerifyToken = (token: string, checkRevoked: boolean) => Promise<admin.auth.DecodedIdToken>;
const verifyToken: VerifyToken = (token, checkRevoked) =>
  admin.auth().verifyIdToken(token, checkRevoked);

/** Admin mutations also reject revoked sessions and disabled users. */
export async function verifyAdminHeader(header: string | undefined, verify: VerifyToken = verifyToken) {
  const match = /^Bearer ([^\s]+)$/i.exec(header ?? "");
  if (!match) throw new HttpsError("unauthenticated", "Firebase ID token required");
  let token: admin.auth.DecodedIdToken;
  try {
    token = await verify(match[1], true);
  } catch {
    throw new HttpsError("unauthenticated", "Invalid or revoked Firebase ID token");
  }
  if (token.firebase?.sign_in_provider === "anonymous" || token.admin !== true) {
    throw new HttpsError("permission-denied", "Administrator access required");
  }
  return token;
}

export async function requireAdmin(request: CallableRequest) {
  const caller = requireUser(request);
  if (caller.token.admin !== true) {
    throw new HttpsError("permission-denied", "Administrator access required");
  }
  return verifyAdminHeader(request.rawRequest.headers.authorization);
}

export async function authorizeAdminHttp(req: Request, res: Response): Promise<boolean> {
  res.set("Cache-Control", "no-store");
  if (req.method !== "POST") {
    res.set("Allow", "POST");
    res.status(405).json({error: "Use POST"});
    return false;
  }
  try {
    await verifyAdminHeader(req.headers.authorization);
    return true;
  } catch (error) {
    const forbidden = error instanceof HttpsError && error.code === "permission-denied";
    res.status(forbidden ? 403 : 401).json({error: forbidden ? "Administrator access required" : "Valid Firebase ID token required"});
    return false;
  }
}

export function inputObject(data: unknown): Record<string, unknown> {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "Expected an object");
  }
  return data as Record<string, unknown>;
}

export function searchInput(data: unknown) {
  const value = inputObject(data);
  const text = (field: string): string | undefined => {
    if (value[field] === undefined) return undefined;
    if (typeof value[field] !== "string" || (value[field] as string).length > 100) {
      throw new HttpsError("invalid-argument", `${field} must be at most 100 characters`);
    }
    return (value[field] as string).trim();
  };
  const limit = value.limit === undefined ? 30 : value.limit;
  if (typeof limit !== "number" || !Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new HttpsError("invalid-argument", "limit must be an integer from 1 to 100");
  }
  return {query: text("query"), bodyPart: text("bodyPart"), equipment: text("equipment"), limit};
}

export function exerciseIdInput(data: unknown, field: string, gymFit = false): string {
  const id = inputObject(data)[field];
  if (typeof id !== "string" || id.length > 128 ||
      !(gymFit ? /^gymfit_[A-Za-z0-9_-]+$/ : /^[A-Za-z0-9_-]+$/).test(id)) {
    throw new HttpsError("invalid-argument", `Invalid ${field}`);
  }
  return id;
}

/** Shared per-account quota across paid exercise routes; one document per UID.
 * Transactions serialize concurrent instances. Database errors fail closed.
 * Firestore rules must deny client access to _endpointQuotas (default deny does).
 */
export async function consumeExerciseQuota(uid: string, firestore = admin.firestore(), now = Date.now()) {
  const key = createHash("sha256").update(uid).digest("hex");
  const ref = firestore.collection("_endpointQuotas").doc(key);
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const previous = snapshot.data();
    const sameWindow = previous && now >= previous.startedAt && now - previous.startedAt < 60_000;
    const count = sameWindow ? previous.count : 0;
    if (count >= 30) {
      throw new HttpsError("resource-exhausted", "Too many exercise requests; try again in a minute");
    }
    transaction.set(ref, {startedAt: sameWindow ? previous.startedAt : now, count: count + 1});
  });
}
