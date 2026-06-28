import React from 'react';
import { NowPlayingBar } from '../components/PhonoDeck.jsx';

export default {
  title: 'Shell/NowPlayingBar',
  component: NowPlayingBar,
  parameters: { layout: 'centered' },
  argTypes: { mode: { control: 'inline-radio', options: ['youtube', 'native', 'empty'] } },
};

// YouTube source: controls the embed can't truthfully perform are disabled (honest controls — research §7)
export const YouTubeMusic = { args: { mode: 'youtube', standalone: true } };
// No current item: bar shows a quiet placeholder
export const NoSelection = { args: { mode: 'empty', standalone: true } };
