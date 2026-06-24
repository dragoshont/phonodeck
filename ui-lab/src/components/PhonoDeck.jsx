import React from 'react';
import { Icon } from '../icons.jsx';

/* ====== sample data ====== */
const G = (i) => `g${(i % 10) + 1}`;
export const sourceMeta = {
  ytm: { name: 'YT Music', color: 'var(--ytm)' }, yt: { name: 'YouTube', color: 'var(--yt)' },
  spotify: { name: 'Spotify', color: 'var(--spotify)' }, plex: { name: 'Plex', color: 'var(--plex)' },
  own: { name: 'Own Files', color: 'var(--accent)' },
};
export const sampleSongs = [
  { title: 'Neon Skyline', artist: 'The Midnight', album: 'Monsters', time: '3:35', src: 'ytm', badge: 'Official Audio', playing: true, liked: true },
  { title: 'Sunset', artist: 'Petit Biscuit', album: 'Presence', time: '3:58', src: 'ytm', badge: 'Official Audio' },
  { title: 'Midnight City', artist: 'M83 · Topic', album: "Hurry Up, We're Dreaming", time: '4:03', src: 'ytm', badge: 'Topic', liked: true },
  { title: 'Resonance', artist: 'HOME', album: 'Odyssey', time: '3:32', src: 'yt', badge: 'YouTube' },
  { title: 'Nightcall', artist: 'Kavinsky', album: 'OutRun', time: '4:18', src: 'ytm', badge: 'Official Audio' },
  { title: 'A Real Hero', artist: 'College & Electric Youth', album: 'Drive OST', time: '4:30', src: 'ytm', badge: 'Official Audio' },
];
export const samplePlaylists = [
  { title: 'Late Night Drive', count: 18, src: 'ytm' }, { title: 'Focus', count: 42, src: 'spotify' },
  { title: 'Throwbacks', count: 60, src: 'yt' }, { title: 'Workout', count: 25, src: 'plex' }, { title: 'Coding', count: 88, src: 'ytm' },
];
/* mixed-source library: every row carries a discrete source marker (dot + textual badge) */
export const mixedSongs = [
  { title: 'Neon Skyline', artist: 'The Midnight', album: 'Monsters', time: '3:35', src: 'ytm', badge: 'YT Music', playing: true, liked: true },
  { title: 'Midnight City', artist: 'M83', album: "Hurry Up, We're Dreaming", time: '4:03', src: 'spotify', badge: 'Spotify' },
  { title: 'Open Your Eyes', artist: 'School of Seven Bells', album: 'Ripped CD (FLAC)', time: '5:12', src: 'plex', badge: 'Plex · FLAC' },
  { title: 'Resonance', artist: 'HOME', album: 'Odyssey', time: '3:32', src: 'yt', badge: 'YouTube' },
  { title: 'Sunset', artist: 'Petit Biscuit', album: 'Presence', time: '3:58', src: 'spotify', badge: 'Spotify' },
  { title: 'A Real Hero', artist: 'College', album: 'Drive OST', time: '4:30', src: 'ytm', badge: 'YT Music' },
  { title: 'Innerbloom', artist: 'RÜFÜS DU SOL', album: 'Bloom (ALAC)', time: '9:38', src: 'plex', badge: 'Plex · ALAC' },
];
/* Plex-style cross-service discovery: new releases per configured source, each provenance-labeled */
export const mixedNew = [
  { title: 'Sonic Bloom', artist: 'RÜFÜS DU SOL', src: 'ytm', tag: 'New on YT Music' },
  { title: 'Afterglow', artist: 'ODESZA', src: 'spotify', tag: 'New on Spotify' },
  { title: 'Night Tapes', artist: 'Added to your server', src: 'plex', tag: 'New in your library' },
  { title: 'Echoes', artist: 'HOME', src: 'yt', tag: 'New on YouTube' },
  { title: 'Polaris', artist: 'Tycho', src: 'ytm', tag: 'New on YT Music' },
  { title: 'Drift', artist: 'Bonobo', src: 'spotify', tag: 'New on Spotify' },
];
/* connected services row (honest tier per source) */
export const connectedServices = [
  { src: 'ytm', detail: 'Premium · 12 new' },
  { src: 'yt', detail: 'Connected' },
  { src: 'spotify', detail: 'Free · library only' },
  { src: 'plex', detail: 'Plex Pass · 3 new' },
];
export const sampleSubs = ['Majestic Casual', 'Mr.SuicideSheep', 'NoCopyrightSounds', 'Proximity', 'The Midnight', 'Monstercat'];
export const relatedSongs = [
  { title: 'Days', artist: 'The Drums', time: '3:18' }, { title: 'Instant Crush', artist: 'Daft Punk', time: '5:37' },
  { title: 'Crystallized', artist: 'The xx', time: '3:22' }, { title: 'Genesis', artist: 'Grimes', time: '4:16' },
];
export const lyricLines = [
  { t: 'I drive alone tonight', s: 'past' }, { t: 'The city lights are calling', s: 'past' },
  { t: 'Neon skyline burning bright', s: 'active' }, { t: 'And I can feel it falling', s: '' },
  { t: 'Down the avenue we go', s: '' }, { t: 'Chasing all the afterglow', s: '' },
  { t: 'Headlights paint the road in gold', s: '' }, { t: 'A story that was never told', s: '' },
];
export const aboutInfo = {
  bio: 'The Midnight is an American synthwave band formed in 2012 by Tyler Lyle and Tim McEwan, known for nostalgic, saxophone-driven retro-pop evoking 1980s film soundtracks.',
  bioSource: 'Wikipedia (CC BY-SA 4.0)',
  credits: [
    { role: 'Songwriters', name: 'Tyler Lyle, Tim McEwan', source: 'MusicBrainz' },
    { role: 'Producer', name: 'Tim McEwan', source: 'MusicBrainz' },
    { role: 'Label', name: 'Counter Records', source: 'MusicBrainz' },
  ],
};
export const featureCard = { over: 'Made for You', title: 'Late Night Drive', sub: 'Synthwave for the open road · 18 songs', g: 'g6' };
/* Apple Music 'Top Picks' — large cards whose EYEBROW labels name the real provenance (honest, never 'YouTube recommends') */
export const topPicks = [
  { eyebrow: 'From your YouTube activity', title: 'Heavy Rotation Mix', sub: 'The Midnight, HOME, Kavinsky & more', g: 'g6' },
  { eyebrow: 'Because you played Nightcall', title: 'Synthwave Drive', sub: 'Outrun, retrowave & neon', g: 'g3' },
  { eyebrow: 'Updated playlist', title: 'Late Night Drive', sub: 'Refreshed today · 18 songs', g: 'g5' },
  { eyebrow: 'Made by you', title: 'Focus', sub: '42 songs', g: 'g4' },
];
export const artistInfo = {
  name: 'The Midnight', listeners: '2.1M subscribers · 92M views', g: 'g6',
  latest: { title: 'Monsters', kind: 'Latest Release · Album', year: '2024', tracks: 12, g: 'g1' },
};
export const artistTopSongs = [
  { title: 'Sunset', plays: '48M', time: '4:21', badge: 'Official Audio' },
  { title: 'Los Angeles', plays: '31M', time: '5:12', badge: 'Official Audio' },
  { title: 'Crystalline', plays: '22M', time: '4:02', badge: 'Topic' },
  { title: 'Deep Blue', plays: '18M', time: '3:48', badge: 'Official Audio' },
  { title: 'Vampires', plays: '14M', time: '4:33', badge: 'Official Audio' },
];
export const essentialAlbums = [
  { title: 'Endless Summer', count: 11 }, { title: 'Nocturnal', count: 10 },
  { title: 'Kids', count: 12 }, { title: 'Monsters', count: 12 }, { title: 'Days of Thunder', count: 6 },
];

/* ====== SourcePill ====== */
export function SourcePill({ src = 'ytm' }) {
  const m = sourceMeta[src];
  return <span className="pill" style={{ color: m.color, background: 'color-mix(in srgb, currentColor 16%, transparent)' }}>● {m.name}</span>;
}

export function SourceBadge({ src = 'ytm', variant = 'pill' }) {
  const m = sourceMeta[src];
  if (variant === 'dot') {
    return <span className="src-dot-label"><span className="src-dot" style={{ background: m.color }} aria-hidden="true" />{m.name}</span>;
  }
  if (variant === 'corner') {
    return <span className="card-src" style={{ background: m.color }} title={m.name} aria-label={`Source: ${m.name}`} />;
  }
  return <SourcePill src={src} />;
}

const readinessConfig = {
  ready: { label: 'Ready', icon: 'info', pill: 'ok' },
  notConnected: { label: 'Connect', icon: 'person', pill: 'plan' },
  notConfigured: { label: 'Setup needed', icon: 'gear', pill: 'warn' },
  missingScope: { label: 'Permission needed', icon: 'info', pill: 'warn' },
  authorizationExpired: { label: 'Reconnect', icon: 'person', pill: 'warn' },
  rateLimited: { label: 'Rate limited', icon: 'info', pill: 'warn' },
  providerUnavailable: { label: 'Service issue', icon: 'info', pill: 'warn' },
  partial: { label: 'Partial', icon: 'info', pill: 'warn' },
  policyBlocked: { label: 'Unavailable', icon: 'down', pill: 'blocked' },
  failed: { label: 'Failed', icon: 'info', pill: 'blocked' },
};

