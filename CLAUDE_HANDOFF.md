# SweatMark — Claude handoff

Last updated: November 1, 2026

This is the durable project context for continuing SweatMark without the original conversation. Read this file before changing the product, data model, design system, Firebase configuration, or release setup. The repository currently contains a large, intentional, uncommitted product rewrite. Do not reset, clean, restore deleted files, or copy old implementations out of `legacy/` unless the owner explicitly asks.

## Product goal

SweatMark is a focused personal workout log. The core promise is simple:

1. Pick a saved routine or start an empty workout.
2. Add exercises and quickly enter sets, reps, weight, time, or distance.
3. Save reliably even without connectivity.
4. See workout history, weekly consistency, useful stats, and exercise progress.

Ease of logging and trust in saved numbers matter more than adding broad fitness features. Avoid turning the app into a social network, recovery coach, calorie estimator, or generalized health dashboard.

The active app has five primary destinations:

- **Home** — greeting, weekly progress, primary workout action, routines, recent activity.
- **History** — saved workout journal and calendar.
- **Start** — centered primary action for a new workout.
- **Exercises** — searchable exercise library and custom exercise creation.
- **Stats** — monthly/yearly summaries and drill-down sheets.

Profile is accessed from the avatar near search/header actions. Settings is reached from the profile flow. A routine tap opens a preview/details screen; it must never start a session automatically.

## Product decisions that must remain consistent

- A routine opens details first. Starting the workout requires an explicit action.
- Tapping an exercise info button opens a how-to/progress screen; it does not add or start anything.
- Custom exercises persist locally per account and sync when possible.
- Offline completion is a real save. Cloud sync happens later and must not block the user.
- Autofill uses the **last completed workout values**, not the personal record.
- Previously used exercise values should be remembered when that exercise is added again.
- Finishing with unfinished exercise rows prompts the user before excluding those rows.
- Exercise type, tracking mode, image metadata, collapsed cards, and draft state survive closing and resuming a workout.
- Weekly streak is required. The default weekly goal is one workout and is editable; changes apply from the next Monday.
- Stats show recorded facts. Do not invent calories, intensity, heart rate, units, or missing duration.
- Month and Year are explicit period modes. Year view shows all twelve months and supports month drill-down.
- Inner-thigh hip adduction and outer-thigh hip abduction are separate exercises with stable IDs.

## Design direction

The owner supplied multiple mobile fitness references. Reproduce their hierarchy, spacing, proportions, card topology, navigation placement, modal behavior, and visual rhythm where they fit SweatMark. Do **not** copy the reference brand colors blindly.

The rule is:

> Match the composition; express it through SweatMark's design system.

For example, the workout result follows the reference's large hero, four metric cards, exercise list, floating Done action, and share action. Its button is lavender, not the reference's green/cyan. Similar rules apply throughout Home, Settings, Stats, Exercises, workout details, and share results.

Source of truth: [`lib/theme/app_theme.dart`](lib/theme/app_theme.dart) and [`docs/design/DESIGN_SYSTEM.md`](docs/design/DESIGN_SYSTEM.md).

Core light palette:

| Role | Value |
| --- | --- |
| Page | `#FDFCFD` |
| Card | `#FFFFFF` |
| Ink | `#1D1C21` |
| Muted text | `#696473` |
| Primary lavender | `#A893F0` |
| Pale lavender | `#E6DFFB` |
| Interactive dark lavender | `#6741B2` |
| Reference panel | `#F7F6F9` |
| Lavender panel | `#F8F5FE` |
| Decorative lime | `#D4F120` |
| Decorative coral / PR | `#FF555D` |

Use General Sans from `assets/fonts/general_sans/`. Typical sizes are 27px dashboard titles, 18px compact page headers, 22–27px important values, 17px section titles, 15px body/input text, and 13px supporting text. The app previously suffered from oversized type; preserve the compact proportions in the current screens.

Use rounded white/panel cards, generous breathing room, subtle borders, and pale lavender selected states. Dark mode must use semantic theme roles. Keep state understandable without color alone. Do not reintroduce neon mint as the primary brand color.

### Navigation

