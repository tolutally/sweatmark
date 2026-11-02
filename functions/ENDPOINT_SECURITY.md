# Endpoint authorization and rollout

These changes are local until deployed. Target project from repository Firebase configuration: `sweatmark-v1`, region `us-east1`.

## Access policy

| Endpoints | Required access |
| --- | --- |
| searchExercises, getExerciseById, refreshGymFitImage | Non-anonymous Firebase user; shared 30 requests/account/minute quota; validated input |
| getCacheStats, getBodyParts, getEquipmentList | Non-anonymous Firebase user |
| downloadAllExercisesComplete, triggerExerciseDownload | Firebase ID token with boolean `admin: true`; revocation/disabled-account check |
| adminDownloadAllExercises, bulkDownloadExercises, downloadAllExercises, downloadFromGymFit, refreshAllGymFitImages | POST with `Authorization: Bearer <Firebase ID token>`; boolean `admin: true`; revocation/disabled-account check |

HTTP routes no longer accept query/body passwords or upstream API keys as authorization. Existing HTTP invoker IAM is preserved on updates; the source does not request public access. Where IAM permits requests to reach a handler, its admin-token check still applies. Private IAM may additionally require an authorized Google identity. Existing clients using old admin passwords must change. Normal app Firebase callable authentication is automatic for signed-in users.

The admin claim must be assigned using a trusted Admin SDK environment, preserving other existing claims. Never let the client or a user-writable Firestore profile grant it. Users without the claim cannot import exercises. No admin account was chosen or modified by this patch. Refresh the Firebase ID token after a claim is granted. Token verification checks revocation for administrative calls.

The quota uses `_endpointQuotas/{sha256(uid)}` with transactional updates so concurrent function instances share a counter. The repository's Firestore default-deny rule prevents client access; confirm the deployed rules do too. Only one quota document per account is retained. Database failure denies the request rather than bypassing the limit. This is a per-account control, not a global spend cap or protection against mass account creation.

App Check is not enforced yet because this Flutter app has no App Check integration. Configure client attestation and verify it in production before enabling enforcement. Metadata reads are authenticated but not rate-limited by this patch.

## Verification and deployment

From the repository root:

```sh
npm --prefix functions ci --ignore-scripts
npm --prefix functions test
firebase login
firebase deploy --project sweatmark-v1 --only functions:searchExercises,functions:getExerciseById,functions:refreshGymFitImage,functions:getCacheStats,functions:getBodyParts,functions:getEquipmentList,functions:downloadAllExercisesComplete,functions:triggerExerciseDownload,functions:adminDownloadAllExercises,functions:bulkDownloadExercises,functions:downloadAllExercises,functions:downloadFromGymFit,functions:refreshAllGymFitImages
```

Deploy every listed endpoint together so older entry points do not retain their weak checks. This selective command leaves streak triggers/scheduled jobs outside this patch's deployment. Firebase CLI and an authorized project login are required. Node 22 is the configured functions runtime.

Tests exercise every callable's unauthenticated/anonymous rejection, HTTP method and legacy credential rejection, ordinary-user admin denial, strict verified admin claims, revoked tokens, normal filter access, malformed/path-injection input, and quota boundary/reset/account separation. They mock token verification and quota storage; they do not prove deployed IAM, Firestore concurrency, or production token verification. The Firebase SDK provides signature verification for callable auth and ID-token verification for HTTP/admin requests.

After deployment, verify unauthenticated/ordinary-user rejection on all admin routes, normal signed-in exercise usage, and the quota with a test account. Confirm a trusted administrator's token/claim without running a full production import merely as an access test.

Credential rotation is deferred at the user's request. The previously exposed Apple and upstream API keys remain exposed; endpoint checks do not invalidate them or prevent direct upstream use. No key values are repeated in this document.


## Node 22 runtime upgrade

The runtime is selected by `functions/package.json` (`engines.node: "22"`), with matching lockfile metadata. Local build/security verification runs on Node 22. Runtime changes take effect only after redeployment.

To upgrade all functions, including the streak trigger and reminder scheduler omitted from the earlier endpoint-only rollout, run from the repository root:

```sh
firebase deploy --project sweatmark-v1 --only functions
```

Confirm deployment output reports Node.js 22 for every function. If the CLI proposes deleting unexpected functions, stop and review the names first. Test a normal workout save, exercise browsing, and administrative rejection after deployment; unit tests do not exercise production Firebase integrations.