export function ReadinessCallout({ src = 'plex', status = 'notConfigured', title, detail }) {
  const meta = sourceMeta[src];
  const config = readinessConfig[status] || readinessConfig.failed;
  return (
    <div className="ready-callout" role="status" aria-label={`${meta.name}: ${config.label}. ${detail}`}>
      <div className="ic" style={{ background: `color-mix(in srgb, ${meta.color} 16%, transparent)`, color: meta.color }}><Icon name={config.icon} size={16} /></div>
      <div className="rc-body"><div className="rc-title">{title || meta.name}</div><div className="rc-detail">{detail}</div></div>
      <span className={`pill ${config.pill}`}>{config.label}</span>
    </div>
  );
}

/* ====== SourceFilterChips — unify the library but let users filter by origin ====== */
export function SourceFilterChips({ active = 'all' }) {
  const chips = [['all', 'All', null], ['yt', 'YouTube', 'yt'], ['ytm', 'YT Music', 'ytm'], ['spotify', 'Spotify', 'spotify'], ['plex', 'Plex', 'plex']];
  return (
    <div className="srcchips" role="tablist" aria-label="Filter by source">
      {chips.map(([id, label, src]) => (
        <span key={id} role="tab" aria-selected={active === id} tabIndex={0} className={'srcchip' + (active === id ? ' active' : '')}>
          {src && <span className="d" style={{ background: sourceMeta[src].color }} aria-hidden="true" />}{label}
        </span>
      ))}
    </div>
  );
}

/* ====== LikeButton — heart (Apple feel); verb stays source-truthful ("Like on YouTube") ====== */
export function LikeButton({ on = false, size = 17, label = 'Like on YouTube' }) {
  return (
    <span className={'like-btn' + (on ? ' on' : '')} role="button" tabIndex={0} aria-label={label} aria-pressed={on} title={label} style={{ color: on ? 'var(--accent)' : 'inherit' }}>
      <Icon name={on ? 'heart-fill' : 'heart'} size={size} />
    </span>
  );
}

/* ====== SongResultRow — smart play (focusable hover Play) + per-row Like ====== */
export function SongResultRow({ index = 1, song = sampleSongs[0] }) {
  return (
    <div className={'trow' + (song.playing ? ' playing' : '')}>
      <span className="idx">
        {song.playing
          ? <Icon name="wave" size={13} />
          : <><span className="num">{index}</span><span className="pbtn" role="button" tabIndex={0} aria-label={`Play ${song.title}`}><Icon name="play" size={13} /></span></>}
      </span>
      <span className="cell-main">
        <span className={'mini ' + G(index)} />
        <span><div className="n">{song.title}</div><div className="badge">{song.badge}</div></span>
      </span>
      <span className="muted">{song.artist.split(' · ')[0]}</span>
      <span className="muted"><span className="src-dot" style={{ background: sourceMeta[song.src].color }} aria-hidden="true" />{song.album}</span>
      <span className="like-cell"><span className={'like' + (song.liked ? ' on' : '')} role="button" tabIndex={0} aria-label="Like on YouTube" aria-pressed={!!song.liked}><Icon name={song.liked ? 'heart-fill' : 'heart'} size={15} /></span></span>
      <span className="time">{song.time}</span>
    </div>
  );
}
export function SongTable({ songs = sampleSongs }) {
  return (
    <div className="table">
      <div className="thead"><span>#</span><span className="asc">Title</span><span>Artist</span><span>Album</span><span /><span style={{ textAlign: 'right' }}>Time</span></div>
      {songs.map((s, i) => <SongResultRow key={i} index={i + 1} song={s} />)}
    </div>
  );
}

/* ====== Collection detail (playlist/album) — Apple Music-style toolbar + sortable table + row context menu ====== */
export function SortMenu({ field = 'Playlist Order', dir = 'Ascending', hover = 'Genre' }) {
  const fields = ['Playlist Order', 'Title', 'Genre', 'Year', 'Artist', 'Album', 'Time'];
  const item = (label, checked, hot) => (
    <div className={'ctx-item' + (hot ? ' sel' : '')} role="menuitemradio" aria-checked={checked} key={label}>
      <span className="ck" aria-hidden="true">{checked ? '✓' : ''}</span>{label}
    </div>
  );
  return (
    <div className="ctxmenu sortmenu" role="menu" aria-label="Sort & filter">
      {fields.map((f) => item(f, f === field, f === hover))}
      <div className="ctx-sep" />
      {['Ascending', 'Descending'].map((d) => item(d, d === dir, false))}
    </div>
  );
}
export function SongContextMenu() {
  const rows = [
    ['plus', 'Add to Library'], ['down', 'Download'], ['addplaylist', 'Add to Playlist', '›'], 'sep',
    ['fwd', 'Play Next'], ['radio', 'Create Station'], ['info', 'Get Info'], 'sep',
    ['heart', 'Favourite'], ['share', 'Share', '›'],
  ];
  return (
    <div className="ctxmenu" role="menu" aria-label="Track actions">
      {rows.map((r, i) => r === 'sep'
        ? <div className="ctx-sep" key={i} />
        : <div className={'ctx-item' + (r[1] === 'Get Info' ? ' sel' : '')} role="menuitem" key={i}><Icon name={r[0]} size={15} />{r[1]}{r[2] && <span className="chev">{r[2]}</span>}</div>)}
    </div>
  );
}
export function CollectionToolbar({ sortOpen = false }) {
  return (
    <div className="coll-toolbar">
      <button className="tbar-btn" aria-label="Download"><Icon name="down" size={17} /></button>
      <button className="tbar-btn" aria-label="More"><Icon name="ellipsis" size={17} /></button>
      <span className="sortwrap">
        <button className={'tbar-btn' + (sortOpen ? ' on' : '')} aria-haspopup="menu" aria-expanded={sortOpen} aria-label="Sort and filter"><Icon name="list" size={17} /></button>
        {sortOpen && <SortMenu />}
      </span>
      <label className="searchbar"><Icon name="search" size={14} /><input placeholder="Find in Playlist" aria-label="Find in Playlist" /></label>
    </div>
  );
}
export function CollectionHeader({ title = 'Heavy Rotation', sub = 'Made For You', updated = 'Updated 19hr ago', desc = "The tracks you can't get enough of lately, all in one place — updated as you listen.", g = 'g3' }) {
  return (
    <div className="coll-head">
      <div className={'coll-art ' + g}><span>{title}</span></div>
      <div className="coll-info">
        <h1>{title}</h1>
        <div className="coll-sub">{sub}</div>
        <div className="coll-upd">{updated}</div>
        <p className="coll-desc">{desc}</p>
        <div className="coll-actions">
          <button className="cbtn"><Icon name="play" size={14} /> Play</button>
          <button className="cbtn"><Icon name="shuffle" size={14} /> Shuffle</button>
        </div>
      </div>
    </div>
  );
}
export function PlaylistDetail({ sortOpen = false, contextOpen = false }) {
  return (
    <div className="coll-detail">
      <div className="coll-bar"><CollectionToolbar sortOpen={sortOpen} /></div>
      <CollectionHeader />
      <SongTable songs={sampleSongs} />
      {contextOpen && <div className="ctx-anchor"><SongContextMenu /></div>}
    </div>
  );
}

/* ====== shelves + cards ====== */
export function SongCarouselShelf({ title = 'Recently Played', items = sampleSongs, showAll }) {
  return (
    <div className="shelf">
      <div className="shelf-h"><h3>{title}</h3>{showAll && <a>Show All ›</a>}</div>
      <div className="row">{items.map((s, i) => (
        <div className="card" key={i}>
          <div className={'art ' + G(i)}><div className="play" role="button" tabIndex={0} aria-label={`Play ${s.title}`}><Icon name="play" size={15} /></div></div>
          <div className="c-title">{s.title}</div><div className="c-sub">{(s.artist || '').split(' · ')[0]}</div>
        </div>))}
      </div>
    </div>
  );
}

/* ====== DiscoveryShelf — Plex-style 'New From Your Services' (source-marked + provenance-labeled) ====== */
export function DiscoveryShelf({ title = 'New From Your Services', items = mixedNew }) {
  return (
    <div className="shelf">
      <div className="shelf-h"><h3>{title}</h3><a>Show All ›</a></div>
      <div className="row">{items.map((s, i) => (
        <div className="card" key={i}>
          <div className={'art ' + G(i + 2)}>
            <span className="card-src" style={{ background: sourceMeta[s.src].color }} title={sourceMeta[s.src].name} aria-label={`Source: ${sourceMeta[s.src].name}`} />
            <div className="play" role="button" tabIndex={0} aria-label={`Play ${s.title}`}><Icon name="play" size={15} /></div>
          </div>
          <div className="c-title">{s.title}</div>
          <div className="c-sub" style={{ color: sourceMeta[s.src].color }}>{s.tag}</div>
        </div>))}
      </div>
    </div>
  );
}

