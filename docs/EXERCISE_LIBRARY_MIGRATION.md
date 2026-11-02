# Exercise library migration plan — ExerciseGymGifsDB

Status: proposal, November 1, 2026. Nothing implemented.

Candidate source: [ExerciseGymGifsDB](https://jahelcuadrado.github.io/ExerciseGymGifsDB/)
(`JahelCuadrado/ExerciseGymGifsDB`, release `v1.1.0`, served by jsDelivr).

## Blocker: media rights

The repository has **no license**, and its README states the GIFs were
collected from the internet, the maintainer does not own their copyright and
cannot grant rights to them. Several IDs (`lever-seated-hip-abduction`,
`…-male`, `…-v-2`) follow ExerciseDB/Gymvisual naming, which suggests
commercially licensed animations. Without a license, even the JSON text
(names, instructions) is all-rights-reserved by default.

`CLAUDE_HANDOFF.md` already lists "confirm exercise-media rights" as a release
blocker. Shipping these GIFs in a TestFlight or App Store build would add an
unlicensed-media risk rather than remove one.

Decision needed from the owner before any implementation:

1. **Use it as-is** — owner accepts the risk in writing; plan proceeds.
2. **Structure only** — adopt its taxonomy and coverage, but source names and
   media from a licensed or public-domain set (e.g. free-exercise-db, which is
   public domain and is where existing `free_` IDs came from; or a paid
   ExerciseDB/Gymvisual license).
3. **License the media** — contact the original animation owner, then use this
   dataset's structure with properly licensed GIFs.

The technical plan below works for all three; only the asset source changes.

**Decision (November 1, 2026):** the owner chose **option 1 — use as-is**,
accepting the unlicensed-media risk described above. Revisit before any public
App Store release; the media source is isolated so it can be swapped.

## What the dataset provides

- 1,323 exercises; 19 muscles, 12 equipment types, 7 body parts, 4 categories
  (1,224 strength, 56 stretching, 29 cardio, 14 plyometrics). No duplicate names.
- English and Spanish (`/api/{lang}/exercises.json`, ~1.2 MB each).
- Fields: `id` (`biceps/barbell-curl`), `slug`, `name`, `muscle`, `bodyPart`,
  `equipment`, `category`, `secondaryMuscles`, `instructions[]`, `gifUrl`.
- GIFs ~300 KB each (~400 MB total) on jsDelivr. Static; no keys or quotas.
- Covers SweatMark's required pairs: `adductors/lever-seated-hip-adduction`
  and `abductors/lever-seated-hip-abduction` are distinct.

## Today

- `exercise_db_repository.dart` pages the Firestore `exercisedb_exercises`
  cache, filled by Cloud Functions (`downloadAllExercises`,
  `downloadFromGymFit`, `refreshGymFitImage`, …).
- `seed_exercises.dart` / `exercise_data.dart` (`EXERCISE_LIBRARY`) hold local
  fallbacks with `ex_` IDs.
- Logged history mixes `custom_`, `free_`, `exercisedb_` and `ex_` IDs. PRs,
  progress and stats key on these IDs.

## Plan

### 1. Pinned, bundled catalog
- Script `scripts/import_gym_gifs.mjs`: download `en` (and `es`) from a pinned
  tag, validate fields, write `assets/exercises/catalog_v1.json`. Fail on
  schema drift. Never fetch "latest" at runtime.
- Bundle the JSON in the app so the library works offline on first launch and
  no longer depends on Firestore reads.
- Media: stream GIFs with `CachedNetworkImage` from a pinned URL (option 1), or
  from our own Firebase Storage copy (options 2–3). Keep the local icon
  fallback.

### 2. Model mapping
- New IDs: `gg:biceps/barbell-curl` (namespaced, stable, never reused).
- `muscle` → primary muscle group used by Stats; `secondaryMuscles` kept.
- `category` → `ExerciseType`: cardio → cardio; stretching → timed hold;
  strength/plyometrics → weighted or bodyweight from `equipment`.
- `instructions[]` → the how-to screen.
- Spanish names stored for a later locale switch; not exposed yet.

### 3. History compatibility (most important)
- Never rewrite saved workouts, routines or custom exercises.
- Add an alias table `oldId → gg:` built by normalized-name matching plus a
  reviewed manual list for ambiguous matches; unmatched IDs stay as they are.
- `PRService`, exercise progress and Stats resolve IDs through the alias table
  so a bench press logged under `free_Barbell_Bench_Press` and one under
  `gg:pectorals/barbell-bench-press` share one record history.
- Display names keep going through `exerciseDisplayName` (saved name first).

### 4. Library UI
- Filters from the dataset's muscle and equipment lists.
- Search over name, muscle and equipment, all local.
- Custom exercise creation unchanged.

### 5. Retire the old pipeline (after release, separately)
- Stop reading `exercisedb_exercises` and GymFit refresh paths in the app.
- Do not delete deployed functions until inspected (see handoff); remove them
  in a dedicated backend change with a backup.

### 6. Verification
- Import script test on a fixture; catalog schema test; alias coverage report
  for every exercise ID in the owner's history.
- PR/progress continuity test across an aliased pair.
- Offline first launch, search speed with 1,323 items, 320 px / large text.
- On-device check of GIF loading and cache size.

## Progress — November 1, 2026

Done: steps 1–4 and their tests.
- `scripts/import_gym_gifs.mjs` (+ `node --test scripts/import_gym_gifs.test.mjs`)
  writes `assets/exercises/catalog_v1.json` (1,323 exercises, 923 KB).
- `ExerciseCatalog` loads it at startup; the repository no longer reads
  Firestore for browsing or search.
- `ExerciseCatalog.canonicalId` maps older IDs by exact word-set match or a
  manual list; PRs, exercise progress, "Last time" and library de-duplication
  use it. Custom exercises are never merged.

- Media is bundled: `scripts/build_exercise_media.py` converts every GIF to a
  360 px animated WebP in `assets/exercises/media/` (92.6 MB for 1,323 files,
  versus ~370 MB of GIFs). `ExerciseMedia` shows the bundled file instantly and
  offline, and falls back to the network only for unknown URLs or a missing
  file. The download cache (`build/exercise_gifs/`) is git-ignored.

Open:
- ~~Owner review of `docs/EXERCISE_ALIAS_REVIEW.md`~~ — approved and applied;
  simulator history now maps 26 of 35 non-custom exercises; the other 9 are the "keep separate" rows.
- Same coverage report on the TestFlight account.
- Step 5 (retiring the old pipeline).
- Media is tracked with Git LFS (`.gitattributes`). Every machine that
  builds the app needs `git lfs install` before cloning; without it the
  files are LFS pointers and the app falls back to network media.
- Measure the release app size on device.

## Estimate

Roughly 2–3 focused sessions after the rights decision: import and bundling
(1), alias mapping and PR continuity (1), UI, tests and device checks (0.5–1).
