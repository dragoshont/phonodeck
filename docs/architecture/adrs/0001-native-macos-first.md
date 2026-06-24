# ADR 0001: Native macOS First

## Status

Accepted

## Context

The product goal is to recreate the feel of a stock macOS music app, not a web wrapper. Apple HIG emphasizes Mac-specific behavior: menu bar commands, keyboard shortcuts, resizable windows, sidebars, standard toolbars, high-precision input, and user customization.

## Decision

PhonoDeck will use a native macOS app architecture with SwiftUI as the main UI layer, AppKit where system behavior requires it, and AVFoundation/MediaPlayer for playback integration.

## Consequences

- P0 work must build as a macOS app, not only a web app.
- Source-specific web surfaces may exist only where the source requires them, such as YouTube embedded playback.
- Every feature must have a native command, menu, keyboard, or accessibility story when applicable.
