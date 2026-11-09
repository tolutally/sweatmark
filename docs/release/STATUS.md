# TestFlight release status — October 25, 2026

User clarified scope: private TestFlight testing on their own phone; they will add testers themselves. Do not submit for public App Review. Public listing requirements below are deferred.

- App Store Connect: SweatMark, 6755909248; Peniwyse Financial Technology Inc., team FV4TXY2Q7Z.
- Existing latest TestFlight upload: 1.3.0 (7), expired; next build selected: 1.3.1 (8).
- Apple agreement issued October 13, 2026 is shown as accepted October 25, 2026.
- Production iOS compilation and unsigned archive succeeded. Archive: build/ios/archive/SweatMark-unsigned.xcarchive. This does not constitute an App Store upload.
- Release/Profile entitlements now include Sign in with Apple and production APNs.
- Last test results: 52 Flutter tests and 8 backend security tests passed.

## Open blockers

1. Firebase CLI reauthentication completed; production deployment succeeded.
2. Registered com.peniwyse.sweatmark.ios001 in the same project; applied generated plist and matching Dart options. Firebase app ID: 1:529973334654:ios:cf2aca1a1d905c3cc93e2f.
3. Firebase console confirms Google and Apple providers are not configured. Social sign-in UI is disabled by default; email/password remains enabled. ENABLE_SOCIAL_SIGN_IN may be enabled only after provider configuration and end-to-end testing.
4. Xcode account sign-in and automatic signing are approved and configured. Final signed archive succeeded and its bundle, version, build number, and generated Firebase configuration were verified. App Store Connect upload succeeded.
5. In-app account deletion and an accessible privacy-policy link still need implementation before App Review.
6. App Store listing draft 1.3.1 saved with description, promotional text, and keywords. Support/privacy URLs, screenshots, app privacy answers, age rating responses, review contact and test login still need completion.

Firebase functions and Firestore rules/indexes deployed successfully to sweatmark-v1. TestFlight upload 1.3.1 (8) completed and Apple processing finished. Build ID: 6429b8c5-c39d-4dbf-a61b-7d09debe02a7. Currently Missing Compliance.

Upload completed with warnings about missing dSYM files for third-party frameworks. This did not prevent upload; symbolicated crash details inside those libraries may be limited.

Personal testing internal group created with automatic distribution disabled; only the owner's personal Apple ID added. No build added yet. Standard encryption selected (Firebase/gRPC TLS); France distribution answer not submitted. Automatic approval review requires explicit confirmation to select No and Save the export-compliance declaration. User is testing personally in Canada; confirm before submitting. No public review submitted.

## November 1, 2026 — 1.3.2 (9)

- Persistence fixes: draft saves collapsed cards and tracking field selections; restored exercise type is used; workout images use disk cache.
- 53 Flutter tests and backend security tests passed.
- Firebase functions/Firestore deployment completed successfully (unchanged functions skipped).
- Signed archive build/ios/archive/SweatMark-9.xcarchive verified as 1.3.2 (9).
- App Store Connect upload succeeded; log /tmp/sweatmark-upload9.log.
- Browser session expired. User must sign in before processing/compliance and assignment to Personal testing can be verified. Build 9 is not yet confirmed available for installation.

## November 1, 2026 — Personal records / 1.3.3 (10)

- Automatic saved-best badges on exercise and superset headers, including collapsed cards.
- Weighted and unweighted bodyweight records derive from account-owned completed workout history; weighted bodyweight records remain separate. Cardio, holds, assistance, test data, invalid sets, and unknown weight units excluded.
- Set-completion PR celebrations include finite confetti and optional haptics; reduced motion respected. Celebration keys persist in drafts; finishing no longer duplicates PR notifications.
- Active winning sets show New PR; saved summary lists final records/baselines. Stats has period-specific PR counts and recent/all-time detail lists.
- 61 Flutter tests passed, including new PR comparison, draft-restore, stats detail and reduced-motion regressions. Analyzer reported no errors or warnings (existing info lints remain).
- Archive build/ios/archive/SweatMark-10.xcarchive succeeded and verified as 1.3.3 (10). Upload in progress in /tmp/sweatmark-upload10.log.
- No backend schema changes or Firebase deployment needed. Autofill and unfinished-set warning remain separate work.
- Upload completed successfully; App Store Connect shows 1.3.3 (10) Processing. Awaiting Apple processing and group assignment.
- Apple processing completed. Build 10 now Missing Compliance. Standard encryption selected; France answer remains unsubmitted. Await user confirmation to answer No/save (prior automatic review requires explicit approval), then assign to Personal testing. Screenshot /tmp/sweatmark-build10-compliance.png.