The bottom navigation is a dark rounded dock inspired by the supplied reference, with a raised central lavender Start action. The Stats icon represents stats; do not use it as a history icon. Keep the dock consistent across primary pages.

### Finish and share flow

The current finish screen is in [`lib/screens/workout_summary_screen.dart`](lib/screens/workout_summary_screen.dart). It uses:

- a lavender/pink hero with spaced SweatMark wordmark;
- workout title, duration, and ordinal workout count;
- 2×2 rounded metric cards for completed sets, weekly streak, PRs, and lifting volume;
- a flat Best Set exercise list with coral PR badges;
- a lavender Done button and separate share button;
- notes and Save as routine in the overflow menu.

The share preview is in [`lib/screens/workout_share_screen.dart`](lib/screens/workout_share_screen.dart). It renders a bounded PNG and opens the native share sheet. It must not include email or private notes. Full behavior and verification are documented in [`docs/WORKOUT_RESULTS.md`](docs/WORKOUT_RESULTS.md).

## Implemented feature state

### Authentication and account isolation

- Firebase email/password authentication is active.
- Google/Apple UI remains disabled until the providers are fully configured and tested.
- Account-owned providers are recreated when UID changes.
- Local records live under an account-scoped hashed directory.
- Signed-out storage is refused.
- Async work from an old account cannot populate a new account.
- Unowned legacy local files are preserved and deliberately not auto-imported.

See [`docs/ACCOUNT_ISOLATION.md`](docs/ACCOUNT_ISOLATION.md).

### Reliable offline workouts

- Finishing commits workout history, pending cloud operation, and draft removal atomically on device.
- Pending uploads, edits, and deletes retry on startup, foregrounding, and every 15 seconds while the app runs.
- Local history is merged conservatively with cloud history.
- Tombstones prevent stale cloud responses from restoring local deletions.
- Repeated uploads do not double-count the workout.
- A late autosave cannot resurrect a completed draft.

This is durable replay, not full multi-device conflict resolution. See [`docs/OFFLINE_WORKOUTS.md`](docs/OFFLINE_WORKOUTS.md).

### Workout logging

- Strength, bodyweight, cardio, and timed modes are modeled explicitly.
- Exercise metadata and units are preserved in drafts/history.
- Known kg/lb values are normalized only for comparison; original recorded units remain visible.
- Unknown legacy units are disclosed and excluded from comparisons instead of guessed.
- Cardio supports recorded time, distance, optional average heart rate, and subjective Low/Moderate/High effort.
- Exercise cards can remain collapsed through draft restoration.
- An unfinished-set confirmation exists before finishing.
- Last completed values support fast repeat entry.

### Routines and exercises

- Saved routines sync through the template system.
- Routine details are editable and explicitly started.
- The exercise library supports search, muscle/equipment filtering, info pages, and custom exercise creation.
- Custom exercises use account-scoped local persistence plus a durable upload/delete queue.
- Exercise info includes how-to content and links to individual progress.

### Personal records

The single calculation path is [`lib/services/pr_service.dart`](lib/services/pr_service.dart). It feeds active badges, celebrations, saved summaries, and stats.

- Weighted record: highest completed weight; more reps wins at equal weight.
- Unweighted bodyweight record: highest completed reps.
- Added-weight bodyweight records remain separate from unweighted records.
- First comparable performance establishes a baseline and says **First best saved** without a PR celebration.
- Equal performance is not a new record.
- Only completed, valid, non-rest sets count.
- Test workouts, cardio, timed holds, assisted movements, and unknown weight units are excluded.
- Exercise matching uses stable IDs, including custom exercises.
- The active winning set shows **New PR**.
- A brief celebration can use finite confetti and optional haptics; reduced motion is respected.
- Celebration IDs persist in drafts so reopening/rechecking an unchanged set does not replay it.
- Editing or unchecking recalculates eligibility.
- Records become permanent with locally saved workout history; discarded drafts contribute nothing.
- The Stats Personal Records card provides recent PRs and all-time bests with timestamps and links to exercise progress.

### Stats

Stats are derived from completed, non-test history available on the device, including locally saved workouts waiting to sync.

