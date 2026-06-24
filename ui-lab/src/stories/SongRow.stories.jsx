import React from 'react';
import { SongResultRow, SongTable, sampleSongs } from '../components/PhonoDeck.jsx';

export default {
  title: 'Components/SongResultRow',
  component: SongResultRow,
  parameters: { layout: 'centered' },
};

export const Row = {
  render: (args) => <div style={{ width: 760 }} className="table"><SongResultRow {...args} /></div>,
  args: { index: 2, song: sampleSongs[1] },
};

export const NowPlayingRow = {
  render: (args) => <div style={{ width: 760 }} className="table"><SongResultRow {...args} /></div>,
  args: { index: 1, song: sampleSongs[0] },
};

export const FullTable = {
  render: () => <div style={{ width: 760 }}><SongTable songs={sampleSongs} /></div>,
};
