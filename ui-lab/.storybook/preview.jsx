import React from 'react';
import '../src/phonodeck.css';
import { IconSprite } from '../src/icons.jsx';

export const globalTypes = {
  appearance: {
    name: 'Appearance',
    description: 'Light or Dark (validate both — research §9)',
    defaultValue: 'dark',
    toolbar: {
      icon: 'mirror',
      dynamicTitle: true,
      items: [
        { value: 'dark', title: 'Dark' },
        { value: 'light', title: 'Light' },
      ],
    },
  },
};

export const decorators = [
  (Story, ctx) => {
    const light = ctx.globals.appearance === 'light';
    return (
      <div
        className={'pd ' + (light ? 'light' : 'dark')}
        style={{ background: light ? '#d7d7da' : '#0c0c0e', padding: 24, minHeight: '100vh' }}
      >
        <IconSprite />
        <Story />
      </div>
    );
  },
];

export const parameters = {
  layout: 'fullscreen',
  controls: { expanded: true },
  a11y: { test: 'todo' },
  options: {
    storySort: { order: ['Overview', 'Screens', 'Shell', 'Components', 'Onboarding'] },
  },
};
