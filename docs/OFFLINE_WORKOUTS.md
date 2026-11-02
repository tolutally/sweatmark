# Offline workout saving

Finishing a workout commits history, its pending upload, and draft removal to one account-scoped JSON snapshot. Writes are serialized across StorageService instances, flushed to a temporary file, then atomically renamed. A failed disk write surfaces an error instead of pretending the workout was saved. Existing owned workout files are migrated into the outbox; unowned legacy files remain untouched.

Cloud sync runs separately from saving. It retries on startup, foregrounding, and every 15 seconds while the app is running, with no attempt limit. Closing the app preserves pending work for the next launch. iOS does not guarantee execution while the app is closed. Account changes stop further requests from the old session; requests already issued retain their original UID.

Uploads upsert the existing timestamp-based workout ID. Firestore transactions increment workout count only on initial creation, so retrying an acknowledged upload cannot double-count it. Local edits and deletes replace pending operations by ID; acknowledgements remove only the exact revision sent. Writes are not timed out, because a Firestore write can still complete after a timeout. The save UI never waits for those writes.

Cloud history is cached locally and merged with pending edits. Empty or failed queries cannot erase local history. Local deletion tombstones prevent stale cloud responses from restoring deleted workouts. A response begun before a local mutation/acknowledgement is discarded. This is conservative preservation, not multi-device conflict resolution: remote deletions on another device are not inferred from absent documents, and conflicting simultaneous edits remain last-write-wins in the cloud.

Drafts retain all exercise/set fields, cardio values, superset progress, notes, and original timestamp. Completion clears the matching draft in the same commit. A late autosave cannot resurrect a completed workout.

## Verification

Run `flutter test test/account`. Tests cover persistence across new service instances, repeated network failures, stalled acknowledgement, concurrent saves, revision races, deletion replay, stale cloud responses, account switching, legacy migration, corrupt-file preservation, and draft completion.

For a device check, use a test account in sweatmark-v1. Disconnect networking, finish a workout, restart the app, and verify it remains in history. Reconnect and keep the app open; confirm exactly one document under users/<uid>/workouts/<workout-id>. Repeat with a notes edit and deletion. The automated tests use a fake cloud and real temporary files; they do not write to production Firebase.

## Scope

Durable replay covers workout records, notes edits, and deletions. Recovery/flame features have since been retired from the active app; saving no longer updates those derived metrics. Custom exercises and other app data retain their existing sync behavior. Files survive app restarts, not uninstalling the app or losing the device before upload. Existing timestamp IDs are retained for compatibility.