- Month/Year selector and period navigation.
- Workouts, active days, total/average recorded workout time.
- Daily/monthly activity visualization.
- Strength sets, reps, and known-unit lifting volume.
- Cardio workouts, time, normalized known-unit distance, heart rate, and effort details.
- Primary muscle-group set counts.
- Personal-record count and details.
- Logged dates/times appear in detail sheets.
- Individual exercise progress remains on the exercise page.

Missing data stays missing and is explained. Current-month comparison uses the same elapsed portion of the prior month.

### Retired scope

The following were intentionally removed from the active app and preserved under `legacy/`:

- muscle recovery/readiness maps;
- flame/tier mechanics and countdown streaks;
- broad analytics dashboard;
- social feed/profile editing;
- AI coach placeholder;
- scheduling and old notifications UI;
- exercise-download administration UI;
- automatic calorie/points claims.

Do not restore these because old source files exist. The owner wants an app that logs exercises and tracks numbers.

## Architecture map

- `lib/main.dart` — Firebase initialization, authenticated session boundary, provider composition, theme.
- `lib/widgets/app_shell.dart` — primary tab shell and navigation dock.
- `lib/screens/` — active UI flows.
- `lib/state/workout_notifier.dart` — active draft, history, collapsed state, timers, completion, PR state.
- `lib/state/template_notifier.dart` — routine lifecycle and sync.
- `lib/state/settings_notifier.dart` — account settings, units, goal history, haptic/rest preferences.
- `lib/state/exercise_db_notifier.dart` — catalog/custom exercise state.
- `lib/services/storage_service.dart` — account-scoped atomic snapshots and durable outboxes.
- `lib/services/sync_service.dart` — conservative local/cloud merge and retry loop.
- `lib/services/firebase_service.dart` — Firebase client access.
- `lib/services/pr_service.dart` — structured record derivation.
- `lib/models/workout_result.dart` — shared saved-summary/share presentation model.
- `functions/src/` — authenticated Firebase Functions and endpoint security.
- `test/account/`, `test/logging/`, `test/design/` — active regression suites.
- `test/manual/` — memory-only simulator previews; these must never save fixtures to a real account.
- `legacy/` — retired code excluded from the active build.

State management uses Provider/ChangeNotifier. Firebase project configuration targets `sweatmark-v1`. Do not put secrets, private keys, admin passwords, or tester identities in documentation or source.

## Backend and security

Cloud Functions use Node 22. Exercise lookup and metadata endpoints require a non-anonymous Firebase user. Administrative import/download/refresh routes require a verified Firebase ID token with a strict boolean `admin: true` custom claim. Legacy query/body passwords are rejected. Shared endpoint quotas are account-based and stored transactionally. App Check is not yet integrated or enforced.

The functions and Firestore rules/indexes have been deployed previously. Credential rotation was explicitly deferred by the owner; endpoint authorization does not replace rotation. Read [`functions/ENDPOINT_SECURITY.md`](functions/ENDPOINT_SECURITY.md) before any backend change.

If Firebase proposes deleting a deployed function missing from local source, stop and inspect it first. A backup of the retired `generateWorkout` deployment exists under `backups/`.

## iOS, simulator, and TestFlight

- Flutter SDK on the development Mac: `~/.local/share/flutter`.
- Run locally with `./scripts/run-ios.sh` after booting one iPhone in Xcode Device Hub.
- Expo is not used.
- Bundle ID: `com.peniwyse.sweatmark.ios001`.
- Firebase iOS configuration matches this bundle.
- Deployment target is iOS 15+.
- Sign in with Apple and production APNs entitlements exist for release builds.

The last uploaded private TestFlight build documented in the repository is **1.3.3 (10)**. It does not contain every subsequent local UI change. The present working tree is ahead of TestFlight and must be treated as the source of truth. Do not submit for public App Review unless the owner explicitly changes the release scope. Public privacy/support URLs, privacy answers, review details, account deletion, and media-rights confirmation remain release work.

See [`docs/IOS_TESTING.md`](docs/IOS_TESTING.md) and [`docs/release/STATUS.md`](docs/release/STATUS.md).

## Current verification status

