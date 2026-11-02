# SweatMark design system

The app follows system light/dark appearance. `lib/theme/app_theme.dart` is the source of truth for colors, typography, and Material component defaults. Use `Theme.of(context).colorScheme` for standard roles and `AppDesign.of(context)` for success, PRs, warnings, charts, and hero gradients.

| Role | Light | Dark |
| --- | --- | --- |
| Page | #FDFCFD | #141218 |
| Cards | #FFFFFF | #211E29 |
| Main text | #1D1C21 | #F5F3FA |
| Supporting text | #696473 | #B5AEC2 |
| Brand accent | #A893F0 | #A893F0 |
| Selected surface | #E6DFFB | #382D50 |
| Interactive text | #6741B2 | #C9B5FF |
| Decorative border | #E6E1ED | #40394D |
| Reference panel | #F7F6F9 | #292431 |
| Weekly overview | #F8F5FE | theme primary container |
| Decorative lime | #D4F120 | #D4F120 |
| Decorative coral | #FF555D | #FF555D |

The lavender and pale surfaces are sampled from the supplied activity/journal screenshots: #A893F0 is the dominant lavender, #F7F6F9 the panel, #F8F5FE the tinted inset, and #E6DFFB the selected surface. Use `AppColors.lavender` for decorative fills, charts, and selected switch/checkbox tracks. The darker `primary` is for readable text links and focus, not a substitute for reference lavender. Pair containers with their matching `on…Container` foregrounds. Green means completed/success; gold marks personal records; red means error/destructive. Never communicate state with color alone. Charts use the theme's ordered six-color palette and accompanying labels/values.

## Typography and geometry

General Sans Regular/Medium/Semibold/Bold and Italic are bundled, so rendering never needs a font download. Original files and license obtained from https://www.fontshare.com/fonts/general-sans (2026-11-01); retain the unmodified license in assets. It is also registered with Flutter's license registry. These are application assets, not a standalone font distribution.

Use 27px dashboard titles, compact centered 18px headers for reference-style stats/settings sheets, 22–27px prominent values, 17px sections, 15px body/input text, and 13px supporting text. Medium headings and semibold key values. Dense set annotations may be 10–13px; do not use tiny text for primary controls. Respect system scaling; wrap rather than shrinking text. Avoid fixed-height text containers.

Spacing: 4, 8, 12, 16, 24, 32. Card radius24, sheet radius28, input radius12, pills for actions/segments/navigation. Tap targets at least44px. Theme primary actions are solid near-black/white in light mode, lavender/near-black in dark mode. Use gradients only on feature surfaces such as Start Workout/profile. Keep exercise imagery and app icon unchanged.

## Validation and previews

Run `flutter test` and `flutter analyze`. `test/design` checks readable semantic contrast, real-theme layouts, enlarged text, and reduced motion. To export the four main screen previews in both modes:

```
flutter test test/design/design_preview_test.dart --dart-define=CAPTURE_DESIGN=true
```

It writes `/tmp/sweatmark-{home,workout,stats,settings}-{light,dark}.png` with local fixture data, not account data, plus the scrolled settings goal. These captures support review; they are intentionally not date-dependent golden baselines. Navigation displays Home / History / Start or Resume / Browse / Stats, mapping to the existing screens. Profile remains in the homepage header. No storage schema or backend changes are required for this theme.

## Homepage dashboard

The homepage follows the reference's proportions: pale lavender overview panel, solid lavender/lime icon badges, compact inline metric values, and contrasting activity/weekly cards nested inside a pale panel. The bottom bar is edge-to-edge ink with a straight top, small icons and labels, no selected-tab capsule, and an 80px raised pale-lavender circle surrounding a 52px lavender Start/Resume action. This center action starts an empty workout or resumes the current draft.

The overview displays the existing weekly goal and streak with a capped0–100% goal gauge. Lavender and the thin lime arc both show the same progress; ink shows the remaining portion. Monthly cards derive completed workout count and recorded minutes from `MonthlyStats`; PRs use the shared history-derived records and exclude baselines. Cards open detail sheets with logged date/time. Missing recorded time displays a dash. Future, test, incomplete, and rest-only entries are excluded from dashboard activity. Routines still open their detail page before a session starts. The small weekly strip opens accessible day rows rather than using tiny individual touch targets.

## Settings cards

Settings uses top-aligned pale Weight and Distance cards with inset unit segments and lavender/lime icon circles. The cards stack on narrow screens or with larger text. A rounded Workout preferences group contains white (theme-surface in dark mode) inset rows, label-aligned descriptions, and compact lavender/coral switches with full 44px tap areas. Keep units as direct selections and preferences as switches, not dropdowns. Preserve custom timer durations alongside the standard choices. Thin round header buttons match the reference; the calendar scrolls to the weekly goal, whose changes still take effect next Monday. Reference-only features such as location, height, and activity tracking are not included. Preview images are in `docs/design/previews/settings-{light,dark}.png`.

## Stats and exercise progress

Stats follows the supplied activity and journal references: a compact centered header, Month/Year pills, pale rounded groups, white inset metric cards, and lavender/lime/coral icon circles. The calendar changes the displayed period. Keep the seven overview cards: Workouts, Time, Personal Records, Strength, Cardio, Muscles, and Active days. Each opens a draggable detail sheet with the same nested surfaces and one drag handle. Cards stack at narrow widths or enlarged text sizes.

The duration ring displays total recorded workout time; its fill represents how many workouts have a recorded duration, with an explicit coverage caption. It does not imply a time goal. Activity pills and bars show actual session counts; year entries drill into a month. Strength and muscle bars compare completed sets, while cardio retains recorded time, distance, heart rate, and effort with missing data labeled. Journal-style entries include the full logged date/time and link to the saved workout. PR detail sections retain Recent PRs and All-time bests, with previous-best values and links to individual exercise progress. Exercise progress uses the same pale sections, white session cards, and lavender chart.

Generate populated previews in both themes with:

```
flutter test test/design/stats_reference_preview_test.dart --dart-define=CAPTURE_DESIGN=true
```

The 20 images (including the calendar) are written to `/tmp/sweatmark-stats-reference-*-{light,dark}.png`. They use local fixtures only. Selected review captures are saved in `docs/design/previews/`. Layout tests also exercise every detail sheet at 320px with 1.5× text, period navigation, logged values, and PR-to-progress navigation.

## Browse and exercise picker

Browse follows the exercise-list reference: search is the first control, followed by muscle and equipment pills, a Create Custom Exercise row, and an alphabetical list. The pale panel background, white rounded thumbnail tiles, lavender plus and info icons, and restrained 15px exercise names use the shared palette. Keep the whole row flat; the image tile provides the visual container. Filter pills open rounded choice sheets with a visible selected state and an Any option. Pills stack with enlarged text; long exercise names wrap.

The workout/routine picker shares this list with a close button and Choose exercises header. Selecting a row returns the exercise; tapping its info button only opens details. Browse row taps open the same info sheet. Custom exercise creation retains its existing account-owned persistence. Search retains loaded catalog entries and filter options, searches longer queries through the notifier, and restores cached results when cleared. No classification or workout data migrations are part of this visual update.

`flutter test test/design/library_reference_preview_test.dart --dart-define=CAPTURE_DESIGN=true` captures Browse and both filter sheets in light/dark mode at `/tmp/sweatmark-library-reference-*-{light,dark}.png`. Fixture previews use the real missing-image fallback; the app continues to display cached exercise illustrations when available. Review copies are saved as `docs/design/previews/browse-*.png`.