/* ====== ConnectedServicesRow — Plex-style 'Your Services' (honest tier) ====== */
export function ConnectedServicesRow({ items = connectedServices }) {
  return (
    <div className="shelf">
      <div className="shelf-h"><h3>Your Services</h3><a>Manage ›</a></div>
      <div className="svc-row">{items.map((s, i) => (
        <div className="svc-card" key={i} role="button" tabIndex={0} aria-label={`${sourceMeta[s.src].name}: ${s.detail}`}>
          <span className="svc-dot" style={{ background: sourceMeta[s.src].color }} aria-hidden="true"><Icon name="note" size={15} /></span>
          <span style={{ minWidth: 0 }}><div className="svc-n">{sourceMeta[s.src].name}</div><div className="svc-d">{s.detail}</div></span>
        </div>))}
      </div>
    </div>
  );
}
export function FeatureHeroCard({ data = featureCard }) {
  return (
    <div className={'feature ' + data.g} role="button" tabIndex={0} aria-label={`${data.over}: ${data.title}`}>
      <div className="scrim" />
      <div className="meta"><div className="over">{data.over}</div><div className="ft">{data.title}</div><div className="fs">{data.sub}</div></div>
      <div className="fplay" aria-hidden="true"><Icon name="play" size={20} /></div>
    </div>
  );
}

/* ====== Top Picks — big rounded recommendation cards with honest provenance eyebrow (Apple Music) ====== */
export function BigPickCard({ data = topPicks[0], index = 0 }) {
  return (
    <div className={'bigpick ' + (data.g || G(index))} role="button" tabIndex={0} aria-label={`${data.eyebrow}: ${data.title}`}>
      <div className="bp-scrim" />
      <div className="bp-play" aria-hidden="true"><Icon name="play" size={16} /></div>
      <div className="bp-meta"><div className="bp-eyebrow">{data.eyebrow}</div><div className="bp-title">{data.title}</div><div className="bp-sub">{data.sub}</div></div>
    </div>
  );
}
export function TopPicksShelf({ title = 'Top Picks for You', items = topPicks }) {
  return (
    <div className="shelf">
      <div className="shelf-h"><h3>{title}</h3><a>Show All ›</a></div>
      <div className="row bigrow">{items.map((p, i) => <BigPickCard key={i} data={p} index={i} />)}</div>
    </div>
  );
}
export function PlaylistArtworkCard({ title = 'Late Night Drive', count = 18, index = 0, src }) {
  return <div className="card"><div className={'art ' + G(index)}>{src && <span className="card-src" style={{ background: sourceMeta[src].color }} title={sourceMeta[src].name} aria-label={`Source: ${sourceMeta[src].name}`} />}</div><div className="c-title">{title}</div><div className="c-sub">{count} songs</div></div>;
}
export function SubscriptionAvatarCard({ title = 'The Midnight', index = 0 }) {
  return <div className="card ch"><div className={'avatar ' + G(index)} /><div className="c-title">{title}</div></div>;
}

/* ====== YouTube embed (the REAL visible official iframe — policy-compliant) ====== */
export function YouTubeEmbed({ id = 'fJ9rUzIMcZQ' }) {
  return (
    <div className="npp-media">
      <iframe title="Visible official YouTube player" src={`https://www.youtube.com/embed/${id}?rel=0&modestbranding=1`} allow="accelerometer; encrypted-media; picture-in-picture" allowFullScreen />
    </div>
  );
}

export function SpotifyEmbed() {
  return (
    <div className="npp-media spotify-embed" role="img" aria-label="Visible official Spotify embedded player">
      <div className="sp-logo"><Icon name="speaker" size={24} /></div>
      <div><div className="sp-title">Visible official Spotify player</div><div className="sp-detail">Preview or full track depends on the listener's Spotify login inside the player.</div></div>
    </div>
  );
}

/* ====== AmbientBackdrop — artwork-derived blurred glow behind Now Playing media (Apple Music) ====== */
export function AmbientBackdrop({ g = 'g6', className = '' }) {
  return <div className={'ambient ' + g + (className ? ' ' + className : '')} aria-hidden="true" />;
}

/* ====== Right Now Playing panel — single trailing inspector; tabs at TOP ====== */
export function NowPlayingPanel({ tab = 'now', source = 'ytm', autoplay = true, lyricsAvailable = false, mediaMode = 'song', routeStatus = 'ready', empty = false }) {
  const [active, setActive] = React.useState(tab);
  const [mode, setMode] = React.useState(mediaMode);
  React.useEffect(() => setActive(tab), [tab]);
  React.useEffect(() => setMode(mediaMode), [mediaMode]);
  const youtube = source === 'ytm' || source === 'yt';
  const spotify = source === 'spotify';
  const native = source === 'plex' || source === 'own' || source === 'native';
  const meta = sourceMeta[source] || sourceMeta.plex;
  const blocked = routeStatus !== 'ready';
  const tabs = [['now', 'Now Playing', 'play'], ['next', 'Up Next', 'list'], ['lyrics', 'Lyrics', 'lyrics'], ['about', 'About', 'info']];
  return (
    <aside className="npp">
      <div className="npp-tabs">
        {tabs.map(([id, label, icon]) => (
          <button key={id} className={active === id ? 'active' : ''} aria-label={label} aria-pressed={active === id} onClick={() => setActive(id)}><Icon name={icon} size={13} />{label}</button>
        ))}
      </div>
      <div className="npp-body">
        {active === 'now' && <>
          {empty && <div className="npp-empty"><Icon name="note" size={32} /><div><div className="n">Select a song</div><div className="d">Choose a row from Home, Search, Library, or Playlists to start playback.</div></div></div>}
          {!empty && <>
          {routeStatus !== 'ready' && <ReadinessCallout src={sourceMeta[source] ? source : 'plex'} status={routeStatus} title="Playback route" detail={routeStatus === 'failed' ? 'The provider could not load this item. Choose another song or manage the source in Settings.' : 'This item cannot start playback until the source is ready.'} />}
          {youtube && <div className="media-toggle"><div className="seg2" role="tablist" aria-label="Audio or video">
            <button role="tab" className={mode === 'song' ? 'active' : ''} aria-selected={mode === 'song'} onClick={() => setMode('song')}>Song</button>
            <button role="tab" className={mode === 'video' ? 'active' : ''} aria-selected={mode === 'video'} onClick={() => setMode('video')}>Video</button>
          </div></div>}
          <div className="npp-stage">
            <AmbientBackdrop g="g6" />
            {youtube && mode === 'video' ? <YouTubeEmbed /> : spotify ? <SpotifyEmbed /> : <div className="npp-media square g6" />}
          </div>
          {youtube && mode === 'song' && <div className="npp-srcnote" style={{ textAlign: 'center' }}>Audio-first — the official audio plays in the visible YouTube player. Switch to Video for the clip.</div>}
          <div className="npp-titlerow">
            <div style={{ minWidth: 0 }}>
              <div className="npp-title">Neon Skyline</div>
              <div className="npp-artist">The Midnight</div>
              <div className="npp-sub2">Monsters · 2019 · 3:35</div>
              <div className="npp-srcline" style={{ color: meta.color }}>● {meta.name}</div>
            </div>
            <LikeButton on size={19} />
          </div>
          <div className={'npp-transport' + (blocked ? ' disabled' : '')}>
            <span className="b sm" role="button" tabIndex={blocked ? -1 : 0} aria-disabled={blocked} aria-label="Shuffle"><Icon name="shuffle" size={15} /></span>
            <span className="b" role="button" tabIndex={blocked ? -1 : 0} aria-disabled={blocked} aria-label="Previous"><Icon name="back" size={17} /></span>
            <span className="b play" role="button" tabIndex={blocked ? -1 : 0} aria-disabled={blocked} aria-label={blocked ? 'Playback unavailable' : 'Pause'}><Icon name={blocked ? 'play' : 'pause'} size={22} /></span>
            <span className="b" role="button" tabIndex={blocked ? -1 : 0} aria-disabled={blocked} aria-label="Next"><Icon name="fwd" size={17} /></span>
            <span className="b sm" role="button" tabIndex={blocked ? -1 : 0} aria-disabled={blocked} aria-label="Repeat"><Icon name="repeat" size={15} /></span>
          </div>
          <div className="npp-scrub"><span>1:24</span><div className="bar"><i /></div><span>-2:11</span></div>
          {youtube && <div className="npp-srcnote">These controls drive the visible official YouTube player (IFrame Player API). System AirPlay &amp; device volume aren’t available for web playback.</div>}
          {spotify && <div className="npp-srcnote">These controls drive the visible official Spotify player. System media-key ownership and app AirPlay routing stay disabled for web playback.</div>}
          {native && <div className="npp-srcnote">Native playback can publish system Now Playing and use media keys only after the provider route resolves ready.</div>}
          <div className="npp-quick">
            <button className="btn bordered" disabled={blocked}><Icon name="addplaylist" size={15} />Add</button>
            <button className="btn bordered" disabled={blocked}><Icon name="share" size={15} />Share</button>
          </div>
          </>}
        </>}
        {active === 'next' && <UpNextQueue autoplay={autoplay} />}
        {active === 'lyrics' && (lyricsAvailable ? <LyricsView /> : <LyricsView empty />)}
        {active === 'about' && (native ? <AboutInspector /> : <AboutUnavailable />)}
      </div>
    </aside>
  );
}

