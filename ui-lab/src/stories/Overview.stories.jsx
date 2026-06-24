import React from 'react';

function Overview() {
  return (
    <div style={{ maxWidth: 720, color: 'var(--label)', lineHeight: 1.5 }}>
      <h1 style={{ fontSize: 24, fontWeight: 760, margin: '0 0 6px' }}>PhonoDeck UI Lab</h1>
      <p style={{ color: 'var(--label-2)', margin: '0 0 16px' }}>
        Design-validation workbench. Browse components by their real Swift names, switch screens,
        toggle Light/Dark (toolbar), and run the Accessibility addon. Validate UI here, then build
        it natively in SwiftUI.
      </p>
      <div style={{ background: 'var(--elev)', border: '0.5px solid var(--hairline)', borderRadius: 8, padding: 14, marginBottom: 14 }}>
        <strong>⚠️ Not the app.</strong> The real PhonoDeck macOS app is <strong>native SwiftUI</strong> in
        <code> Sources/PhonoDeck</code>. These stories are throwaway visual mocks.
      </div>
      <ul style={{ color: 'var(--label-2)', fontSize: 13, paddingLeft: 18 }}>
        <li><strong>Screens</strong> — full window compositions (Library, First run, Playlist, Queue, Search, Settings).</li>
        <li><strong>Shell</strong> — SidebarView, NowPlayingBar (with honest per-source variants).</li>
        <li><strong>Components</strong> — SongResultRow, PlaylistArtworkCard, SubscriptionAvatarCard, SourcePill, SongCarouselShelf.</li>
        <li><strong>Onboarding</strong> — PhonoDeckWelcomeSheet, libraryEmptyState.</li>
      </ul>
      <p style={{ color: 'var(--label-3)', fontSize: 12, marginTop: 14 }}>
        Source of truth for names/flows/sources: <code>docs/design/phonodeck-ui-map.json</code>.
        Cited HIG rules: <code>docs/design/design-system-research.md</code>.
      </p>
    </div>
  );
}

export default { title: 'Overview', parameters: { layout: 'centered' } };
export const ReadMe = { render: () => <Overview /> };
