# YouTube Premium Wiring Plan

This plan covers how PhonoDeck should connect a user's Google/YouTube account while staying inside official YouTube API and playback rules.

## Critical Boundary

YouTube Premium is not an API entitlement that lets a third-party macOS app download, extract, cache, or natively stream YouTube Music audio. Premium should be treated as a user benefit that official YouTube playback surfaces may honor after sign-in.

PhonoDeck must not:

- download YouTube audiovisual content;
- make YouTube content available for offline playback;
- extract or isolate audio from YouTube videos;
- use undocumented YouTube Music endpoints;
- run hidden/background YouTube players;
- modify, obscure, or replace the YouTube player or attribution.

## P0 Goal

Let the user connect a Google account so PhonoDeck can display account-aware YouTube metadata and launch policy-compliant YouTube playback, while keeping Plex/local media as the native playback path.

## Account Setup

1. Create one Google Cloud project for PhonoDeck.
2. Configure OAuth consent screen with the PhonoDeck name, privacy policy, contact email, and YouTube/Google disclosures.
3. Create OAuth credentials for an installed desktop app.
4. Use a browser-based OAuth flow from macOS, preferably through `ASWebAuthenticationSession`.
5. Store tokens in Keychain only.
6. Provide a Disconnect Google action that revokes/deletes tokens and deletes cached authorized data.

## Scope Phases

| Phase | Feature | Scope posture |
| --- | --- | --- |
| P0 unauthenticated | Public search/discovery | Use YouTube Data API without user auth where possible, or API key if needed |
| P0 account connect | Account identity and user's YouTube channel context | Minimal identity plus read-only YouTube scope if required |
| P0 library surfaces | User playlists/subscriptions/liked-video references where officially exposed | `https://www.googleapis.com/auth/youtube.readonly` requested in context |
| P1 playlist actions | Create/update YouTube playlists from explicit user action | Escalate to write scopes only when the feature exists |

Do not request write scopes during initial sign-in.

## Playback Strategy

### Allowed P0 Strategy

- Use visible, official YouTube playback surfaces for YouTube content.
- Prefer an embedded YouTube player for playable video IDs where the IFrame Player API supports the use case.
- Keep YouTube attribution visible.
- Keep Autoplay off unless the user clearly initiates playback.
- For YouTube Music-specific pages that are not supported by the IFrame API, open or host the official YouTube Music web experience without interfering with its UI.

### Not P0

- Native `AVPlayer` playback of YouTube streams.
- YouTube downloads/offline.
- Background-only YouTube audio.
- Converting YouTube Music into Plex/local tracks.

## Premium Behavior

What Premium can plausibly help with:

- Ads/background behavior inside official YouTube or YouTube Music surfaces, according to Google's own implementation.
- Access to Premium-only features in the official web/player session if Google exposes them there.

What Premium does not give PhonoDeck:

- A documented native audio stream URL.
- A documented offline-download API.
- Permission to bypass player UI, ads, attribution, or playback restrictions.
- A documented YouTube Music library API equivalent to Apple Music or Spotify Web API.

## UX Model

- Settings > Accounts > YouTube: Connect Google, Disconnect, Revoke instructions, cached-data deletion.
- Search results: show clear source badges and YouTube attribution.
- Track/action rows: show YouTube actions only when they are supported by official APIs.
- Playback: display a visible YouTube player region or open official YouTube Music for unsupported playback flows.
- Downloads: show unavailable for YouTube with a short reason.

## Implementation Tasks

1. Add `GoogleAccountStore` backed by Keychain.
2. Add `GoogleOAuthClient` using `ASWebAuthenticationSession`.
3. Add `YouTubeDataClient` with quota-aware request wrappers.
4. Add `YouTubeCapabilityProvider` that reports search, read-only playlist access, embedded playback, and unavailable downloads/native playback.
5. Add visible YouTube playback surface prototype with IFrame Player API in `WKWebView`.
6. Add privacy/disconnect UI and token revocation.
7. Add tests for scope escalation, capability gating, and no-download policy.

## Open Questions

- Does the embedded player in `WKWebView` preserve the user's Google/Premium web session reliably enough for daily use?
- Which YouTube Music pages can be hosted without creating a browser-wrapper product that conflicts with YouTube policy?
- Should P0 use YouTube Data API search only, or should all YouTube playback launch in the user's default browser until the embedded-player policy is fully validated?
- Will quota needs require an audit before meaningful private beta use?