/* ====== Lyrics — synced when a licensed provider is configured; honest empty otherwise ====== */
export function LyricsView({ empty = false }) {
  if (empty) return <div className="lyric-empty">Lyrics aren’t available for this source.<br /><span style={{ fontSize: 11 }}>Add a licensed lyrics provider (Musixmatch / LyricFind) in Settings.</span></div>;
  return (
    <div className="lyrics">
      {lyricLines.map((l, i) => <div key={i} className={'lyric-line ' + l.s}>{l.t}</div>)}
      <div className="lyric-attr">Lyrics licensed by Musixmatch · synced to playback</div>
    </div>
  );
}

/* ====== About / Info inspector — honest, attributed ====== */
export function AboutInspector() {
  return (
    <div>
      <div className="about-sec" style={{ marginTop: 0 }}>Info</div>
      <div className="facts">
        <div className="fact"><span className="fk">Released</span><span className="fv">2019</span><span className="src-tag">MusicBrainz</span></div>
        <div className="fact"><span className="fk">Duration</span><span className="fv">3:35</span><span className="src-tag">YouTube</span></div>
        <div className="fact"><span className="fk">Plays</span><span className="fv">12M</span><span className="src-tag">YouTube</span></div>
        <div className="fact"><span className="fk">Likes</span><span className="fv">48K</span><span className="src-tag">YouTube</span></div>
        <div className="fact"><span className="fk">Comments</span><span className="fv">1.2K</span><span className="src-tag">YouTube</span></div>
        <div className="fact"><span className="fk">Bitrate</span><span className="fv dim">Native sources only</span><span className="src-tag">—</span></div>
      </div>
      <div className="about-sec">Description</div>
      <div className="about-bio">Official audio for “Neon Skyline” from the album <i>Monsters</i> — saxophone-driven synthwave evoking 1980s film soundtracks. <span className="more" role="button" tabIndex={0}>more</span></div>
      <div className="src-tag" style={{ marginTop: 6 }}>Description — YouTube</div>
      <div className="about-sec">Credits</div>
      {aboutInfo.credits.map((c, i) => (
        <div className="credit-row" key={i}><span><div className="role">{c.role}</div>{c.name}</span><span className="src-tag">{c.source}</span></div>
      ))}
      <div className="about-sec">About the artist</div>
      <div className="about-hero g3"><div className="scrim" /><div className="nm">The Midnight</div></div>
      <div className="about-bio">{aboutInfo.bio} <span className="more" role="button" tabIndex={0}>more</span></div>
      <div className="src-tag" style={{ marginTop: 6 }}>Trivia — {aboutInfo.bioSource}</div>
      <div className="about-sec">More from The Midnight</div>
      <div className="table">{relatedSongs.map((s, i) => (
        <div className="trow" key={i}><span className="idx"><span className="num">{i + 1}</span><span className="pbtn" role="button" tabIndex={0} aria-label={`Play ${s.title}`}><Icon name="play" size={13} /></span></span>
          <span className="cell-main"><span className={'mini ' + G(i + 3)} /><span><div className="n">{s.title}</div></span></span>
          <span className="muted">{s.artist}</span><span /><span /><span className="time">{s.time}</span></div>
      ))}</div>
      <div className="src-tag" style={{ marginTop: 6 }}>Related — built by PhonoDeck from YouTube search</div>
    </div>
  );
}

export function AboutUnavailable() {
  return (
    <div>
      <ReadinessCallout src="ytm" status="policyBlocked" title="About this song" detail="Artist biography, credits, and canonical album facts are not exposed by YouTube Music's public API. PhonoDeck shows attributed provider facts when a catalog source is connected." />
      <div className="about-sec">Available facts</div>
      <div className="facts">
        <div className="fact"><span className="fk">Duration</span><span className="fv">3:35</span><span className="src-tag">YouTube</span></div>
        <div className="fact"><span className="fk">Year</span><span className="fv dim">Not exposed</span><span className="src-tag">—</span></div>
        <div className="fact"><span className="fk">Credits</span><span className="fv dim">Not available</span><span className="src-tag">—</span></div>
        <div className="fact"><span className="fk">Bitrate</span><span className="fv dim">Native sources only</span><span className="src-tag">—</span></div>
      </div>
    </div>
  );
}

export const phase5Albums = [
  { title: 'Monsters', artist: 'The Midnight', count: 5, src: 'ytm', source: 'Derived from YouTube results' },
  { title: 'OutRun', artist: 'Kavinsky', count: 3, src: 'ytm', source: 'Derived from YouTube results' },
  { title: 'Bloom (FLAC)', artist: 'RÜFÜS DU SOL', count: 11, src: 'plex', source: 'Plex library metadata' },
  { title: 'Presence', artist: 'Petit Biscuit', count: 14, src: 'spotify', source: 'Spotify catalog metadata' },
];

export const phase5Artists = [
  { name: 'The Midnight', count: 9, src: 'ytm', source: 'Derived from YouTube channels' },
  { name: 'Kavinsky', count: 4, src: 'ytm', source: 'Derived from YouTube channels' },
  { name: 'RÜFÜS DU SOL', count: 24, src: 'plex', source: 'Plex artist metadata' },
  { name: 'M83', count: 18, src: 'spotify', source: 'Spotify artist metadata' },
];

export function Phase5AlbumCard({ album = phase5Albums[0], index = 0 }) {
  return (
    <div className="card limited-card">
      <div className={'art ' + G(index)}><SourceBadge src={album.src} variant="corner" /></div>
      <div className="c-title">{album.title}</div>
      <div className="c-sub">{album.artist}</div>
      <div className="limited-note">{album.count} songs · {album.source}</div>
    </div>
  );
}

export function Phase5ArtistCard({ artist = phase5Artists[0], index = 0 }) {
  return (
    <div className="card limited-card">
      <div className={'avatar ' + G(index)}><SourceBadge src={artist.src} variant="corner" /></div>
      <div className="c-title">{artist.name}</div>
      <div className="c-sub">{artist.count} songs</div>
      <div className="limited-note">{artist.source}</div>
    </div>
  );
}

export function LimitedEmpty({ symbol = 'info', title, detail }) {
  return <div className="limited-empty"><div className="ic"><Icon name={symbol} size={20} /></div><div><div className="n">{title}</div><div className="d">{detail}</div></div></div>;
}

export function AlbumsSurface({ mode = 'limited' }) {
  const real = mode === 'real';
  const empty = mode === 'empty';
  const albums = real ? phase5Albums.slice(2) : phase5Albums;
  return (
    <div className="scroll">
      <div className="page-title">Albums</div>
      <div className="page-sub">Album catalog surfaces require provider-grade metadata. YouTube-only groupings stay labeled as limited.</div>
      {empty && <ReadinessCallout src="plex" status="notConnected" title="No album catalog source is ready" detail="Connect Plex, Spotify, or Own Files metadata before Albums can behave like a canonical catalog." />}
      {!empty && !real && <ReadinessCallout src="ytm" status="policyBlocked" title="Limited album grouping" detail="These albums are derived from YouTube Music results and may miss year, label, credits, track order, and canonical album identity." />}
      {real && <ReadinessCallout src="plex" status="ready" title="Plex album metadata ready" detail="Showing albums from a connected catalog source with native playback routes where available." />}
      {!empty && <><div className="coll-toolbar phase5-toolbar"><label className="searchbar"><Icon name="search" size={14} /><input placeholder="Find albums" aria-label="Find albums" /></label><SourceFilterChips active="all" /></div><div className="row wraprow">{albums.map((album, index) => <Phase5AlbumCard key={album.title} album={album} index={index} />)}</div></>}
      {empty && <LimitedEmpty symbol="stack" title="Albums need a catalog source" detail="YouTube Music search can play songs, but it does not expose canonical albums to third-party apps." />}
    </div>
  );
}

