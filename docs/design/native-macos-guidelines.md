# Native macOS Design Guidelines

PhonoDeck should feel like a stock Apple media app without copying Apple Music or implying affiliation with Apple, Google, Plex, or Spotify.

## Design Principles

- Native first: SwiftUI/AppKit controls, standard toolbar, standard menu bar, system typography, SF Symbols, and system materials.
- Library first: the app should expose collections, playlists, albums, artists, downloads, and devices as stable navigation areas.
- Source-aware: Plex, YouTube Music, Spotify, and Local must be visibly distinguishable when policy or capabilities differ.
- Quiet density: avoid marketing layout, oversized hero sections, decorative gradients, and card-heavy dashboards.
- Playback persistent: a bottom Now Playing bar remains visible and compact, with metadata, transport controls, progress, and output route.

## Window Anatomy

- Sidebar: top-level navigation and user-configurable library groups.
- Toolbar: sidebar toggle, source picker, search, share, and context actions.
- Detail: lists/grids that adapt to album, playlist, artist, search, and source views.
- Now Playing bar: fixed bottom region with compact artwork, track text, controls, and route controls.
- Menu bar: every toolbar command must exist as a menu command.

## Visual Rules

- Use SF Pro and system text styles.
- Use SF Symbols for toolbar, sidebar, playback, devices, and sharing actions.
- Keep cards to repeated media items only. Do not put cards inside cards.
- Keep repeated item radius at 8 px or less.
- Use service color only as a small source cue, never as a full-page theme.
- Use accent color and vibrancy according to system settings.
- Make text fit at compact window sizes; use line limits and sensible minimum widths.

## Apple Music-Inspired Information Architecture

Use Apple Music as an interaction reference, not a visual copy target:

- Listen Now: recent, recommended, and resumable items.
- Library: Songs, Albums, Artists, Playlists, Imported, Downloads.
- Search: source-scoped search with clear attribution.
- Devices: AirPlay, Spotify Connect, Plex sessions, future Cast routes.
- Settings: accounts, library import, privacy, downloads, cache, and keyboard controls.

## YouTube Music Native Shell Direction

The YouTube Music surface must not be a large browser slab. The preferred visual model is a native command room:

- native search, shelves, queue, route status, account controls, and source badges;
- official YouTube playback opened or controlled only through permitted surfaces;
- no hidden player, no obscured player, no native controls pretending to own a YouTube stream;
- clear route state for official playback, native-control limitations, and downloads.

## Accessibility

- All icon-only buttons require labels/help.
- Controls must support keyboard navigation.
- Do not rely on color alone to distinguish sources.
- Respect Reduce Motion and Increase Contrast.
- Now Playing metadata should be exposed to the system via `MPNowPlayingInfoCenter`.

## Design Resources To Use

- Apple macOS design resources and UI kits.
- SF Symbols app.
- Icon Composer for app icon exploration.
- AirPlay glyph and design guidance where AirPlay UI is needed.
