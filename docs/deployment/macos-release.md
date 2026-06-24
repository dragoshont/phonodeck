# macOS Release Engineering

Phase 9 prepares PhonoDeck for distribution engineering without performing a public release. It produces a local unsigned artifact, validates bundle metadata, and documents the operator-run signed/notarized path. Final live validation, release notes, legal/privacy publication, and go/no-go remain Phase 10.

## Local Unsigned Package

Run:

```sh
make release-preflight
make package-local
```

Outputs are written to `build/release/`:

- `PhonoDeck.app` — unsigned Release app bundle.
- `PhonoDeck-local-unsigned.zip` — compressed local artifact.
- `metadata.json` — bundle identifier, version, build, signing status, artifact name, SHA-256, and timestamp.

The local package script builds with `CODE_SIGNING_ALLOWED=NO` and forces `GOOGLE_OAUTH_CLIENT_SECRET` empty for the packaged app. It fails before compression if the expanded app bundle contains a non-empty OAuth client secret.

## Release Preflight

`make release-preflight` validates:

- required local tools: `xcodebuild`, `xcodegen`, `plutil`, `codesign`, `ditto`, `shasum`;
- optional notarization tool availability through `xcrun notarytool`;
- `project.yml` version/build/bundle metadata;
- `Config/Info.plist` required keys;
- `Config/PhonoDeck.entitlements` sandbox/network/user-selected file entitlements;
- `Config/BuildSettings.xcconfig` optional local secret include;
- `Config/Secrets.xcconfig` remains ignored and has no release-package client secret value;
- optional signing/notarization environment variable presence.

Preflight reports only presence/readiness. It must not print Apple IDs, team IDs, certificate identities, API keys, app-specific passwords, OAuth secrets, or token values.

## Operator Signing And Notarization

Real signing and notarization are operator-run. Do not store credentials in this repository, run artifacts, prompts, logs, or chat.

Recommended local environment names:

- `PHONODECK_DEVELOPER_ID_APPLICATION` — presence indicates a Developer ID Application signing identity is configured locally.
- `PHONODECK_NOTARY_KEYCHAIN_PROFILE` — presence indicates `xcrun notarytool store-credentials` has already stored credentials in the user keychain.

Operator flow:

1. Rotate the previously exposed Google desktop OAuth client secret in Google Cloud before OAuth use.
2. Confirm `make release-preflight` passes; optional signing/notarization warnings mean the local Mac is not yet configured for public distribution.
3. Build and archive from Xcode or with `xcodebuild archive` using a Developer ID Application identity configured in the local keychain.
4. Export the signed app using Xcode Organizer or `xcodebuild -exportArchive` with an operator-owned export options plist stored outside this repo if it contains team-specific data.
5. Submit the signed archive with `xcrun notarytool submit --keychain-profile "$PHONODECK_NOTARY_KEYCHAIN_PROFILE" --wait`.
6. Staple with `xcrun stapler staple` and verify with `spctl --assess --type execute --verbose`.
7. Record only pass/fail evidence and artifact hashes in Phase 10. Do not paste notarization credentials, certificate names, team IDs, or provider secrets.

## Phase 10 Clean-Install Smoke Prep

Clean-install validation belongs to Phase 10. Preparation checklist:

1. Install the packaged app in a clean location, not over a running app.
2. Confirm first launch opens without stale Now Playing or provider state.
3. Confirm `defaults delete ro.hont.phonodeck` resets app preferences only.
4. Do not delete Keychain provider tokens except through the app's Disconnect actions or a deliberate Phase 10 recovery step.
5. Confirm Google/Spotify/Plex disconnect actions remove credentials and leave cache-clearing behavior explicit.
6. Confirm YouTube/Spotify media downloads remain unavailable and Plex/Own Files policy stays source-honest.
7. Confirm final privacy/legal copy and provider live/revocation tests before go/no-go.

## Boundaries

Phase 9 does not sign, notarize, staple, upload, publish, rotate provider credentials, run live provider writes, publish release notes, or approve release. Those are Phase 10/operator tasks.