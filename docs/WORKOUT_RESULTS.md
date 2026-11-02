# Saved workout and share result

Finishing a workout still saves it locally before opening the summary. The
summary now uses the app's light lavender palette, a title/date/duration hero,
four rounded metric cards, completed exercise results, and fixed Done/Share
actions. Notes and Save as routine remain available below the results.

`WorkoutResultData` supplies both the summary and share preview. It uses
completed non-rest sets, converts known units to the user's preference, excludes
test logs from PRs/streaks, and distinguishes first baselines from new records.
Missing measurements remain missing; no calories or points are estimated.

Share opens a dark sheet containing the result card. Its composition follows the
owner's reference: an avatar/name/date header with the spaced wordmark, a
workout tile (the first exercise's artwork, or a lavender dumbbell tile when
none is available) and large title, one row of icon metrics (duration, sets, volume;
missing measurements are omitted), then a pale panel of exercise rows with
right-aligned results ("45 lb • 10 reps", numbers bold, units muted) and coral
PR badges. No calories are shown. The preview itself is
rendered to PNG, including every exercise in long workouts. PNG size is bounded
to limit memory use. Missing artwork uses a local icon. Only display name,
workout name, logged date/time, metrics, and exercise results are included;
account email and notes are excluded.

The Share or save image action opens the operating system's share menu, where
the user chooses a destination or available save action. Nothing is posted
automatically. The implementation uses
[share_plus 11.1.0](https://pub.dev/packages/share_plus/versions/11.1.0), compatible
with this project's existing Android build tools, with an iPad popover anchor.
Native plugin registration takes effect on the next full app build.

## Verification — November 1, 2026

After the user authorized verification, all 132 Flutter tests passed. Coverage
includes completed/rest filtering, known and unknown units, mixed record types,
baseline/PR labels, streak deduplication, 320px layouts with 1.5× text in both
themes, and native-share failure/retry. PNG checks confirm all 12 exercise rows
are painted, including rows below the viewport; private notes and email are
excluded. Timed-hold results were corrected to preserve seconds.

Analysis of the three result/share source files reports no issues. The full
repository still has existing informational lints; no analysis errors or
warnings were reported in the initial full run. The iOS simulator build passes.

The iPhone 18 Pro simulator was checked with
`test/manual/workout_result_preview.dart`, which uses memory-only fixtures.
Summary → Share preview → native iOS menu successfully produced a PNG with
Save Image available. Dismissing the menu, closing the preview, and Done all
returned correctly. No test workout was written to account history, and no
image was sent to a third party. The normal `lib/main.dart` build is restored
after this inspection.
