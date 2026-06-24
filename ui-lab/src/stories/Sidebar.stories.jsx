import React from 'react';
import { SidebarView } from '../components/PhonoDeck.jsx';

export default {
  title: 'Shell/SidebarView',
  component: SidebarView,
  argTypes: {
    active: { control: 'select', options: ['library', 'search', 'playlists', 'albums', 'artists', 'queue', 'downloads', 'devices', 'settings'] },
  },
};

export const Default = { args: { active: 'library' } };
export const QueueSelected = { args: { active: 'queue' } };
