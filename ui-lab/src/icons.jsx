import React from 'react';

/* Simplified inline-SVG stand-ins for SF Symbols (SF Symbols are licensed; the real app uses them). */
export function IconSprite() {
  return (
    <svg width="0" height="0" style={{ position: 'absolute' }} aria-hidden="true">
      <defs>
        <symbol id="i-note" viewBox="0 0 24 24"><path fill="currentColor" d="M9 17V5l10-2v12"/><circle cx="6.5" cy="17" r="2.5" fill="currentColor"/><circle cx="16.5" cy="15" r="2.5" fill="currentColor"/></symbol>
        <symbol id="i-search" viewBox="0 0 24 24"><circle cx="11" cy="11" r="6" fill="none" stroke="currentColor" strokeWidth="2"/><path d="M20 20l-4-4" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round"/></symbol>
        <symbol id="i-list" viewBox="0 0 24 24"><path fill="currentColor" d="M4 6h16v2H4zM4 11h16v2H4zM4 16h10v2H4z"/></symbol>
        <symbol id="i-stack" viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="10" rx="2" fill="none" stroke="currentColor" strokeWidth="2"/><path d="M7 18h10" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></symbol>
        <symbol id="i-mic" viewBox="0 0 24 24"><rect x="9" y="3" width="6" height="11" rx="3" fill="currentColor"/><path d="M6 11a6 6 0 0 0 12 0M12 17v4" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round"/></symbol>
        <symbol id="i-down" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" strokeWidth="2"/><path d="M12 7v8m0 0l-3-3m3 3l3-3" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></symbol>
        <symbol id="i-airplay" viewBox="0 0 24 24"><path d="M6 16a8 8 0 0 1 0-10h12a8 8 0 0 1 0 10" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M12 14l5 6H7z" fill="currentColor"/></symbol>
        <symbol id="i-gear" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3" fill="none" stroke="currentColor" strokeWidth="2"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></symbol>
        <symbol id="i-play" viewBox="0 0 24 24"><path fill="currentColor" d="M8 5v14l11-7z"/></symbol>
        <symbol id="i-pause" viewBox="0 0 24 24"><path fill="currentColor" d="M7 5h4v14H7zM13 5h4v14h-4z"/></symbol>
        <symbol id="i-back" viewBox="0 0 24 24"><path fill="currentColor" d="M18 5v14l-9-7zM7 5h2v14H7z"/></symbol>
        <symbol id="i-fwd" viewBox="0 0 24 24"><path fill="currentColor" d="M6 5v14l9-7zM15 5h2v14h-2z"/></symbol>
        <symbol id="i-person" viewBox="0 0 24 24"><circle cx="12" cy="8" r="4" fill="currentColor"/><path d="M4 21a8 8 0 0 1 16 0" fill="currentColor"/></symbol>
        <symbol id="i-speaker" viewBox="0 0 24 24"><path fill="currentColor" d="M4 9h4l5-4v14l-5-4H4z"/><path d="M16 9a4 4 0 0 1 0 6" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></symbol>
        <symbol id="i-sidebar" viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="2" fill="none" stroke="currentColor" strokeWidth="2"/><path d="M9 5v14" stroke="currentColor" strokeWidth="2"/></symbol>
        <symbol id="i-share" viewBox="0 0 24 24"><path d="M12 3v12M8 7l4-4 4 4M5 12v7h14v-7" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></symbol>
        <symbol id="i-house" viewBox="0 0 24 24"><path d="M4 11l8-6 8 6v8a1 1 0 0 1-1 1h-4v-6H9v6H5a1 1 0 0 1-1-1z" fill="currentColor"/></symbol>
        <symbol id="i-heart" viewBox="0 0 24 24"><path d="M12 20s-7-4.5-9.5-9A4.5 4.5 0 0 1 12 6a4.5 4.5 0 0 1 9.5 5c-2.5 4.5-9.5 9-9.5 9z" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round"/></symbol>
        <symbol id="i-heart-fill" viewBox="0 0 24 24"><path d="M12 20s-7-4.5-9.5-9A4.5 4.5 0 0 1 12 6a4.5 4.5 0 0 1 9.5 5c-2.5 4.5-9.5 9-9.5 9z" fill="currentColor"/></symbol>
        <symbol id="i-lyrics" viewBox="0 0 24 24"><path d="M5 4h14a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H9l-4 4V6a2 2 0 0 1 2-2z" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round"/><path d="M8 9h8M8 13h5" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></symbol>
        <symbol id="i-info" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" strokeWidth="2"/><path d="M12 11v5" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><circle cx="12" cy="8" r="1.2" fill="currentColor"/></symbol>
        <symbol id="i-wave" viewBox="0 0 24 24"><path d="M4 12v0M8 8v8M12 5v14M16 9v6M20 12v0" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></symbol>
        <symbol id="i-plus" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></symbol>
        <symbol id="i-ellipsis" viewBox="0 0 24 24"><circle cx="5" cy="12" r="1.6" fill="currentColor"/><circle cx="12" cy="12" r="1.6" fill="currentColor"/><circle cx="19" cy="12" r="1.6" fill="currentColor"/></symbol>
        <symbol id="i-shuffle" viewBox="0 0 24 24"><path d="M3 7h4l10 10h4M3 17h4l3-3M14 7h3M17 4l3 3-3 3M17 14l3 3-3 3" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></symbol>
        <symbol id="i-repeat" viewBox="0 0 24 24"><path d="M4 9a5 5 0 0 1 5-5h8l-3-3M20 15a5 5 0 0 1-5 5H7l3 3" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></symbol>
        <symbol id="i-handle" viewBox="0 0 24 24"><path d="M5 8h14M5 12h14M5 16h14" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></symbol>
        <symbol id="i-radio" viewBox="0 0 24 24"><circle cx="12" cy="12" r="2.4" fill="currentColor"/><path d="M7.5 7.5a6 6 0 0 0 0 9M16.5 7.5a6 6 0 0 1 0 9M4.7 4.7a10 10 0 0 0 0 14.6M19.3 4.7a10 10 0 0 1 0 14.6" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"/></symbol>
        <symbol id="i-addplaylist" viewBox="0 0 24 24"><path d="M4 7h11M4 12h7M4 17h7" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/><path d="M16 14v6M13 17h6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></symbol>
      </defs>
    </svg>
  );
}

export function Icon({ name, size = 17 }) {
  return (
    <svg width={size} height={size} aria-hidden="true">
      <use href={`#i-${name}`} />
    </svg>
  );
}
