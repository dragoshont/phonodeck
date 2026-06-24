import React from 'react';
import { AlbumsSurface, ArtistsSurface, HomeState, LibraryState, PlaylistsState, QueueState, ReadinessCallout, SearchState, SourceBadge } from '../components/PhonoDeck.jsx';

export default {
  title: 'Phase 5/Readiness States',
  parameters: { layout: 'fullscreen' },
};

const frame = (children) => <div className="pd" style={{ minHeight: 720, background: 'var(--content-bg)' }}>{children}</div>;
const panel = (children) => <div className="pd" style={{ padding: 24, background: 'var(--content-bg)', minHeight: 420 }}><div style={{ maxWidth: 780 }}>{children}</div></div>;

export const ReadinessRows = {
  render: () => panel(<>
    <ReadinessCallout src="ytm" status="ready" title="YouTube Music" detail="Search, playlists, likes, and visible official playback are ready." />
    <ReadinessCallout src="spotify" status="notConnected" title="Spotify" detail="Connect Spotify to use metadata/library and the visible official Spotify player." />
    <ReadinessCallout src="plex" status="notConfigured" title="Plex" detail="No Plex music server is configured. Native playback becomes available after setup." />
    <ReadinessCallout src="ytm" status="missingScope" title="YouTube playlists" detail="Reconnect YouTube to grant the playlist write scope." />
    <ReadinessCallout src="spotify" status="authorizationExpired" title="Spotify" detail="Spotify authorization expired. Reconnect to refresh library metadata." />
    <ReadinessCallout src="ytm" status="rateLimited" title="YouTube Music" detail="Showing cached results where available. Try again later." />
    <ReadinessCallout src="ytm" status="policyBlocked" title="Albums" detail="YouTube does not expose canonical album metadata to third-party apps." />
    <ReadinessCallout src="plex" status="failed" title="Plex" detail="Could not load the Plex server. Retry or manage it in Settings." />
  </>),
};

export const SourceBadgeVariants = {
  render: () => panel(<div style={{ display: 'flex', gap: 16, alignItems: 'center', flexWrap: 'wrap' }}>
    <SourceBadge src="ytm" variant="dot" />
    <SourceBadge src="spotify" variant="dot" />
    <SourceBadge src="plex" />
    <SourceBadge src="yt" />
    <div className="art g6" style={{ width: 88, height: 88 }}><SourceBadge src="plex" variant="corner" /></div>
  </div>),
};

export const AlbumsLimitedEmpty = { render: () => frame(<AlbumsSurface mode="empty" />) };
export const AlbumsLimitedDerived = { render: () => frame(<AlbumsSurface mode="limited" />) };
export const AlbumsRealProvider = { render: () => frame(<AlbumsSurface mode="real" />) };
export const ArtistsLimitedEmpty = { render: () => frame(<ArtistsSurface mode="empty" />) };
export const ArtistsLimitedDerived = { render: () => frame(<ArtistsSurface mode="limited" />) };
export const ArtistsRealProvider = { render: () => frame(<ArtistsSurface mode="real" />) };
export const HomePartial = { render: () => frame(<HomeState state="partial" />) };
export const HomeStaleCache = { render: () => frame(<HomeState state="stale" />) };
export const HomeSignedOutEmpty = { render: () => frame(<HomeState state="empty" />) };
export const SearchLoading = { render: () => frame(<SearchState state="loading" />) };
export const SearchNoResults = { render: () => frame(<SearchState state="noResults" />) };
export const SearchRateLimited = { render: () => frame(<SearchState state="rateLimited" />) };
export const SearchOfficialFallback = { render: () => frame(<SearchState state="fallback" />) };
export const LibraryPartial = { render: () => frame(<LibraryState state="partial" />) };
export const LibraryEmpty = { render: () => frame(<LibraryState state="empty" />) };
export const PlaylistsMissingScope = { render: () => frame(<PlaylistsState state="missingScope" />) };
export const PlaylistsEmpty = { render: () => frame(<PlaylistsState state="empty" />) };
export const QueueBlockedItem = { render: () => frame(<QueueState state="blocked" />) };
export const QueueEmpty = { render: () => frame(<QueueState state="empty" />) };