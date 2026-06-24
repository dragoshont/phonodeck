# YouTube Policy Findings

Checked on 2026-06-18 against official YouTube API Services docs. This is engineering risk analysis, not legal advice.

## What We Are Confident About

PhonoDeck can use native UI for YouTube-related browsing and organization when the data comes from documented YouTube API Services and we follow branding, attribution, scope, storage, and user-consent rules.

PhonoDeck must not use a hidden player or native controls that conceal/replace the official YouTube player for YouTube audiovisual playback.

## Official Constraints That Matter

Source: YouTube API Services Developer Policies.

- API clients must use only documented YouTube API Services and must not reverse engineer undocumented services.
- API clients must not download, import, back up, cache, or store copies of YouTube audiovisual content without prior written approval.
- API clients must not make YouTube content available for offline playback.
- API clients must not separate, isolate, modify, or promote only the audio or video component of YouTube audiovisual content.
- API clients must not create or promote playback from a background player that is not displayed in the page, tab, or screen the user is viewing.
- API clients must not modify, build upon, block, obscure, or replace the YouTube player or player functionality.
- Screens displaying YouTube content must make clear that YouTube is the source and preserve YouTube attribution.
- API clients must not mimic or replace core YouTube experiences unless they add significant independent value.

Source: YouTube API Services Required Minimum Functionality.

- Embedded YouTube players in WebViews are allowed when using OS-provided WebViews such as `WKWebView`.
- Embedded players must be at least 200 x 200 px, and 16:9 players are recommended to be at least 480 x 270 px.
- Autoplay must not start until the player is visible and more than half of the player is visible on screen.
- You must not place overlays, frames, or other visual elements in front of any part of a YouTube embedded player, including controls.
- YouTube player attributes and branding must not be changed except as explicitly documented.

## Product Implication

Allowed direction:

- Native PhonoDeck search, playlists, queue planning, library views, account settings, and source-aware actions.
- Visible official YouTube embedded player as the primary playback surface, with the external YouTube Music site only as a fallback.
- Native controls only where the visible official player/API explicitly permits control.

Rejected direction:

- Hidden `WKWebView` audio.
- Native `AVPlayer` playback of extracted YouTube streams.
- Native controls that pretend to own YouTube playback while the official player is hidden.
- YouTube downloads/offline cache.
