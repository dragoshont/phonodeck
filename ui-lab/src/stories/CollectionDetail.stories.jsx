import React from 'react';
import { PlaylistDetail, CollectionToolbar, SongContextMenu } from '../components/PhonoDeck.jsx';

export default {
  title: 'Screens/Collection Detail',
  component: PlaylistDetail,
  parameters: { layout: 'fullscreen' },
};

// Playlist/album detail with the native macOS pattern: a stretching, sortable
// multi-column SongTable, the Apple Music toolbar (sort menu + Find-in-playlist
// search + download/overflow), and a per-row context menu.
export const PlaylistTable = { name: 'Playlist (table)', render: () => <PlaylistDetail /> };
export const SortAndFilterMenu = { name: 'Sort & filter menu (open)', render: () => <PlaylistDetail sortOpen /> };
export const RowContextMenu = { name: 'Row context menu (open)', render: () => <PlaylistDetail contextOpen /> };
export const ToolbarOnly = {
  name: 'Collection toolbar',
  parameters: { layout: 'padded' },
  render: () => <div style={{ display: 'flex', justifyContent: 'flex-end', paddingTop: 40 }}><CollectionToolbar sortOpen /></div>,
};
export const TrackContextMenu = {
  name: 'Track context menu',
  parameters: { layout: 'centered' },
  render: () => <div style={{ position: 'relative', height: 340, width: 260 }}><SongContextMenu /></div>,
};
