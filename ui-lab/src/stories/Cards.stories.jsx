import React from 'react';
import {
  PlaylistArtworkCard, SubscriptionAvatarCard, SourcePill, SongCarouselShelf,
  FeatureHeroCard, LikeButton, sampleSongs, TopPicksShelf,
} from '../components/PhonoDeck.jsx';

export default { title: 'Components/Cards', parameters: { layout: 'centered' } };

export const FeatureHero = {
  name: 'FeatureHeroCard',
  parameters: { layout: 'fullscreen' },
  render: () => <div style={{ width: 820, padding: 24 }}><FeatureHeroCard /></div>,
};

export const TopPicks = {
  name: 'TopPicksShelf (provenance eyebrows)',
  parameters: { layout: 'fullscreen' },
  render: () => <div style={{ width: 980, padding: 24 }}><TopPicksShelf /></div>,
};

export const PlaylistCard = {
  name: 'PlaylistArtworkCard',
  render: () => (<div style={{ display: 'flex', gap: 16 }}>
    <PlaylistArtworkCard index={0} title="Late Night Drive" count={18} />
    <PlaylistArtworkCard index={1} title="Focus" count={42} />
    <PlaylistArtworkCard index={2} title="Throwbacks" count={60} />
  </div>),
};

export const SubscriptionAvatar = {
  name: 'SubscriptionAvatarCard',
  render: () => (<div style={{ display: 'flex', gap: 16 }}>
    <SubscriptionAvatarCard index={0} title="Majestic Casual" />
    <SubscriptionAvatarCard index={1} title="Mr.SuicideSheep" />
    <SubscriptionAvatarCard index={4} title="The Midnight" />
  </div>),
};

export const SourcePills = {
  name: 'SourcePill',
  render: () => (<div style={{ display: 'flex', gap: 8 }}>
    <SourcePill src="ytm" /><SourcePill src="yt" /><SourcePill src="spotify" />
  </div>),
};

export const Like = {
  name: 'LikeButton',
  render: () => (<div style={{ display: 'flex', gap: 18, alignItems: 'center' }}>
    <LikeButton on={false} size={22} /><LikeButton on size={22} />
  </div>),
};

export const Shelf = {
  name: 'SongCarouselShelf',
  render: () => <div style={{ width: 760 }}><SongCarouselShelf title="Recently Played" items={sampleSongs} showAll /></div>,
};
