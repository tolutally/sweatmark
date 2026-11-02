# Account isolation

## Behavior

The authenticated UID defines the lifetime of the application session. A UID change replaces all account-owned providers and the Navigator, including open detail/edit routes. Same-account auth loading notifications retain the session. Template subscriptions, workout/rest timers and sync retry timers are disposed with the old session. Async results cannot notify its disposed providers or populate the next account's providers. Draft restoration cannot restart timers after disposal.

Workouts, drafts, custom exercises and recovery files live under:

`<application documents>/accounts/<SHA-256 of UID>/<filename>.json`

Storage captures the account at construction rather than looking up the current user after each await. The hash gives a stable path-safe directory name; it is not encryption. Signed-out storage access is refused. Cloud sync checks the active UID before writing/retrying; delayed work retains its original owner and cannot retarget the new account. Rest timer/haptic preferences are namespaced by UID; cloud unit preferences reload with the new session.

Closing a session attempts to preserve its latest active draft in that account's directory. This is an asynchronous best-effort save; application termination can still interrupt it. The existing periodic/lifecycle draft saves remain.

## Existing installations

Old top-level `workout_logs.json`, `draft_workout.json`, `custom_exercises.json` and `muscle_recovery.json` do not establish ownership. They are neither deleted nor automatically imported. Otherwise the first account to log in could acquire somebody else's fitness records. Cloud-backed history continues loading from the authenticated user's Firestore path.

**Rollout limitation:** old local-only history, drafts and custom exercises will not automatically appear in the new account directory. A verified-owner recovery/import flow is still needed before a broad rollout to users relying on those old local-only files. Preserve the original files and do not guess ownership. Do not copy all shared files into every account.

## Verification

- `flutter test --no-pub test/account`: 11 passing tests covering real file separation and ownership retention, legacy-file preservation, signed-out/path rejection, navigation disposal, same-account state retention, late result isolation, and sync retry/save races.
- Dart analysis of all modified Dart files and the account tests: no issues.
- Whole-library analysis: no errors; existing warnings/info remain in unrelated screens.
- Tested with temporary Flutter 3.47.8 / Dart 3.13.7. `pubspec.lock` contains the six transitive package adjustments required by that SDK; application dependency constraints were not changed.
- No physical-device or production two-account test was run. The legacy counter/profile widget suite was not used to claim full-suite success.

This is client code. A rebuilt app is required; deploying Firebase functions alone does not deliver the fix.

Before release, exercise A → sign out → B → A on a device, with an active workout, an open private route, distinct library/settings data, and offline pending writes. Confirm A's draft/history never appears under B and that A can reopen its scoped draft. Durable offline reconciliation and complete draft field serialization are separate remaining reliability work.
