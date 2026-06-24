import React from 'react';
import { DevicesSurface, ProviderLabDiagnostics, StorageCenter } from '../components/PhonoDeck.jsx';

export default {
  title: 'Phase 6/Operational Surfaces',
  parameters: { layout: 'fullscreen' },
};

const frame = (children) => <div className="pd" style={{ minHeight: 760, background: 'var(--content-bg)' }}>{children}</div>;

export const StorageEmptyCache = { render: () => frame(<StorageCenter state="empty" />) };
export const StoragePopulated = { render: () => frame(<StorageCenter state="populated" />) };
export const StorageClearConfirmation = { render: () => frame(<StorageCenter state="confirm" />) };
export const StorageClearReceipt = { render: () => frame(<StorageCenter state="receipt" />) };
export const StoragePartialError = { render: () => frame(<StorageCenter state="error" />) };
export const DevicesYouTubeRoute = { render: () => frame(<DevicesSurface mode="youtube" />) };
export const DevicesNativeRoute = { render: () => frame(<DevicesSurface mode="native" />) };
export const ProviderLabNoQuery = { render: () => frame(<ProviderLabDiagnostics state="noQuery" />) };
export const ProviderLabComparing = { render: () => frame(<ProviderLabDiagnostics state="comparing" />) };
export const ProviderLabBothSuccess = { render: () => frame(<ProviderLabDiagnostics state="success" />) };
export const ProviderLabOfficialAuthRequired = { render: () => frame(<ProviderLabDiagnostics state="auth" />) };
export const ProviderLabOfficialQuotaCached = { render: () => frame(<ProviderLabDiagnostics state="quota" />) };
export const ProviderLabExperimentalTimeout = { render: () => frame(<ProviderLabDiagnostics state="timeout" />) };
export const ProviderLabWarmCacheOffline = { render: () => frame(<ProviderLabDiagnostics state="offline" />) };
export const ProviderLabInvalidResponse = { render: () => frame(<ProviderLabDiagnostics state="invalid" />) };
export const ProviderLabNarrowLongTitle = { render: () => <div className="pd" style={{ width: 620, minHeight: 760, background: 'var(--content-bg)' }}><ProviderLabDiagnostics state="long" /></div> };
export const ProviderLabBothFailed = { render: () => frame(<ProviderLabDiagnostics state="failed" />) };