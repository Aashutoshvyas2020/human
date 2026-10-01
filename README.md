# Human · Duo Fold

An experimental, local-first human-verification flow for iPhone Duo. The native SwiftUI app asks a person to match three hinge angles; a small static website opens the app and receives the result.

This repository is a working prototype, not a secure CAPTCHA service. Validation runs on the device, and the browser trusts a URL callback. A modified app or forged callback can claim success. Do not use it to protect accounts, payments, or other sensitive actions.

## What is here

| Path | Purpose |
| --- | --- |
| `App/` | iOS app, hinge capture, fold UI, haptics, and session lifecycle |
| `App/Core/` | Challenge generation, trace validation, and deep-link contract |
| `Website/` | Dependency-free HTTPS demo page and browser tests |
| `Tests/` | Swift package tests for the core logic |
| `Project.json` | Bitrig-managed iOS project configuration |
| `Package.swift` | Standalone Swift package for testing `App/Core/` |

## Try the flow

1. Build and run **Duo Fold** in Bitrig with Xcode 27.1 / iOS 27.1 SDK. The app targets iOS 27.1 and iPhone Duo. The Bitrig simulator can show the UI; a physical Duo is needed for real hinge acceptance.
2. Host the contents of `Website/` at an HTTPS URL, preserving the relative files. A static host is enough; no build or backend is required. GitHub Pages can serve the `Website/` directory through a Pages workflow or published branch, but Pages is not configured by this repository.
3. On the Duo, open that URL in Safari and tap **Verify**. If Safari blocks automatic opening, tap **Open Duo Fold**.
4. Match the three displayed angles. Hold the final angle to finish. The app returns to the same HTTPS page, which displays **Verified ✓**.

For a direct app-launch check, use this URL with the installed app:

```text
duofold://verify?session=ABC123abc456&callback=https%3A%2F%2Fexample.com
```

`example.com` is only a placeholder return destination. For the complete browser experience, start from the hosted demo page so it creates and stores a fresh session and supplies its own callback URL.

## How verification works

The site creates a 12-character session ID, stores it in browser storage, and opens `duofold://verify` with an HTTPS callback. The app generates three separated targets between 135° and 175°, checks real hinge samples in order with ±5° tolerance, and requires an accumulated 800 ms hold on the final target. The core validator replays the raw trace before the app opens the callback with `result=success`. The site accepts only a return matching its pending session.

The current speed policy allows up to 1,440°/s and needs calibration on physical hardware. No fake sensor or timer-generated hinge readings are included. Backgrounding during an attempt invalidates it. The browser's pending state is local to its origin and profile.

## Test

```sh
swift test
node --test Website/*.test.mjs
```

Swift tests cover generation, ordering, tolerance, holds, interruptions, trace validity, and URL parsing. Browser tests cover launch URLs, pending sessions, return matching, replay, and storage failures. The Swift package tests core logic on macOS; they do not exercise iOS hinge hardware.

## Current limits

- Requires iOS 27.1 SDK for Duo APIs. Physical Duo end-to-end behavior, accessibility poses, and timing still need device acceptance.
- No server-issued challenge, server-side proof, replay protection, or cryptographic attestation. URL callbacks and browser storage are suitable for demonstration only.
- No live demo URL or GitHub Pages deployment is configured here.
- App retains Bitrig's scaffold bundle identifier until device signing is configured.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development notes and [SECURITY.md](SECURITY.md) for the security boundary.

## License

MIT. See [LICENSE](LICENSE).
