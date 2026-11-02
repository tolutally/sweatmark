# Retired app features

These sources are preserved for reference, not imported by the current app. The simplified app removes recovery scoring, flame/tier gamification, old daily/custom streaks, scheduling, the profile dashboard, broad analytics, the unused AI placeholder, the background timer service, and sharing-oriented screens.

The old profile UI tests move with their retired screen. They were already failing because their expected edit/location controls no longer matched the old UI. Current screen tests cover the simplified logging home and saved-workout summary. Profile model tests remain active.

Do not reintroduce these files directly: their relative imports and feature assumptions reflect the older app. This archive preserves prior uncommitted work; no user data or cloud records were removed.
