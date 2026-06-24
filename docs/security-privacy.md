# Security and Privacy

## Token Handling

- Store Google, Spotify, and Plex tokens in Keychain.
- Keychain token items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Never commit client secrets or user tokens.
- `Config/Secrets.xcconfig` is ignored and is for local developer configuration only. Do not store secret values in docs, run artifacts, logs, or chat. If a secret is exposed in logs/chat, rotate it in the provider console.
- Request the narrowest OAuth scopes needed for currently implemented features. Google currently uses `https://www.googleapis.com/auth/youtube` because PhonoDeck implements playlist create/add/remove; a read-only scope would not cover those user-facing write flows.
- Provide local disconnect actions for each account. Provider-side revocation is verified separately with live test-account evidence before release GO.
- Delete cached authorized data when an account is disconnected, within the stricter service requirement when applicable. Google disconnect clears local YouTube authorized cache/default keys as well as the Keychain token.

## YouTube Requirements

- Provide an accessible privacy policy before user-authorized YouTube features.
- Link to YouTube Terms of Service and Google Privacy Policy where required.
- Do not request future scopes before the feature exists.
- Delete user-authorized data when consent is revoked.
- Refresh or delete stored API data according to YouTube storage windows.
- YouTube media downloads, hidden playback, copied cookies, stream extraction, and undocumented YouTube Music metadata endpoints are not implemented.

## Spotify Requirements

- Provide account disconnect.
- Delete personal data when the user disconnects Spotify.
- Attribute Spotify content when displayed.
- Do not use Spotify content for ML training, derived metrics, or cross-service stream mixing.

## Plex Requirements

- Treat Plex server tokens as secrets.
- Respect server download permissions.
- Keep downloaded personal media in the app container unless the user explicitly exports it.
- Do not download Plex-provided streaming content.
- Plex token-bearing URLs are redacted before logging and are not shareable PhonoDeck URLs.

## Local Cache And Data Controls

- Metadata and artwork cache clearing is separate from credential disconnect.
- Clearing local metadata/artwork does not delete account credentials, provider libraries, playlists, or user-owned files.
- Google account disconnect deletes the Google Keychain token and local YouTube authorized metadata keys.
- Spotify and Plex disconnect delete local Keychain credentials and return the source adapter to a not-connected state. No provider-specific authorized local cache is stored for Spotify or Plex yet.
- Local restore is deterministic: stored Spotify/Plex credentials can restore Settings readiness without opening a browser or proving live provider identity. Live provider profile refresh/revocation evidence remains a separate validation step.
- Additional live provider revocation tests are deferred until a live-account validation phase.

## Logging And Redaction

- Use `OSLog` privacy annotations: song titles and user-facing personal content should be `.private`; counts/status/source IDs can be `.public`.
- URLs that may contain tokens or secrets must pass through `RedactedURL` before logging.
- `RedactedURL` redacts common sensitive query names case-insensitively, including token and secret parameters.

## Entitlement Rationale

- App sandbox is enabled.
- Network client is required for provider APIs and official embedded web players.
- Network server is required for local loopback OAuth callbacks only.
- User-selected read/write file access is reserved for Own Files imports and future user-selected storage flows.
- Signing, notarization, package hardening, and final release privacy/legal review are deferred to Phase 9/10.
