import React from 'react';
import { SidebarView } from '../components/PhonoDeck.jsx';

export default {
  title: 'Shell/SidebarView',
  component: SidebarView,
  argTypes: {
    active: { control: 'select', options: ['home', 'search', 'playlists', 'albums', 'artists', 'songs', 'queue', 'downloads', 'devices', 'settings'] },
  },
};

export const Default = { args: { active: 'home' } };
export const QueueSelected = { args: { active: 'queue' } };