## November 1, 2026 — Focused logging rewrite / 1.4.0 (11)

- Contents: merged rewrite (PR #1) — offline-durable logging, account isolation, redesigned Home/History/Workout details/share card, readable names for older logs, bundled ExerciseGymGifsDB catalog (1,323 exercises) and media (Git LFS, ~93 MB).
- 148 Flutter, 8 Functions and 3 import-script tests passed on the committed state.
- Signed archive build/ios/archive/SweatMark-11.xcarchive verified as 1.4.0 (11); app bundle 130 MB before App Store compression.
- Command-line export could not use the Xcode account; uploaded from Xcode Organizer (App Store Connect → Upload). Status: Uploaded to Apple.
- Apple processing completed. The owner answered export compliance (standard encryption).
- Added to the internal Personal testing group (1 tester); status Testing, expires in 90 days. No public review.
- The Account Holder accepted the updated Apple Developer Program License Agreement on November 1, 2026 (deadline was November 13).

## November 4, 2026 — Sign-in redesign and Apple Health / 1.4.1 (12)

- Contents: intro pages, Apple and Google sign-in, separate sign-in and sign-up screens, Apple Health (save workouts; show Health workouts and steps in Stats), new icon, app name SweatMark.
- 155 Flutter tests passed on the committed state.
- HealthKit enabled on the App ID in the developer portal; Xcode regenerated the team profile with HealthKit.
- Archived from the command line as ios/build/SweatMark-1.4.1-12.xcarchive and uploaded from Xcode Organizer. Only warnings: missing dSYMs for some frameworks.
- Apple processing completed. The owner answered export compliance (standard encryption).
- Added to Personal testing (internal) and Family & Friends (external, 4 testers). Submitted for TestFlight Beta App Review, which external groups need. No public App Store review.
- Not yet checked on a real device: Apple Health read and write, Apple and Google sign-in.
- Before any public release: add Health data to the App Store privacy answers.

## November 8, 2026 — AI search, Health in Stats, share card / 1.5.0 (13)

- Contents: AI exercise search ("Ask AI" in Library, Claude Haiku 5.5 through the `runAiWorker` function), smarter text search (any word order, plurals, gym shorthand), redesigned share card with top set and muscles, share from saved workouts, timer pauses after 10 minutes idle, Apple Health steps, distance and active energy in Stats, Watch time used when a workout overlaps, cardio source setting (logs, Health or both).
- 198 Flutter tests and 17 Functions tests passed. Analyzer clean.
- Fix: the project inherited the organization's "Domain restricted sharing" rule, so no app function could be called (403). The owner set the project to the Google-managed default and gave the seven app callables public invoker access (each still requires sign-in). Admin functions stay private.
- App callables in `exercise_db_repository.dart` now use region us-east1.
- All Cloud Functions deployed to sweatmark-v1.
- Signed archive build/ios/archive/SweatMark-13.xcarchive verified as 1.5.0 (13) with HealthKit, Sign in with Apple and push entitlements. Command-line upload again couldn't use the Xcode account; uploaded from Xcode Organizer.
- Before AI search works: Firestore `_config/ai` must exist with `enabled: true`.
- Uploaded from Xcode Organizer on November 8, 2026 (warnings only: missing dSYMs for some frameworks). Next: Apple processing, export compliance, then add to Personal testing and Family & Friends.
