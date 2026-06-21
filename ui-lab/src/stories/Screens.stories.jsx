import React from 'react';
import { Shell } from '../components/PhonoDeck.jsx';

export default {
  title: 'Screens',
  component: Shell,
  parameters: { layout: 'fullscreen' },
  argTypes: {
    screen: { control: 'select', options: ['home', 'firstrun', 'library', 'playlist', 'artist', 'queue', 'search', 'settings'] },
    showPanel: { control: 'boolean' },
    panelTab: { control: 'inline-radio', options: ['now', 'next', 'lyrics', 'about'] },
  },
  args: { showPanel: true, panelTab: 'now' },
};

export const Home = { args: { screen: 'home' } };
export const FirstRun = { args: { screen: 'firstrun' } };
export const Playlist = { args: { screen: 'playlist' } };
export const Artist = { name: 'Artist (cinematic)', args: { screen: 'artist', panelTab: 'about' } };
export const Library = { name: 'Library (unified, source-marked)', args: { screen: 'library' } };
export const Queue = { args: { screen: 'queue' } };
export const Search = { args: { screen: 'search' } };
export const Settings = { args: { screen: 'settings' } };
export const HomeWithLyrics = { args: { screen: 'home', panelTab: 'lyrics' } };
export const HomeNoPanel = { args: { screen: 'home', showPanel: false } };
