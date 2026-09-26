# Duo Fold

A local-first physical CAPTCHA for iPhone Duo. Native SwiftUI app and framework-free reference website. No backend, accounts, or simulated sensor path.

## Run

Build and run the **Duo Fold** target in Bitrig with the installed iOS 27.1 SDK. Minimum deployment version is 27.1; iPhone is the only target family. The project keeps Bitrig's scaffold bundle identifier until device signing requires a permanent identifier through Bitrig.

Publish the contents of `Website/` on an HTTPS static host (retain relative paths). No configuration or build step is required. Open that URL in Safari on the Duo with the app installed and tap **Verify**. The callback is derived from the deployed page URL. Use **Open Duo Fold** if Safari blocks automatic app opening.

Flow: **Verify → Bend to the target angle → fold → fold → hold → Checking… → Human Verified → Verified ✓**.

The site must return to the same browser profile/origin that started verification. It uses localStorage for the pending session across tabs, and sessionStorage to retain the successful display in the returning tab. Only the latest pending session is active. This is intentionally demo-level trust; forged callbacks and modified clients are outside scope.

## Architecture and timing

- `App/Core/`: pure generator, sample/trace types, event reducer, replay validator, and URL contract. Also compiled as a Swift package for deterministic tests.
- `HingeCapture`: real `onHingeChange` input plus a `ContinuousClock`. No timers generate sensor readings.
- `FoldSession`: main-actor lifecycle, attempt cancellation, feedback events, local validation, and browser return.
- `FoldProtractor` / `ContentView`: full-screen semicircle angle ring, fixed target marker and tolerance zone, live and target angle readouts, progress markers, and green completion checks. `HoldCheckRing` shows accumulated final-hold progress around a check; `CompletionCheckmark` draws the slower success animation. Reduce Motion shows completion statically. Other interface colors are monochrome. `FoldFeedback` owns haptic triggers. Layout adapts to Duo's reserved regions.

Each challenge has three targets in 135°–175°, separated by 30°–40°, with inclusive ±5° tolerance. No accepted match is below 130°. The first two complete on raw entry. The third accumulates 800 ms of monotonic elapsed time while the latest real reading is in range. A subsequent exit pauses; re-entry resumes. Stationary silence is allowed. Inactivity or explicit capture loss invalidates the attempt, so background time can never finish a hold. Generation identifiers and task cancellation isolate timers from replacement requests.

Validation replays the raw events and completion timestamp, rather than trusting UI completion markers. The initial angular-speed ceiling is **1,440°/s** in `TrajectoryValidator.Policy`. No adjacent-angle cap applies. One observed intermediate reading must lie between consecutive target tolerance regions. Calibrate the speed ceiling from real Duo before tightening it. A maximum of 30,000 raw samples bounds a single attempt's memory.

## Tests

```sh
swift test
node --test Website/*.test.mjs
```

Core tests cover stationary and accumulated holds, tolerance boundaries, order, correction, sparse callbacks, missing intermediates, implausible motion, timestamp validity, capture interruption, generation, and callback parsing. Website tests cover encoding, pending session matching, new-tab return, reload, replay, manual fallback, unavailable storage, and phase timing.

## Device acceptance and measurement

Still requires physical Duo and an HTTPS deployment:

- Website opens installed app; real folds drive silhouette; hold completes without repeated stationary events; callback returns to Verified.
- Book/table poses, closed/open transitions, rotation, Split View, large Dynamic Type, light/dark appearance, Reduce Motion, VoiceOver, contrast, and haptics.
- Interrupt a hold with Home/lock/system UI; retry must use a fresh challenge. Open another verification URL during a hold; old timer must never verify it.
- Confirm unavailable state on a non-Duo device and manual Return to website recovery when URL opening fails.

After validation, native logs include sample count, maximum callback interval, and maximum observed angular speed. Safari's console prints launch, challenge, local validation, browser return, and full round-trip durations in milliseconds. The completed tab also keeps these in `sessionStorage['duofold.completed.v1']` for inspection. Cross-app times use device wall-clock timestamps and are estimates; challenge and validation use a monotonic clock. Measure under five seconds; do not assume it.

The protractor uses brief display-only interpolation between raw hinge updates; capture and validation never use those interpolated values. Reduce Motion disables interpolation. System layout handles reserved fold regions; essential controls stay within the arrangement's primary region. Physical folding is required even with VoiceOver; an alternative verification route is outside scope.

Backend work is deferred until this entire local flow passes real-device acceptance.
