# OAuth and Token Plan

## Storage

- Use Keychain for all OAuth refresh tokens, access tokens, Plex tokens, and device secrets.
- Use app-group Keychain only when the iOS/watch architecture requires it later.
- Do not store tokens in `UserDefaults`, plain JSON, `.plist`, or checked-in config.

## Google and YouTube

Initial setup:

1. Create one Google Cloud API Project for PhonoDeck.
2. Enable the YouTube Data API only when the corresponding feature is implemented.
3. Configure OAuth consent screen and desktop app credentials.
4. Request only scopes needed by implemented features.
5. Use system-browser OAuth with PKCE and a loopback redirect for macOS desktop. Do not use `WKWebView` for Google login.

Likely scope phases:

| Phase | Feature | Scope posture |
| --- | --- | --- |
| P0 public search | YouTube search/discovery | API key or non-authorized requests where possible |
| P0 user playlists | Read user playlists/subscriptions if implemented | Read-only YouTube scopes in context |
| P1 playlist management | Create/update YouTube Music playlists through official YouTube account playlist APIs | Write scopes only when the UI supports the action |

Rules:

- Do not request future scopes early.
- Provide Google/YouTube revocation and cached-data deletion.
- Link YouTube Terms of Service and Google Privacy Policy in the privacy surface.
- Refresh or delete stored API data according to YouTube's storage rules.

## Spotify

Initial setup:

1. Create one Spotify Developer app for PhonoDeck.
2. Configure redirect URI for macOS OAuth callback.
3. Use Authorization Code with PKCE for native app flow if available in the selected auth library.

Likely scopes:

| Feature | Scope |
| --- | --- |
| Profile/subscription | `user-read-private` |
| Current playback | `user-read-currently-playing`, `user-read-playback-state` |
| Spotify Connect control | `user-modify-playback-state` |
| Library | `user-library-read`, later `user-library-modify` |
| Playlists | `playlist-read-private`, `playlist-read-collaborative`, later `playlist-modify-private`, `playlist-modify-public` |

Rules:

- Do not use Spotify metadata, artwork, or previews as standalone content.
- Attribute Spotify content and link back to Spotify.
- Provide disconnect and personal-data deletion.

## Plex

Initial options:

- Manual token entry for private early development.
- Plex PIN/auth flow for production-quality sign-in.
- Manual server URL fallback for local network edge cases.

Token handling:

- Store Plex token in Keychain.
- Store server identity, base URL, and library section IDs in app storage.
- Respect secure connection settings and server download permissions.