Before the final palette-only result-screen correction, the full active Flutter suite had **132 passing tests**. The final correction removed copied green/cyan/blue/orange accents from the finish screen and was then checked with:

```sh
flutter analyze --no-pub lib/screens/workout_summary_screen.dart
flutter test --no-pub --reporter compact \
  test/design/workout_result_design_test.dart \
  test/widget_test.dart
flutter build ios --simulator --debug --no-pub -t test/manual/workout_result_preview.dart
flutter build ios --simulator --debug --no-pub -t lib/main.dart
```

Analysis was clean, all four focused tests passed, the preview was visually inspected on an iPhone 18 Pro simulator, and the normal app build was restored afterward. The latest visible finish screen had a lavender Done action, lavender section accents, coral PR treatment, and no borrowed green action button.

For a comprehensive checkpoint, run:

```sh
flutter test --no-pub
npm --prefix functions test
```

Avoid repeatedly running broad tests while iterating on low-impact visual details; use focused tests and the manual memory-only preview, then run the full suite at a release checkpoint or when the owner asks.

## Working-tree warning

The current branch contains many modified, added, and intentionally deleted files. The deleted files largely represent retired product scope. There are also native iOS, Firebase, dependency, test, and design-system changes that belong together.

Before editing:

```sh
git status --short
git diff --stat
```

Do not use `git reset --hard`, `git clean`, bulk restore, or an old commit as a new base. Do not assume the latest Git commit reflects the active product. Preserve the local working tree and make narrow edits.

## Best next steps

1. **Audit remaining screens against the design system.** Keep reference layouts but replace stray copied colors, oversized type, inconsistent back buttons, and mismatched navigation.
2. **Exercise the real logging loop on simulator/device.** Routine preview → start → add familiar exercise → verify last-values autofill → collapse → background/reopen → finish with an unfinished row → summary → share → history/stats.
3. **Run the full suite after visual work stabilizes.** Fix only real regressions; avoid snapshot tests that merely mirror implementation.
4. **Create a clean reviewable commit.** The local rewrite currently spans product simplification, offline reliability, account isolation, PRs, stats, redesigned screens, and iOS release configuration. Review the diff carefully before grouping commits.
5. **Prepare a new private TestFlight build only when requested.** Increment version/build, archive with automatic signing, upload, complete export compliance, and assign it to the existing private testing group. Do not publish publicly.
6. **Before broader release:** add in-app account deletion, publish privacy/support pages, finish App Store privacy/review metadata, verify two-account isolation on a physical device, confirm exercise-media rights, integrate App Check, and rotate exposed credentials.

## Collaboration preferences

- Act on clear implementation requests instead of stopping at a plan.
- Discuss product logic first when the owner explicitly asks to discuss.
- Preserve simplicity; challenge features that complicate logging without improving trust or speed.
- For visual references, match structure closely but use SweatMark colors and available features.
- Keep progress reports concise and explain what changed, why, and how it was checked.
- Ask before legal acceptance, public submission, destructive repository operations, credential changes, or actions that materially affect external accounts.

## Supporting documents

- [`docs/PRODUCT_SCOPE.md`](docs/PRODUCT_SCOPE.md) — detailed product rules and stats behavior.
- [`docs/design/DESIGN_SYSTEM.md`](docs/design/DESIGN_SYSTEM.md) — colors, typography, geometry, components.
- [`docs/OFFLINE_WORKOUTS.md`](docs/OFFLINE_WORKOUTS.md) — persistence and replay semantics.
- [`docs/ACCOUNT_ISOLATION.md`](docs/ACCOUNT_ISOLATION.md) — UID boundaries and legacy-data policy.
- [`docs/WORKOUT_RESULTS.md`](docs/WORKOUT_RESULTS.md) — saved result and native sharing.
- [`docs/IOS_TESTING.md`](docs/IOS_TESTING.md) — development Mac and simulator workflow.
- [`functions/ENDPOINT_SECURITY.md`](functions/ENDPOINT_SECURITY.md) — Functions authorization and deployment.
- [`docs/release/STATUS.md`](docs/release/STATUS.md) — private beta history and blockers.