export function ArtistsSurface({ mode = 'limited' }) {
  const real = mode === 'real';
  const empty = mode === 'empty';
  const artists = real ? phase5Artists.slice(2) : phase5Artists;
  return (
    <div className="scroll">
      <div className="page-title">Artists</div>
      <div className="page-sub">Artist pages stay restrained until a catalog source provides artist identity, imagery, and facts.</div>
      {empty && <ReadinessCallout src="spotify" status="notConnected" title="No artist catalog source is ready" detail="Connect Spotify, Plex, or Own Files metadata before Artists can behave like canonical artist pages." />}
      {!empty && !real && <ReadinessCallout src="ytm" status="policyBlocked" title="Limited artist grouping" detail="These artists are derived from YouTube channels/results. Subscriber counts, bios, credits, and canonical identities are not inferred." />}
      {real && <ReadinessCallout src="spotify" status="ready" title="Artist metadata ready" detail="Showing artists from a connected catalog source; rich hero and bio can be enabled only when provider facts are present." />}
      {!empty && <><div className="coll-toolbar phase5-toolbar"><label className="searchbar"><Icon name="search" size={14} /><input placeholder="Find artists" aria-label="Find artists" /></label><SourceFilterChips active="all" /></div><div className="row wraprow">{artists.map((artist, index) => <Phase5ArtistCard key={artist.name} artist={artist} index={index} />)}</div></>}
      {empty && <LimitedEmpty symbol="mic" title="Artists need a catalog source" detail="YouTube channels are not the same thing as music artists, so PhonoDeck does not present them as canonical artist pages." />}
    </div>
  );
}

export function HomeState({ state = 'partial' }) {
  if (state === 'empty') return <div className="scroll"><LibraryEmptyState /></div>;
  return (
    <div className="scroll">
      <div className="page-title">Home</div>
      <div className="page-sub">Recent, recommended, and resumable — source-marked and honest about partial provider availability.</div>
      {state === 'partial' && <ReadinessCallout src="spotify" status="notConnected" title="Some services are not connected" detail="Showing YouTube Music and PhonoDeck history. Connect Spotify or Plex to expand the Home shelves." />}
      {state === 'stale' && <ReadinessCallout src="ytm" status="rateLimited" title="Showing cached Home shelves" detail="YouTube rate-limited fresh discovery. Cached recent songs and playlists stay visible." />}
      <TopPicksShelf />
      <SongCarouselShelf title="Recently Played" items={sampleSongs} showAll />
      <DiscoveryShelf title="Available From Your Services" />
      <ConnectedServicesRow items={state === 'partial' ? connectedServices.slice(0, 2) : connectedServices} />
    </div>
  );
}

export function SearchState({ state = 'rateLimited' }) {
  const loading = state === 'loading';
  const noResults = state === 'noResults';
  const fallback = state === 'fallback';
  const rateLimited = state === 'rateLimited';
  return (
    <div className="scroll">
      <div className="page-title">Songs</div>
      <div className="page-sub">YouTube Music · Songs — switch to Video for clips and music videos.</div>
      {loading && <div className="state-card"><div className="spinner" /><div><div className="n">Searching YouTube Music</div><div className="d">Song-first results load without blocking cached shelves.</div></div></div>}
      {rateLimited && <ReadinessCallout src="ytm" status="rateLimited" title="Search is rate limited" detail="Showing cached results where available. Try another query or retry later." />}
      {fallback && <ReadinessCallout src="ytm" status="partial" title="Using Cached Official Results" detail="The official YouTube API is temporarily unavailable, so PhonoDeck is showing cached official results." />}
      {noResults && <LimitedEmpty symbol="search" title="No songs found" detail="Check the spelling, switch to Video mode, or search another artist/title." />}
      {!noResults && !loading && <><div className="chips"><span className="pill plan" style={{ background: 'var(--selection)', color: 'var(--label)' }}>Recent: synthwave</span><span className="pill plan">lo-fi beats</span><span className="pill plan">80s hits</span></div><SongTable songs={fallback ? mixedSongs.slice(0, 5) : sampleSongs} /><div style={{ textAlign: 'center', marginTop: 14 }}><button className="btn bordered"><Icon name="down" size={15} />Load More</button></div></>}
    </div>
  );
}

export function LibraryState({ state = 'partial' }) {
  if (state === 'empty') return <div className="scroll"><LibraryEmptyState /></div>;
  return (
    <div className="scroll">
      <div className="page-title">Library</div>
      <div className="page-sub">A unified library view, with each row and card marked by source and readiness.</div>
      {state === 'partial' && <ReadinessCallout src="plex" status="notConfigured" title="Showing YouTube library only" detail="Plex and Spotify are not ready yet, so the Library is not claiming a complete cross-source catalog." />}
      <SourceFilterChips active="all" />
      <div className="shelf"><div className="shelf-h"><h3>Playlists</h3><a>Show All ›</a></div><div className="row">{samplePlaylists.slice(0, 4).map((p, i) => <PlaylistArtworkCard key={i} index={i} title={p.title} count={p.count} src={p.src} />)}</div></div>
      <div className="shelf"><div className="shelf-h"><h3>Songs</h3></div><SongTable songs={mixedSongs} /></div>
    </div>
  );
}

export function PlaylistsState({ state = 'missingScope' }) {
  return (
    <div className="scroll">
      <div className="page-title">YouTube Music Playlists</div>
      <div className="page-sub">Provider-backed playlists only. Write actions require official account scopes.</div>
      {state === 'missingScope' && <ReadinessCallout src="ytm" status="missingScope" title="Playlist write permission needed" detail="Reconnect YouTube to grant the playlist write scope before creating or adding songs." />}
      {state === 'empty' && <LimitedEmpty symbol="list" title="No playlists loaded" detail="Connect YouTube or search for songs while playlist loading catches up." />}
      {state !== 'empty' && <><div className="coll-toolbar phase5-toolbar"><button className="btn bordered"><Icon name="plus" size={14} />New Playlist</button><label className="searchbar"><Icon name="search" size={14} /><input placeholder="Find in playlist" aria-label="Find in playlist" /></label></div><SongTable songs={sampleSongs.slice(0, 4)} /></>}
    </div>
  );
}

export function QueueState({ state = 'blocked' }) {
  if (state === 'empty') return <div className="scroll"><div className="page-title">Queue</div><LimitedEmpty symbol="list" title="There is no music in the queue" detail="Play a song, open a playlist, or add rows to queue from Search, Albums, Artists, or Playlists." /></div>;
  const blocked = { title: 'Plex track without ready route', artist: 'Home Server', album: 'No Plex server configured', time: '—', src: 'plex', badge: 'Blocked' };
  return <div className="scroll"><div className="page-title">Queue</div><div className="page-sub">Blocked items remain visible with the source reason; native playback does not attempt to load them.</div><ReadinessCallout src="plex" status="notConfigured" title="Queue item blocked" detail="No Plex music server is configured, so this item cannot start native playback." /><SongTable songs={[sampleSongs[0], blocked, sampleSongs[1]]} /></div>;
}

const evidenceTime = 'Today 04:58';
const storagePolicies = [
  { src: 'ytm', state: 'Metadata only', detail: 'Metadata and artwork cache only. YouTube media downloads remain unavailable.' },
  { src: 'spotify', state: 'Unavailable', detail: 'Spotify offline files are not exposed for third-party app storage.' },
  { src: 'plex', state: 'Planned', detail: 'Owned-media storage requires a future Plex operation with permission and disk preflight.' },
  { src: 'own', state: 'Local', detail: 'User-selected local files remain offline when import/indexing lands.' },
];

export function EvidenceLine({ label, value }) {
  return <div className="evidence-line"><span>{label}</span><b>{value}</b></div>;
}

export function StorageCenter({ state = 'populated' }) {
  const empty = state === 'empty';
  const receipt = state === 'receipt';
  const error = state === 'error';
  return (
    <div className="scroll ops-page">
      <div className="page-title">Storage Center</div>
      <div className="page-sub">Metadata, artwork, and supported-source storage. No YouTube or Spotify media downloads.</div>
      <div className="ops-grid">
        <div className="ops-metric"><Icon name="list" /><div><b>{empty ? '0 KB' : '18.4 MB'}</b><span>Metadata · measured {evidenceTime}</span><EvidenceLine label="Source" value="PhonoDeck metadata cache" /></div></div>
        <div className="ops-metric"><Icon name="note" /><div><b>{empty ? '0 KB' : '42.7 MB'}</b><span>Artwork · measured {evidenceTime}</span><EvidenceLine label="Source" value="PhonoDeck artwork cache" /></div></div>
        <div className="ops-metric blocked"><Icon name="down" /><div><b>0 B</b><span>Owned media · checked {evidenceTime}</span><EvidenceLine label="Scope" value="YouTube/Spotify policy blocked" /></div></div>
      </div>
      {state === 'confirm' && <ReadinessCallout src="ytm" status="partial" title="Clear metadata cache?" detail="This removes PhonoDeck metadata/artwork cache only. It keeps account tokens, playlists, user-owned files, and provider libraries." />}
      {receipt && <div className="receipt"><Icon name="info" /><div><b>Metadata cache cleared</b><span>Completed {evidenceTime}. Previous cache: 18.4 MB. Retained Google tokens, playlists, and media files.</span></div></div>}
      {error && <ReadinessCallout src="ytm" status="providerUnavailable" title="Storage measurement partial" detail="Artwork cache size could not be measured; metadata and policy rows are still current." />}
      {empty ? <LimitedEmpty symbol="list" title="No local cache yet" detail="Search or browse music to populate metadata and artwork caches. YouTube media files will not appear here." /> : <div className="panel"><h3>Stored Items</h3><div className="srow"><div><div className="n">YouTube Music metadata cache</div><div className="d">Metadata · cached · measured {evidenceTime}</div></div><span className="pill ok right">18.4 MB</span></div><div className="srow"><div><div className="n">Artwork cache</div><div className="d">Artwork · cached · measured {evidenceTime}</div></div><span className="pill ok right">42.7 MB</span></div></div>}
      <div className="panel"><h3>Source Policies</h3>{storagePolicies.map((policy) => <div className="srow" key={policy.src}><div className="ic" style={{ background: `color-mix(in srgb, ${sourceMeta[policy.src].color} 16%, transparent)`, color: sourceMeta[policy.src].color }}><Icon name="down" /></div><div><div className="n">{sourceMeta[policy.src].name}</div><div className="d">{policy.detail}</div><EvidenceLine label="Source" value="Storage policy catalog" /><EvidenceLine label="Checked" value={evidenceTime} /></div><span className="pill plan right">{policy.state}</span></div>)}</div>
    </div>
  );
}

