import React from 'react';
import { NowPlayingPanel } from '../components/PhonoDeck.jsx';

export default {
  title: 'Now Playing/Panel',
  component: NowPlayingPanel,
  parameters: { layout: 'fullscreen' },
  argTypes: {
    tab: { control: 'inline-radio', options: ['now', 'next', 'lyrics', 'about'] },
    source: { control: 'inline-radio', options: ['ytm', 'yt', 'spotify', 'plex', 'own', 'native'] },
    routeStatus: { control: 'inline-radio', options: ['ready', 'notConnected', 'notConfigured', 'rateLimited', 'policyBlocked', 'failed'] },
    lyricsAvailable: { control: 'boolean' },
  },
  render: (args) => <div style={{ height: 720, display: 'flex', justifyContent: 'flex-end' }}><NowPlayingPanel {...args} /></div>,
};

// Now Playing tab shows the REAL visible official YouTube iframe (policy-compliant)
export const NowPlaying_YouTubeIframe = { args: { tab: 'now', source: 'ytm' } };
export const NoSelection = { args: { tab: 'now', source: 'ytm', empty: true } };
export const YouTubeVisibleIframeDirect = { args: { tab: 'now', source: 'ytm', mediaMode: 'video' } };
export const UpNext = { args: { tab: 'next', source: 'ytm' } };
export const LyricsUnavailable = { args: { tab: 'lyrics', source: 'ytm', lyricsAvailable: false } };
export const LyricsProviderConfigured = { args: { tab: 'lyrics', source: 'ytm', lyricsAvailable: true } };
export const About = { args: { tab: 'about', source: 'ytm' } };
export const SpotifyVisibleEmbed = { args: { tab: 'now', source: 'spotify' } };
export const NativeArtwork = { args: { tab: 'now', source: 'plex' } };
export const NativeAbout = { args: { tab: 'about', source: 'plex' } };
export const BlockedRoute = { args: { tab: 'now', source: 'plex', routeStatus: 'notConfigured' } };
export const FailedRoute = { args: { tab: 'now', source: 'ytm', routeStatus: 'failed' } };
