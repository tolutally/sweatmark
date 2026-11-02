# Exercise alias review

Older logged exercises that did not match the new catalog automatically.

**Status:** all High and Medium rows approved by the owner and applied on
November 1, 2026 (21 old IDs). "Keep separate" rows stay as they are.
Approving a row makes its history, PRs and "Last time" values continue under
the catalog exercise (`ExerciseCatalog._manualAliases`). Saved workouts are not
rewritten, so a row can be removed later.

Source: the simulator account's history, November 1, 2026. The TestFlight
account may contain other names; run the same report there before release.

Already matched automatically: Jump Rope, Dumbbell Standing Calf Raise, Band
Assisted Pull-Up, Barbell Curl, Front Dumbbell Raise, and both hip machines.
Custom exercises are never merged.

| Logged name | Old ID | Proposed catalog exercise | Confidence |
| --- | --- | --- | --- |
| 45 degree hyperextension | `exercisedb_exr_41n2hRH4aTB379Tp` | `gg:spine/hyperextension` | High |
| Arnold Press | `exercisedb_exr_41n2hMRXm49mM62z` | `gg:delts/dumbbell-arnold-press` | High |
| Dips - Triceps Version | `free_Dips_-_Triceps_Version` | `gg:triceps/triceps-dip` | High |
| Dumbbell Bench Press with Neutral Grip | `free_Dumbbell_Bench_Press_with_Neutral_Grip` | `gg:triceps/dumbbell-neutral-grip-bench-press` | High |
| Lateral Raise | `exercisedb_exr_41n2hjuGpcex14w7` | `gg:delts/dumbbell-lateral-raise` | High |
| Lateral Raises | `ex_lateral_raise` | `gg:delts/dumbbell-lateral-raise` | High |
| Seated Side Lateral Raise | `free_Seated_Side_Lateral_Raise` | `gg:delts/dumbbell-seated-lateral-raise` | High |
| Single-Arm Dumbbell Row | `ex_single_arm_db_row` | `gg:upper-back/dumbbell-one-arm-bent-over-row` | High |
| Stationary Bike Run | `exercisedb_exr_41n2hXYRxFHnQAD4` | `gg:cardio/stationary-bike-run-v-3` | High |
| Bench Press | `exercisedb_exr_41n2hxnFMotsXTj3` | `gg:pectorals/barbell-bench-press` | Medium — assumes barbell |
| Dumbbell Shoulder Press | `free_Dumbbell_Shoulder_Press` | `gg:delts/dumbbell-seated-shoulder-press` | Medium — seated vs standing |
| Seated Shoulder Press | `exercisedb_exr_41n2hs6camM22yBG` | `gg:delts/dumbbell-seated-shoulder-press` | Medium — assumes dumbbell |
| Front Raise | `exercisedb_exr_41n2howQHvcrcrW6` | `gg:delts/dumbbell-front-raise` | Medium — assumes dumbbell |
| Tricep Pushdown | `ex_tricep_pushdown` | `gg:triceps/cable-pushdown` | Medium |
| Lat Pulldown | `ex_lat_pulldown` | `gg:lats/cable-lat-pulldown-full-range-of-motion` | Medium |
| Leg Press | `free_Leg_Press` | `gg:glutes/sled-45-leg-press` | Medium — machine type |
| Jogging, Treadmill | `free_Jogging_Treadmill` | `gg:cardio/run` | Medium |
| Stationary Bike / Bicycling, Stationary | `ex_stationary_bike`, `free_Bicycling_Stationary` | `gg:cardio/stationary-bike-walk` | Medium |
| Jumping Jack / Jumping Jacks | `exercisedb_exr_41n2hupxPcdnktBC`, `ex_jumping_jacks` | `gg:cardio/jack-jump-male` | Medium |

Keep separate (no close equivalent): Ab Crunch Machine, Alternating Deltoid
Raise, Cable Chest Fly, Cable Crunch, EZ-Bar Skullcrusher, Plie Dumbbell
Squat, Shotgun Row, Stair Up, Wide-Grip Lat Pulldown.
