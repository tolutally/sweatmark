import {onCall, HttpsError, CallableRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {createHash} from "node:crypto";
import {requireUser} from "./security";

/** How recently the caller must have signed in to delete their account. */
export const RECENT_SIGN_IN_SECONDS = 10 * 60;

/** What deleting an account touches; tests pass fakes. */
export interface AccountDeps {
  /** Deletes users/{uid} and every subcollection under it. */
  deleteUserTree(uid: string): Promise<void>;
  /** Deletes top-level docs in [collection] whose userId is [uid]. */
  deleteOwned(collection: string, uid: string): Promise<void>;
  deleteDoc(path: string): Promise<void>;
  /** Deletes stored files under users/{uid}/. */
  deleteFiles(prefix: string): Promise<void>;
  deleteAuthUser(uid: string): Promise<void>;
}

/** Collections outside users/{uid} that hold the account's documents. */
export const OWNED_COLLECTIONS = ["templates", "template_collections"];

/**
 * Deletes everything SweatMark stores for [uid], then the sign-in account.
 * Data goes first so a failure never leaves data without an owner who can
 * retry.
 */
export async function deleteAccountData(uid: string, deps: AccountDeps): Promise<void> {
  await deps.deleteUserTree(uid);
  for (const collection of OWNED_COLLECTIONS) {
    await deps.deleteOwned(collection, uid);
  }
  await deps.deleteDoc(`_aiQuotas/${createHash("sha256").update(uid).digest("hex")}`);
  await deps.deleteFiles(`users/${uid}/`);
  await deps.deleteAuthUser(uid);
}

/** Requires a sign-in within [RECENT_SIGN_IN_SECONDS], like Firebase does. */
export function requireRecentSignIn(request: CallableRequest, now = Date.now()) {
  const auth = requireUser(request);
  const signedInAt = Number(auth.token.auth_time ?? 0);
  if (!signedInAt || now / 1000 - signedInAt > RECENT_SIGN_IN_SECONDS) {
    throw new HttpsError("failed-precondition", "Sign in again to delete your account");
  }
  return auth;
}

function liveDeps(): AccountDeps {
  const firestore = admin.firestore();
  return {
    deleteUserTree: (uid) => firestore.recursiveDelete(firestore.doc(`users/${uid}`)),
    deleteOwned: async (collection, uid) => {
      const owned = await firestore.collection(collection).where("userId", "==", uid).get();
      const writer = firestore.bulkWriter();
      owned.docs.forEach((doc) => writer.delete(doc.ref));
      await writer.close();
    },
    deleteDoc: async (path) => {
      await firestore.doc(path).delete();
    },
    deleteFiles: (prefix) => admin.storage().bucket().deleteFiles({prefix}),
    deleteAuthUser: (uid) => admin.auth().deleteUser(uid),
  };
}

/** Deletes the caller's account and all of its data. Cannot be undone. */
export const deleteAccount = onCall({timeoutSeconds: 120}, async (request) => {
  const auth = requireRecentSignIn(request);
  try {
    await deleteAccountData(auth.uid, liveDeps());
  } catch (error) {
    console.error("deleteAccount failed", {error: String(error)});
    throw new HttpsError("internal", "Could not delete the account. Please try again.");
  }
  return {deleted: true};
});
