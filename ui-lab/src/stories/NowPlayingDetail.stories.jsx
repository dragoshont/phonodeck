import React from 'react';
import { LyricsView, AboutInspector, UpNextQueue } from '../components/PhonoDeck.jsx';

const frame = (el) => <div style={{ width: 380, padding: '8px 20px' }}>{el}</div>;

export const LyricsSynced = { name: 'Lyrics — synced', render: () => frame(<LyricsView />) };
export const LyricsEmpty = { name: 'Lyrics — unavailable (honest)', render: () => frame(<LyricsView empty />) };

export default { title: 'Now Playing/Detail', parameters: { layout: 'centered' } };

export const About = { name: 'About / Info inspector', render: () => frame(<AboutInspector />) };
export const UpNext = { name: 'Up Next — Radio planned', render: () => frame(<UpNextQueue />) };
