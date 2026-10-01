# Contributing

Thanks for helping improve Human / Duo Fold. Keep changes small, explain the behavior they affect, and include tests for challenge validation or callback-contract changes.

## Development

- Use Bitrig with Xcode 27.1 and the iOS 27.1 SDK for the app. Edit `Project.json` for project settings; generated Xcode files are not source.
- Run `swift test` for the pure Swift core and `node --test Website/*.test.mjs` for the static website.
- Build the Duo Fold target after changing app code or project settings. Test fold interactions on a physical iPhone Duo before claiming hardware acceptance.
- Keep sensor capture and validation separate from view presentation. Do not synthesize hinge samples to make a challenge pass.
- Preserve the browser-to-app-to-browser flow when changing the `duofold://verify` link contract.

For security-sensitive proposals, read [SECURITY.md](SECURITY.md) first. The present callback is intentionally demonstration-grade.
