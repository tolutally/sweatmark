# Sweatmark Audit – Incomplete Features & Potential Vulnerabilities

## Incomplete Features / TODOs
- AI coach service: `lib/services/ai_coach_service.dart` – TODO placeholder for Gemini API calls; feature not implemented.
- Notification deep links & token sync: `lib/services/notification_service.dart` – TODOs to send refreshed FCM token to backend and to navigate users to the correct screen on notification taps (foreground, background, terminated). Users currently land nowhere specific.
- Android signing & app ID placeholders: `android/app/build.gradle.kts` – TODO comments for unique applicationId and release signing config. Release builds may be using defaults/unsigned.
- Navigation after notification tap (iOS/Android) is still TODO (same file as above), so UX is incomplete.
- AI/PR notifications: workout completion/PR notifications now fire, but they are not wired to navigate anywhere (same TODO as above).

## Potential Vulnerabilities / Risks
- Secret key committed: `AuthKey_9P27Z4DS2F.p8` (Apple push key) is present in the repo; should be removed from source control and rotated. Keeping it in git is a credential leak risk.
- Notification token handling: FCM/APNS tokens are fetched but never persisted server-side; if backend expects tokens, missing sync will break targeting and can lead to stale tokens (availability risk). Add secure upload with auth.
- Android signing config TODO: Release signing not configured in `android/app/build.gradle.kts`; shipping an unsigned or debug-signed build is a supply-chain risk (easy tampering).
- Notification tap handlers are TODO: Lack of routing can lead to confusing flows and possible spoofing if later added without validation of payload.
- General credential hygiene: Ensure `google-services.json` and any API keys are scoped to the app and restricted; audit CI secrets. Rotate the exposed Apple key above.

## Recommendations (next steps)
1) Remove `AuthKey_9P27Z4DS2F.p8` from the repo, rotate the Apple key, and load it via secure config/CI secret.
2) Implement token upload endpoint + call in `notification_service.dart` (on token fetch/refresh) and add navigation handling for notification taps.
3) Configure unique `applicationId` and proper release signing in `android/app/build.gradle.kts`.
4) Implement Gemini AI coach service or hide the entry point until it’s ready.
5) Add tests/QA checklist to verify notifications (foreground/background/terminated) and secure routing.