const deviceRows = [
  { src: 'ytm', title: 'YouTube Web Playback', state: 'Limited', source: 'YouTube IFrame API', detail: 'The visible YouTube player owns output selection. PhonoDeck cannot force HomePod or Cast routing.' },
  { src: 'plex', title: 'Native AVFoundation Routes', state: 'Available', source: 'AVRoutePickerView', detail: 'Native Plex and Own Files playback can use the system route picker after a ready native route.' },
  { src: 'own', title: 'HomePod Default Service', state: 'Not exposed', source: 'HomeKit public API', detail: 'HomeKit does not expose whether HomePod is configured to use YouTube Music as a default service.' },
  { src: 'spotify', title: 'Cross-device Listening History', state: 'Not exposed', source: 'Provider APIs', detail: 'Provider APIs do not expose a full device history with iPhone, TV, car, or speaker names.' },
];

export function DevicesSurface({ mode = 'youtube' }) {
  return (
    <div className="scroll ops-page">
      <div className="page-title">Devices</div>
      <div className="page-sub">Route capability and public API readiness. This is not a fabricated device inventory.</div>
      {mode === 'native' ? <ReadinessCallout src="plex" status="ready" title="Native route picker available" detail="System AirPlay route picker is available for ready native AVFoundation playback." /> : <ReadinessCallout src="ytm" status="policyBlocked" title="YouTube route is web-player owned" detail="The visible official YouTube player owns output selection; PhonoDeck cannot enumerate or force routes." />}
      {mode === 'native' && <div className="airplay-preview" role="button" tabIndex={0} aria-label="System AirPlay route picker preview"><Icon name="airplay" size={20} /><div><b>System AirPlay Route Picker</b><span>Native macOS control · opens system-owned route menu</span></div></div>}
      <div className="panel"><h3>Route Capability Evidence</h3>{deviceRows.map((row) => <div className="srow" key={row.title}><div className="ic" style={{ background: `color-mix(in srgb, ${sourceMeta[row.src].color} 16%, transparent)`, color: sourceMeta[row.src].color }}><Icon name={row.src === 'plex' ? 'airplay' : 'info'} /></div><div><div className="n">{row.title}</div><div className="d">{row.detail}</div><EvidenceLine label="Source" value={row.source} /><EvidenceLine label="Checked" value={evidenceTime} /></div><span className="pill plan right">{row.state}</span></div>)}</div>
    </div>
  );
}

const providerRuns = {
  success: [
    { id: 'official', status: 'Ready', detail: 'Documented Data API completed normally.', src: 'ytm', items: 12, cache: 'refreshed', requests: '+1', error: '—' },
    { id: 'experimental', status: 'Disabled', detail: 'Undocumented metadata path is blocked by product policy.', src: 'yt', items: 0, cache: 'none', requests: '0', error: 'policyDisabled' },
  ],
  quota: [
    { id: 'official', status: 'Quota exceeded', detail: 'Official provider failed; cached fallback retained.', src: 'ytm', items: 6, cache: 'stale cache', requests: '+1', error: 'quotaExceeded' },
    { id: 'experimental', status: 'Disabled', detail: 'No undocumented fallback is used when official quota is exhausted.', src: 'yt', items: 0, cache: 'none', requests: '0', error: 'policyDisabled' },
  ],
  timeout: [
    { id: 'official', status: 'Ready', detail: 'Documented provider completed; diagnostics remain useful.', src: 'ytm', items: 12, cache: 'refreshed', requests: '+1', error: '—' },
    { id: 'experimental', status: 'Disabled', detail: 'Timeout state retired; the provider is not contacted.', src: 'yt', items: 0, cache: 'none', requests: '0', error: 'policyDisabled' },
  ],
  failed: [
    { id: 'official', status: 'Failed', detail: 'Authorization expired; reconnect Google.', src: 'ytm', items: 0, cache: 'none', requests: '+1', error: 'authorizationExpired' },
    { id: 'experimental', status: 'Disabled', detail: 'No private metadata request is attempted after official auth failure.', src: 'yt', items: 0, cache: 'none', requests: '0', error: 'policyDisabled' },
  ],
  auth: [
    { id: 'official', status: 'Auth required', detail: 'Connect Google to use official YouTube API diagnostics.', src: 'ytm', items: 0, cache: 'none', requests: '0', error: 'connectRequired' },
    { id: 'experimental', status: 'Disabled', detail: 'Signed-out metadata discovery still requires official API policy boundaries.', src: 'yt', items: 0, cache: 'none', requests: '0', error: 'policyDisabled' },
  ],
  offline: [
    { id: 'official', status: 'Offline cache', detail: 'Network unavailable; warm cache retained.', src: 'ytm', items: 5, cache: 'warm cache', requests: '0', error: 'networkOffline' },
    { id: 'experimental', status: 'Disabled', detail: 'Only official cached results are retained; no private cache bucket is created.', src: 'yt', items: 0, cache: 'none', requests: '0', error: 'policyDisabled' },
  ],
  invalid: [
    { id: 'official', status: 'Invalid response', detail: 'Provider returned malformed JSON.', src: 'ytm', items: 0, cache: 'none', requests: '+1', error: 'invalidProviderResponse' },
    { id: 'experimental', status: 'Disabled', detail: 'No private fallback is used after official parse errors.', src: 'yt', items: 0, cache: 'none', requests: '0', error: 'policyDisabled' },
  ],
  long: [
    { id: 'official', status: 'Ready', detail: 'Very long diagnostic result title remains wrapped without hiding evidence rows.', src: 'ytm', items: 12, cache: 'refreshed', requests: '+1', error: '—' },
    { id: 'experimental', status: 'Disabled', detail: 'Disabled-provider evidence stays readable in narrow layouts.', src: 'yt', items: 0, cache: 'none', requests: '0', error: 'policyDisabled' },
  ],
};

export function ProviderLabDiagnostics({ state = 'success' }) {
  const rows = providerRuns[state] || providerRuns.success;
  const comparing = state === 'comparing';
  return (
    <div className="scroll ops-page provider-lab">
      <div className="page-title">Provider Lab Diagnostics</div>
    <div className="page-sub">Diagnostic evidence for official YouTube API readiness and disabled undocumented metadata policy.</div>
      {state === 'noQuery' && <LimitedEmpty symbol="search" title="No diagnostic query" detail="Search or select a song first; Provider Lab keeps diagnostics tied to a real query." />}
      {comparing && <ReadinessCallout src="ytm" status="partial" title="Comparison running" detail="Keeping previous results visible while the diagnostic run completes." />}
      <div className="run-card"><div><b>Run ytlab-20260624-0458</b><span>Query: {state === 'long' ? 'A very long artist and song title that still fits narrow diagnostic layouts' : 'Neon Skyline'} · Preference: Song First</span><EvidenceLine label="Started" value={evidenceTime} /><EvidenceLine label="Completed" value={comparing ? 'Still running' : 'Today 04:58:09'} /><EvidenceLine label="Duration" value={comparing ? '—' : '1.42s'} /></div><span className="pill ok">{comparing ? 'Running' : 'Completed'}</span></div>
      <div className="ops-grid">{rows.map((row) => <div className="provider-card" key={row.id}><SourceBadge src={row.src} /><h3>{row.id === 'official' ? 'Official YouTube API' : 'Disabled metadata path'}</h3><p>{row.detail}</p><EvidenceLine label="Status" value={row.status} /><EvidenceLine label="Items" value={String(row.items)} /><EvidenceLine label="Cache" value={row.cache} /><EvidenceLine label="Requests" value={row.requests} /><EvidenceLine label="Error" value={row.error} /><EvidenceLine label="Risk" value={row.id === 'official' ? 'Documented API' : 'Disabled'} /></div>)}</div>
    </div>
  );
}

