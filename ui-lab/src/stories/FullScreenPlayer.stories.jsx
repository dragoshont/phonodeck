import React from 'react';
import { FullScreenPlayer } from '../components/PhonoDeck.jsx';

export default { title: 'Now Playing/Full Screen Player', parameters: { layout: 'fullscreen' } };

const frame = (el) => <div style={{ display: 'grid', placeItems: 'center', padding: 24, minHeight: '100vh' }}>{el}</div>;

export const YouTube = { name: 'YouTube (visible 16:9 embed)', render: () => frame(<FullScreenPlayer source="ytm" />) };
