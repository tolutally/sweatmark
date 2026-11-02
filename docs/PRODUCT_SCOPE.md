# SweatMark: logging first

The app now has three tabs: Workouts, Exercises, History. Settings is a gear on Workouts. The core loop is start/repeat, enter and complete sets, finish and save, then view a saved summary. Only unfinished sets prompt for confirmation. The summary is already saved; notes and saving a routine are optional follow-ups. Repeat copies the exact sets and their recorded units without adding blank sets or mutating history.

## Keep

- Account isolation, durable offline workout history, pending edit/delete replay, Firebase backup.
- Searchable exercise catalog, custom exercises, saved routines, repeat workout, supersets, optional rest timer (including Off).
- Completed workout calendar and recent history.
- Last-session sets beside logging inputs. Exercise pages show previous completed sets, best completed weighted set, and a per-session weight chart when there are two comparable sessions.

## Weekly streak

Home shows weekly streak plus completed workouts/goal this week. Default goal is one; Settings allows 1–14. A change applies next Monday. Goal history is stored by effective week so later changes do not rewrite earlier targets. Weeks run Monday–Sunday in device-local calendar time. An incomplete current week preserves the streak through last week; a missed closed week breaks it. Meeting the current goal adds one week, regardless of additional workouts. Duplicate IDs, future timestamps, test data, and workouts without completed sets do not count. Deleting a workout recomputes the streak from remaining history.

Preferences are stored per account on device and written to Firestore. Existing cached preferences take precedence on this installation; continuous multi-device preference conflict resolution is not implemented.

## Trustworthy numbers

Each newly entered weight stores kg or lb. Existing values are not silently converted when the preference changes; the setting affects new entries, and recorded units remain visible. Comparisons normalize known weights to kilograms. Older values without units remain unchanged and display “unit unknown”; they are excluded from weight charts and records rather than guessed. Re-entering a weight explicitly assigns the current unit. A legacy-unit migration would require the owner's confirmation of the original units.

Records use completed weighted sets: greater weight, or more reps at equal weight. The first comparable session establishes a baseline. Estimated 1RM and incomplete sets no longer generate PR celebrations. Bodyweight and cardio session values remain visible in history; the chart currently tracks weighted sets only.

## Retired

Recovery/readiness scoring and body maps, flame/tier systems, daily/custom streak countdowns, loss popups, schedule setup, the broad analytics dashboard, profile editing, image sharing, the AI placeholder, and exercise-download admin UI are removed from the active app. Their sources are preserved under legacy/ and excluded from builds/analysis. The obsolete profile screen tests move with the retired screen; current profile data-model tests remain active.

The app reads one existing cached exercise collection and falls back to a bundled catalog if unavailable. Previously logged/custom exercises remain discoverable by stable ID. Administrative ingestion endpoints remain protected compatibility tooling; this pass does not delete shared catalog data or deployed import functions. The deployed scheduleStreakReminders function is now a no-op, so the old urgency pushes stop without deleting infrastructure.

Removed app dependencies: flutter_svg, image_gallery_saver, flutter_background_service, image_picker. Photo-access and background-fetch declarations associated with those features were removed from iOS.

## Verification

Run flutter test for the active suite. Coverage includes offline replay/account isolation, weekly boundaries, goal-history preservation, unit serialization, completed-set record rules, exact repeat behavior, cleared input values, and the simplified home and already-saved summary. Verify navigation and the Settings goal picker in the iOS simulator. No test workouts need to be written to production to run these tests.

## Stats

The fourth tab summarizes completed, non-test workouts on this device (including locally saved workouts waiting to sync). Switch between Month and Year above the period selector; annual activity shows January–December, with tappable months for drill-down. Select a period to see workout count, active days, recorded total/average session time, daily activity, strength sets/reps/volume, cardio, and primary-muscle set counts. Current-month comparisons use the same elapsed period of the preceding month. Individual exercise charts remain in exercise info.

Only completed, non-rest sets count. Duration averages exclude sessions with no positive recorded duration. Session time includes rest; cardio time is recorded per set. Lifting volume converts known lb/kg units before summing weight × reps. Cardio distance converts known mi/km units; older missing units are excluded and disclosed. New distance edits preserve the unit, and workout exercise logs preserve their exercise type. Missing muscle groups remain unspecified; set distribution is not a recovery estimate.

Workout and time detail sheets list logged dates, local times, and recorded durations, with links to workout details. Cardio details list completed sets and optional manually recorded average heart rate and Low/Moderate/High effort. Effort is subjective, not an inferred heart-rate zone; absent values remain Not recorded. Heart rate and effort belong to each session and are cleared when repeating a workout.

Custom exercises use an account-scoped atomic local snapshot and durable upload/delete queue. Existing local exercises migrate automatically. Sync retries on startup, foregrounding, and every 15 seconds while the app runs, independently of workout uploads. Cloud reads cache exercises for offline use; pending edits and deletions take precedence over stale cloud results.
