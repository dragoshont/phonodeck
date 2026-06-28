import React from 'react';
import { Shell, TopBarShell } from '../components/PhonoDeck.jsx';

export default {
  title: 'Screens',
  component: Shell,
  parameters: { layout: 'fullscreen' },
  argTypes: {
    screen: { control: 'select', options: ['home', 'firstrun', 'library', 'playlist', 'albums', 'artists', 'artist', 'queue', 'search', 'settings'] },
    showPanel: { control: 'boolean' },
    panelTab: { control: 'inline-radio', options: ['now', 'next', 'lyrics', 'about'] },
  },
  args: { showPanel: true, panelTab: 'now' },
};

export const Home = { args: { screen: 'home' } };
export const FirstRun = { args: { screen: 'firstrun' } };
export const Playlist = { args: { screen: 'playlist' } };
export const Albums = { name: 'Albums (limited metadata)', args: { screen: 'albums' } };
export const Artists = { name: 'Artists (limited metadata)', args: { screen: 'artists', panelTab: 'about' } };
export const Artist = { name: 'Artists (limited metadata, legacy route)', args: { screen: 'artist', panelTab: 'about' } };
export const Library = { name: 'Library (unified, source-marked)', args: { screen: 'library' } };
export const Queue = { args: { screen: 'queue' } };
export const Search = { args: { screen: 'search' } };
export const Settings = { args: { screen: 'settings' } };
export const HomeWithLyrics = { args: { screen: 'home', panelTab: 'lyrics' } };
export const HomeNoPanel = { args: { screen: 'home', showPanel: false } };
export const TopBarHome = { name: 'Top bar nav — Home', render: (args) => <TopBarShell {...args} screen="home" showPanel={false} /> };
export const TopBarPlaylist = { name: 'Top bar nav — Playlist', render: (args) => <TopBarShell {...args} screen="playlist" /> };
export const TopBarAlbums = { name: 'Top bar nav — Albums', render: (args) => <TopBarShell {...args} screen="albums" /> };