/* ====== Cinematic Artist page (Apple Music) — hero + Latest Release + Top Songs + Essential Albums ====== */
export function ArtistPage({ artist = artistInfo }) {
  return (
    <div className="scroll artist-page">
      <div className={'artist-hero ' + artist.g}>
        <div className="ah-scrim" />
        <div className="ah-meta">
          <div className="ah-eyebrow">Artist</div>
          <div className="ah-name">{artist.name}</div>
          <div className="ah-sub">{artist.listeners}</div>
        </div>
        <div className="ah-actions">
          <button className="ah-play" aria-label={`Play ${artist.name}`}><Icon name="play" size={16} />Play</button>
          <LikeButton size={18} label={`Subscribe to ${artist.name} on YouTube`} />
          <button className="ah-ellipsis" aria-label="More"><Icon name="ellipsis" size={18} /></button>
        </div>
      </div>
      <div className="artist-cols">
        <div className="latest">
          <div className="about-sec" style={{ marginTop: 0 }}>Latest Release</div>
          <div className="latest-card">
            <div className={'latest-art ' + artist.latest.g} />
            <div className="latest-info">
              <div className="lt">{artist.latest.title}</div>
              <div className="ls">{artist.latest.kind} · {artist.latest.year}</div>
              <div className="ls">{artist.latest.tracks} songs</div>
              <button className="btn bordered" style={{ marginTop: 10 }}><Icon name="play" size={14} />Play</button>
            </div>
          </div>
        </div>
        <div className="topsongs">
          <div className="about-sec" style={{ marginTop: 0 }}>Top Songs</div>
          <div className="table">
            {artistTopSongs.map((s, i) => (
              <div className="trow" key={i}>
                <span className="idx"><span className="num">{i + 1}</span><span className="pbtn" role="button" tabIndex={0} aria-label={`Play ${s.title}`}><Icon name="play" size={13} /></span></span>
                <span className="cell-main"><span className={'mini ' + G(i)} /><span style={{ minWidth: 0 }}><div className="n">{s.title}</div><div className="badge">{s.badge} · {s.plays} plays</div></span></span>
                <span className="time">{s.time}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
      <div className="shelf" style={{ marginTop: 26 }}>
        <div className="shelf-h"><h3>Essential Albums</h3><a>Show All ›</a></div>
        <div className="row">{essentialAlbums.map((a, i) => <PlaylistArtworkCard key={i} index={i + 2} title={a.title} count={a.count} />)}</div>
      </div>
      <div className="src-tag" style={{ marginTop: 6 }}>Bio &amp; related — built by PhonoDeck from YouTube + Wikipedia (CC BY-SA)</div>
    </div>
  );
}

/* ====== FullScreenPlayer — optional Now Playing takeover (companion to the right inspector) ====== */
export function FullScreenPlayer({ source = 'ytm' }) {
  const youtube = source === 'ytm' || source === 'yt';
  return (
    <div className="fsp">
      <AmbientBackdrop g="g6" className="fsp-ambient" />
      <div className="fsp-top">
        <button className="fsp-close" aria-label="Close full screen"><Icon name="down" size={18} /></button>
        <div className="fsp-srcline" style={{ color: sourceMeta[source].color }}>● {sourceMeta[source].name}</div>
      </div>
      <div className="fsp-stage">
        {youtube
          ? <div className="fsp-media"><iframe title="Visible official YouTube player" src="https://www.youtube.com/embed/fJ9rUzIMcZQ?rel=0&modestbranding=1" allow="accelerometer; encrypted-media; picture-in-picture" allowFullScreen /></div>
          : <div className="fsp-media square g6" />}
        <div className="fsp-titlerow">
          <div style={{ minWidth: 0 }}><div className="fsp-title">Neon Skyline</div><div className="fsp-artist">The Midnight</div></div>
          <LikeButton on size={22} />
          <button className="ah-ellipsis" aria-label="More"><Icon name="ellipsis" size={20} /></button>
        </div>
        <div className="npp-scrub" style={{ marginTop: 14 }}><span>1:24</span><div className="bar"><i /></div><span>-2:11</span></div>
        <div className="fsp-transport">
          <button className="b" aria-label="Shuffle"><Icon name="shuffle" size={18} /></button>
          <button className="b" aria-label="Previous"><Icon name="back" size={20} /></button>
          <button className="b play" aria-label={youtube ? 'Pause (visible embed)' : 'Pause'}><Icon name="pause" size={24} /></button>
          <button className="b" aria-label="Next"><Icon name="fwd" size={20} /></button>
          <button className="b" aria-label="Repeat"><Icon name="repeat" size={18} /></button>
        </div>
        <div className="fsp-foot">
          <button className="np-toggle" aria-label="Up Next"><Icon name="list" size={18} /></button>
          <div className="fsp-vol"><Icon name="speaker" size={16} /><div className="bar"><i /></div></div>
          <button className="np-toggle" aria-label="Lyrics"><Icon name="lyrics" size={18} /></button>
        </div>
        {youtube && <div className="fsp-note">Audio is the visible official YouTube player; these controls drive it via the IFrame API. System AirPlay &amp; routing aren’t available for web playback.</div>}
      </div>
    </div>
  );
}

/* ====== Up Next / Queue (panel, canonical) + Autoplay radio ====== */
export function UpNextQueue({ autoplay = true }) {
  const cur = sampleSongs[0]; const next = sampleSongs.slice(1, 5);
  return (
    <div>
      <div className="q-head"><span className="ov">Now Playing</span></div>
      <div className="q-row current"><span className={'mini ' + G(0)} /><span style={{ minWidth: 0 }}><div className="qn">{cur.title}</div><div className="qa">{cur.artist}</div></span><span className="wave" aria-label="Now playing"><Icon name="wave" size={16} /></span></div>
      <div className="q-head" style={{ marginTop: 14 }}><span className="ov">Up Next</span><span className="clear" role="button" tabIndex={0}>Clear</span></div>
      {next.map((s, i) => (
        <div className="q-row" key={i}><span className={'mini ' + G(i + 1)} /><span style={{ minWidth: 0 }}><div className="qn">{s.title}</div><div className="qa">{s.artist.split(' · ')[0]}</div></span><span className="handle" aria-label="Reorder"><Icon name="handle" size={16} /></span></div>
      ))}
      <div className="autoplay">
        <Icon name="radio" size={18} />
        <span style={{ minWidth: 0 }}><div className="ti">PhonoDeck Radio</div><div className="de">Built from YouTube search · keeps playing similar songs</div></span>
        <span className={'switch' + (autoplay ? '' : ' off')} role="switch" aria-checked={autoplay} aria-label="Autoplay"><i /></span>
      </div>
    </div>
  );
}

/* ====== Bottom Now Playing bar — transport + Like/Lyrics/Queue toggles; honest disabled ====== */
export function NowPlayingBar({ mode = 'youtube', standalone = false }) {
  const youtube = mode === 'youtube'; const empty = mode === 'empty';
  return (
    <div className={'nowbar' + (standalone ? ' standalone' : '')}>
      <div className={'np-art ' + (empty ? '' : 'g6')} />
      <div className="np-meta">
        <div className="n">{empty ? 'Select a song' : 'Neon Skyline'}</div>
        <div className="a">{empty ? 'Choose a song to start playback' : 'The Midnight'}</div>
        {!empty && <div className="src" style={{ color: youtube ? 'var(--ytm)' : 'var(--plex)' }}>● {youtube ? 'YT Music' : 'Plex'}</div>}
      </div>
      <div className="np-transport">
        <div className="np-btn" role="button" aria-label="Previous"><Icon name="back" size={16} /></div>
        <div className={'np-btn play' + (empty ? ' disabled' : '')} role="button" aria-label={empty ? 'Play' : 'Pause'}><Icon name={empty ? 'play' : 'pause'} size={20} /></div>
        <div className="np-btn" role="button" aria-label="Next"><Icon name="fwd" size={16} /></div>
      </div>
      <div className="np-progress"><span className="t">{empty ? '0:00' : '1:24'}</span><div className="bar"><i style={{ width: empty ? '0%' : '38%' }} /></div><span className="t">{empty ? '-0:00' : '-2:11'}</span></div>
      <div className="np-right">
        <div className="np-toggle like on" role="button" aria-label="Like on YouTube" aria-pressed="true" title="Like on YouTube"><Icon name="heart-fill" size={17} /></div>
        <div className="np-toggle disabled" role="button" aria-disabled="true" aria-label="Lyrics unavailable — no provider configured" title="Lyrics aren’t available for this source"><Icon name="lyrics" size={16} /></div>
        <div className="np-toggle" role="button" aria-label="Up Next" title="Up Next"><Icon name="list" size={17} /></div>
        <div className="np-divider" />
        {youtube
          ? <><div className="np-toggle" role="button" aria-label="Volume (adjusts the YouTube player)" title="Volume — adjusts the visible YouTube player"><Icon name="speaker" size={17} /></div>
              <div className="np-toggle disabled" role="button" aria-disabled="true" aria-label="AirPlay unavailable for web playback" title="AirPlay — not available for web playback"><Icon name="airplay" size={17} /></div>
              <div className="np-note">Visible official YouTube player · system AirPlay &amp; routing unavailable</div></>
          : <><div className="np-toggle" role="button" aria-label="AirPlay" title="AirPlay"><Icon name="airplay" size={17} /></div>
              <div className="np-toggle" role="button" aria-label="Volume" title="Volume"><Icon name="speaker" size={17} /></div></>}
      </div>
    </div>
  );
}

/* ====== Sidebar — brand header (no marketing tag) + consolidated groups (no count badges, no Queue row) ====== */
const SIDEBAR = [
  { title: 'PhonoDeck', items: [['home', 'Home', 'house'], ['search', 'Search', 'search']] },
  { title: 'Library', items: [['playlists', 'Playlists', 'list'], ['albums', 'Albums', 'stack'], ['artists', 'Artists', 'mic'], ['songs', 'Songs', 'note'], ['downloads', 'Downloads', 'down']] },
  { title: 'System', items: [['devices', 'Devices', 'airplay'], ['settings', 'Settings', 'gear']] },
];
export function SidebarView({ active = 'home' }) {
  return (
    <nav className="sidebar" aria-label="Sidebar">
      <div className="brand-header"><div className="brand-mark" aria-hidden="true"><Icon name="note" size={16} /></div><span className="brand-word">PhonoDeck</span></div>
      {SIDEBAR.map((g) => (
        <div className="side-group" key={g.title}>
          <div className="side-head">{g.title}</div>
          {g.items.map(([id, label, icon]) => (
            <div className={'side-item' + (active === id ? ' active' : '')} key={id} role="button" tabIndex={0} aria-current={active === id}><Icon name={icon} /> {label}</div>
          ))}
        </div>
      ))}
    </nav>
  );
}

/* ====== Onboarding ====== */
export function WelcomeSheet() {
  return (
    <div className="sheet">
      <div className="head"><div className="icon"><Icon name="house" size={24} /></div>
        <div><h2>Welcome to PhonoDeck</h2><p className="lead">Bringing all music into one place.</p><p>Start with the Library, then add the music services you want PhonoDeck to bring together.</p></div></div>
      <div className="foot"><button className="btn primary">Continue</button></div>
    </div>
  );
}
export function LibraryEmptyState() {
  return (
    <div className="empty"><svg className="glyph"><use href="#i-note" /></svg>
      <h2>Bring All Music Into One Place</h2>
      <p>Connect your music services to build a single library across YouTube Music, Spotify, and Plex.</p>
      <div className="btns"><button className="btn primary"><Icon name="note" size={15} />Connect YouTube</button><button className="btn bordered"><Icon name="speaker" size={15} />Add Spotify</button><button className="btn bordered"><Icon name="stack" size={15} />Add Plex</button></div>
    </div>
  );
}

/* ====== Shell ====== */
const TITLES = { home: 'Home', firstrun: 'Home', playlist: 'Late Night Drive', queue: 'Queue', search: 'Search', settings: 'Settings', artist: 'Artists', artists: 'Artists', albums: 'Albums', library: 'Library' };

function HomeScreen() {
  return (
    <div className="scroll">
      <div className="page-title">Home</div>
      <div className="page-sub">Recent, recommended, and resumable — across your connected sources.</div>
      <TopPicksShelf />
      <FeatureHeroCard />
      <DiscoveryShelf />
      <SongCarouselShelf title="Recently Played" items={sampleSongs} showAll />
      <SongCarouselShelf title="Made for You" items={[...sampleSongs].reverse()} />
      <div className="shelf"><div className="shelf-h"><h3>Your Playlists</h3><a>Show All ›</a></div><div className="row">{samplePlaylists.map((p, i) => <PlaylistArtworkCard key={i} index={i} title={p.title} count={p.count} src={p.src} />)}</div></div>
      <ConnectedServicesRow />
      <div className="shelf"><div className="shelf-h"><h3>Your Subscriptions</h3></div><div className="row">{sampleSubs.map((s, i) => <SubscriptionAvatarCard key={i} index={i} title={s} />)}</div></div>
    </div>
  );
}
function ScreenBody({ screen }) {
  if (screen === 'firstrun') return <div style={{ height: '100%', position: 'relative' }}><LibraryEmptyState /><div className="sheet-scrim"><WelcomeSheet /></div></div>;
  if (screen === 'artist') return <ArtistsSurface mode="limited" />;
  if (screen === 'artists') return <ArtistsSurface mode="limited" />;
  if (screen === 'albums') return <AlbumsSurface mode="limited" />;
  if (screen === 'library') return <div className="scroll">
      <div className="page-title">Library</div>
      <div className="page-sub">Your playlists and songs from every source, merged — each item discreetly marked by where it lives.</div>
      <SourceFilterChips />
      <div className="shelf"><div className="shelf-h"><h3>Playlists</h3><a>Show All ›</a></div><div className="row">{samplePlaylists.map((p, i) => <PlaylistArtworkCard key={i} index={i} title={p.title} count={p.count} src={p.src} />)}</div></div>
      <div className="shelf"><div className="shelf-h"><h3>Songs</h3></div><SongTable songs={mixedSongs} /></div>
    </div>;
  if (screen === 'playlist') return <div className="scroll"><div className="page-title">Late Night Drive</div><div className="page-sub">YouTube Music playlist · 18 songs · official account playlist API</div><SongTable /></div>;
  if (screen === 'queue') return <div className="scroll"><div className="page-title">Queue</div><div className="page-sub">The canonical queue also appears in the Now Playing panel’s Up Next tab.</div><SongTable songs={sampleSongs.slice(1)} /></div>;
  if (screen === 'search') return <div className="scroll"><div className="page-title">Songs</div><div className="page-sub">YouTube Music · Songs — switch to Video for clips and music videos.</div><div className="chips"><span className="pill plan" style={{ background: 'var(--selection)', color: 'var(--label)' }}>Recent: synthwave</span><span className="pill plan">lo-fi beats</span><span className="pill plan">80s hits</span></div><SongTable /><div style={{ textAlign: 'center', marginTop: 14 }}><button className="btn bordered"><Icon name="down" size={15} />Load More</button></div></div>;
  if (screen === 'settings') return <div className="scroll"><div className="page-title">Settings</div><div className="page-sub">Accounts, sources, and playback policy.</div>
    <div className="panel"><h3>Google Account</h3><div className="srow"><div className="ic" style={{ background: 'var(--accent-soft)', color: 'var(--accent)' }}><Icon name="person" /></div><div><div className="n">PhonoDeck Listener</div><div className="d">Connected · youtube playlist scope granted</div></div><span className="pill ok right">Connected</span></div></div>
    <div className="panel"><h3>Sources</h3>
      <ReadinessCallout src="ytm" status="ready" title="YouTube Music" detail="Search, playlists, likes, and visible official playback are ready." />
      <ReadinessCallout src="spotify" status="notConnected" title="Spotify" detail="Connect Spotify to use metadata/library and the visible official Spotify player." />
      <ReadinessCallout src="plex" status="notConfigured" title="Plex" detail="No Plex music server is configured. Native playback becomes available after setup." />
      <ReadinessCallout src="own" status="notConfigured" title="Own Files" detail="Choose a local music folder before Own Files can provide native playback." />
    </div>
    <div className="panel"><h3>Lyrics &amp; Info providers</h3><div className="srow"><div><div className="n">Lyrics provider</div><div className="d">Time-synced lyrics require a licensed provider (Musixmatch / LyricFind).</div></div><span className="pill plan right">Not configured</span></div></div>
  </div>;
  return <HomeScreen />;
}

export function Shell({ screen = 'home', showPanel = true, panelTab = 'now' }) {
  const active = screen === 'firstrun' ? 'home' : (screen === 'library' ? 'songs' : screen);
  const panel = showPanel && screen !== 'firstrun';
  return (
    <div className="window">
      <div className="titlebar">
        <div className="traffic"><i className="r" /><i className="y" /><i className="g" /></div>
        <div className="tb-icon" role="button" aria-label="Toggle sidebar" title="Toggle sidebar"><Icon name="sidebar" /></div>
        <div className="tb-title">{TITLES[screen]}</div>
        <div className="tb-search"><Icon name="search" size={14} /><span>Search songs</span></div>
        <div className="tb-actions"><div className="tb-icon" role="button" aria-label="Share"><Icon name="share" size={16} /></div><div className="tb-icon" role="button" aria-label="Account"><Icon name="person" /></div></div>
      </div>
      <div className="body">
        <SidebarView active={active} />
        <main className="content"><ScreenBody screen={screen} /></main>
        {panel && <NowPlayingPanel tab={panelTab} source="ytm" />}
      </div>
      {screen !== 'firstrun' && <NowPlayingBar mode="youtube" />}
    </div>
  );
}
