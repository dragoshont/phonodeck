# Unified Music Player Research

PhonoDeck should feel like one music app across providers while respecting each provider's API and playback rules.

## Modern Music Player Baseline

- Apple Music surfaces: Home/Listen Now, Search, Library, playlists, downloads, favorites/pins, lyrics, sharing, synced playback across devices, and account-aware recommendations.
- Plexamp surfaces: personal music library, artists/albums/playlists, smart playlists and stations, radio/mixes, gapless playback, loudness leveling, pre-caching, downloads for owned media, lyrics, visual themes, CarPlay/Android Auto, Chromecast/AirPlay, Siri, related tracks, and sonic similarity features.
- Spotify Web API surfaces: metadata search, artists/albums/tracks, user playlists, create playlist, add tracks, saved library, recently played, top tracks/artists, queue, devices, and Spotify Connect playback control through scopes.

## Unified PhonoDeck Surfaces

- Search across connected sources.
- Listen Now with provider activity plus local PhonoDeck history.
- Library with albums, artists, playlists, downloads, and source capability status.
- Now Playing with one queue/transport model and provider-specific playback policy.
- Playlist creation, add-to-playlist, and sharing where the provider supports it.
- Info and lyrics surfaces using official data only.
- Devices/remotes as source-aware capabilities, not fake controls.

## Library Page Direction

- Apple Music reference: Library should behave as a collection hub, not an empty source-settings page. It should surface songs, playlists, downloads/favorites when available, and direct search as a path into the library.
- Plexamp reference: music-library pages benefit from recent listening, smart shelves, stations/radio-style discovery, downloads for owned media, and a sense of personal collection depth.
- Spotify design reference: provider content should be source-attributed, shelves should not mix provider metadata in a misleading way, and metadata/artwork must remain legible and unmodified.
- PhonoDeck implementation direction: Library shows counts, recent playable songs, YouTube Music playlists, and source capability rows. It remains useful before Plex/Spotify/Local are implemented, while avoiding fake playback switches.

## Provider Truths

- YouTube: separate source for general videos, clips, and music videos. It should use documented YouTube APIs and the visible official player. It must not be mixed into song-first surfaces except when the user chooses Video/Mixed mode or opens a YouTube playlist/history item.
- YouTube Music: primary P0 song source. Search, Listen Now, and Library should prefer YouTube Music metadata from the no-cookie experimental provider, use a stale-while-refresh cache for snappy navigation, and fall back to official YouTube APIs when needed. Playback must still stay in a visible official YouTube player. Private YouTube Music account library data is not available without an authenticated/internal YouTube Music session, so PhonoDeck combines cached music metadata, local playback history, official playlists, and official account activity where OAuth allows.
- YouTube Music metadata: duration and publication/recording year can come from official YouTube `videos.list` details when connected. YouTube does not expose audio sample rate/bitrate, the user's Premium plan tier, Family/Student/Individual status, HomePod default music service configuration, or per-device listening history such as iPhone/Tesla/HomePod attribution. Record label is not exposed as a first-class YouTube Data API field; licensed-content status can be shown without naming a label.
- Apple Music / MusicKit: can provide Apple Music catalog metadata, recently played, personal recommendations, subscription capability, audio variants, lyrics/catalog relationships, and record-label entities after MusicKit setup and user authorization. It does not reveal YouTube Music or YouTube Premium subscription status.
- HomePod / AirPlay / Home: AVRoutePickerView can present nearby system media receivers such as HomePod/Apple TV for native playback routes. HomeKit can access home accessories with entitlement and permission, but does not expose HomePod's configured default music service as "YouTube Music" vs another provider.
- Plex: appropriate long-term source for native playback and downloads of user-owned music from Plex Media Server. Requires real Plex auth/server/library browsing before it becomes selectable playback.
- Spotify: Web API supports search, playlists, library, recent/top items, queue, and Spotify Connect controls via scoped OAuth. Native streaming must use Spotify-approved SDK paths and Premium requirements; offline storage is not a PhonoDeck feature.
- Own Files: full native playback, iTunes XML import, local playlists, and offline access are appropriate because files are user-owned.

## Music Metadata Direction

- The app chrome should say "Music" and use YouTube Music only as source attribution, not as the oversized product identity.
- Song detail should prioritize duration, year, source, kind, available captions/lyrics path, local listening time, and provider limitations.
- Quality must be honest: YouTube Data API exposes video definition (`hd`/`sd`) but not audio sample rate, codec, bitrate, or Premium audio quality.
- Lyrics should use official playable lyric-video search or future authorized providers; PhonoDeck should not scrape lyrics sites.
- Trivia should come from a future explicit metadata provider such as MusicBrainz/Wikipedia-style data, never generated as if it were sourced fact.

## Snappy UI Direction

- Navigation should never wait on provider calls before showing useful content. Listen Now and Library should render cached YouTube Music rows immediately, then refresh in the background.
- Search should use stale-while-refresh behavior: publish cached results synchronously, coalesce duplicate searches, and preserve cached rows if the provider refresh fails.
- Account library calls should run independently rather than as a serial waterfall. Activity, playlists, and subscriptions can succeed or fail separately.
- Image and network caching should lean on platform cache behavior where possible, with app-level metadata caches for YouTube Music search rows because the experimental endpoint is a POST response that is not naturally reusable by `URLCache`.
- Source attribution must remain explicit: YouTube Music for song-like metadata, YouTube for clips/videos, Plex, Spotify, and Own Files as separate providers.

## Current Implementation Notes

- Source model now exposes YouTube, YouTube Music, Plex, Spotify, and Own Files as separate providers.
- YouTube Music default `Music` search uses no-cookie `music.youtube.com/youtubei` metadata in Auto mode and falls back to official YouTube API search when needed.
- YouTube `Video` mode remains available for clips/music videos as a separate source posture.
- Listen Now and Library use cached music metadata plus PhonoDeck history first, then enrich with official account activity/playlists when connected.
- YouTube Music playlist create/add/share is implemented against official YouTube account playlist API methods. Existing read-only tokens need reconnecting to grant `https://www.googleapis.com/auth/youtube`.
- PhonoDeck persists local playback history separately from YouTube account activity.
- Source capability rows/chips expose Plex/Spotify/Own Files consistently without activating fake playback.