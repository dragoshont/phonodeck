# YouTube API Gap Map

Date: 2026-06-19

## Current Official API Coverage

PhonoDeck currently uses documented YouTube Data API v3 endpoints for:

- `search.list` for playable video search, biased toward music results.
- `videos.list` for duration, publication/recording year, embeddability, captions flag, statistics, licensed-content signal, and video-definition signal.
- `playlists.list` for authenticated account playlists.
- `playlistItems.list` for playlist contents and date-added/item IDs.
- `playlistItems.insert` for adding a song/video to a playlist.
- `playlistItems.delete` for removing a playlist item.
- `activities.list` for account activity when authorized.
- `subscriptions.list` for account subscriptions/channels when authorized.
- `channels.list` for current-account channel identity.
- YouTube IFrame Player API for visible playback, timing, state, and volume commands.

## Official API Surfaces Not Yet Used

- `playlistItems.update`: could support playlist reordering once Queue/Playlist drag-and-drop is implemented.
- `playlists.update` and `playlists.delete`: could support playlist rename, description, privacy, and delete. These need careful confirmation UI.
- `videos.getRating` and `videos.rate`: could support like/dislike state using official account scopes.
- `captions.list`: can show which caption tracks exist. It does not expose YouTube Music synced lyrics.
- `captions.download`: official, but downloads captions, not media. It should only be added if lyric/caption UX clearly distinguishes captions from lyrics.
- `commentThreads.list`: could power trivia/community notes, but it is noisy and not music metadata.
- `channels.list` by channel ID: could improve artist/channel detail pages with channel thumbnails, descriptions, stats, and uploads playlist IDs.
- `channelSections.list`: could surface a channel's public shelves if browse view is enabled, useful for artist-like pages.
- `search.list` with `type=channel` and `type=playlist`: could support source search for artist channels and public playlists.
- `i18nRegions.list`, `i18nLanguages.list`, and `videoCategories.list`: could improve locale-aware search/filtering.

## Not Available As Official YouTube Music APIs

There is still no public, supported YouTube Music catalog API for canonical songs, albums, artists, artist radio, related artists, synced lyrics, actual audio bitrate, or YouTube Music library entities. PhonoDeck must use the documented YouTube Data API plus visible official playback surfaces only; prior internal/no-cookie metadata experiments are superseded and not a production path.

## Product Implications

- Artist pages can honestly use YouTube channel/search/video signals, but should continue to label them as source-derived, not canonical YouTube Music artist entities.
- Related Music can be local/cache-derived now, and later improved with `search.list` channel/playlist queries or future Plex/Navidrome/local-file providers.
- Queue is local PhonoDeck state over visible YouTube player IDs; it is not a remote YouTube Music queue.
- True audio bitrate/codec belongs to future file/Plex/Navidrome sources, not YouTube playback.