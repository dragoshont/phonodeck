import React from 'react';
import { WelcomeSheet, LibraryEmptyState } from '../components/PhonoDeck.jsx';

export default { title: 'Onboarding', parameters: { layout: 'centered' } };

export const WelcomeSheetStory = { name: 'PhonoDeckWelcomeSheet', render: () => <WelcomeSheet /> };

export const EmptyLibrary = {
  name: 'libraryEmptyState',
  parameters: { layout: 'fullscreen' },
  render: () => <div style={{ height: 560, width: 900, position: 'relative' }}><LibraryEmptyState /></div>,
};
