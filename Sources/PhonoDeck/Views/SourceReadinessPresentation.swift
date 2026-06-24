import SwiftUI

struct SourceReadinessPresentation: Equatable {
    enum Severity: Equatable {
        case ready
        case neutral
        case warning
        case blocked

        var color: Color {
            switch self {
            case .ready: .green
            case .neutral: .secondary
            case .warning: .orange
            case .blocked: .red
            }
        }
    }

    let title: String
    let detail: String
    let badge: String
    let symbolName: String
    let severity: Severity

    static func make(source: MediaSourceKind, status: SourceProviderStatus) -> SourceReadinessPresentation {
        switch status {
        case .ready:
            return .init(
                title: source.descriptor.displayName,
                detail: "\(source.descriptor.displayName) is ready.",
                badge: "Ready",
                symbolName: "checkmark.circle",
                severity: .ready
            )
        case .notConnected:
            return .init(
                title: source.descriptor.displayName,
                detail: "Connect \(source.descriptor.displayName) in Settings to use this surface.",
                badge: "Connect",
                symbolName: "person.crop.circle.badge.plus",
                severity: .neutral
            )
        case .notConfigured(let reason):
            return .init(title: source.descriptor.displayName, detail: reason, badge: "Setup needed", symbolName: "gearshape", severity: .warning)
        case .missingScope(let scope):
            return .init(
                title: source.descriptor.displayName,
                detail: "Reconnect \(source.descriptor.displayName) to grant \(scope).",
                badge: "Permission needed",
                symbolName: "person.crop.circle.badge.exclamationmark",
                severity: .warning
            )
        case .authorizationExpired:
            return .init(
                title: source.descriptor.displayName,
                detail: "\(source.descriptor.displayName) authorization expired.",
                badge: "Reconnect",
                symbolName: "person.crop.circle.badge.exclamationmark",
                severity: .warning
            )
        case .rateLimited:
            return .init(
                title: source.descriptor.displayName,
                detail: "Showing cached results where available. Try again later.",
                badge: "Rate limited",
                symbolName: "clock.badge.exclamationmark",
                severity: .warning
            )
        case .providerUnavailable(let reason):
            return .init(title: source.descriptor.displayName, detail: reason, badge: "Service issue", symbolName: "wifi.exclamationmark", severity: .warning)
        case .partial:
            return .init(
                title: source.descriptor.displayName,
                detail: "Some \(source.descriptor.displayName) data is unavailable; showing what is ready.",
                badge: "Partial",
                symbolName: "circle.lefthalf.filled",
                severity: .warning
            )
        case .policyBlocked(let reason):
            return .init(title: source.descriptor.displayName, detail: "Not available for this source: \(reason)", badge: "Unavailable", symbolName: "slash.circle", severity: .blocked)
        case .invalidProviderResponse:
            return .init(
                title: source.descriptor.displayName,
                detail: "Could not read \(source.descriptor.displayName)'s response. Retry or manage it in Settings.",
                badge: "Failed",
                symbolName: "exclamationmark.triangle",
                severity: .blocked
            )
        case .failed(let reason):
            return .init(title: source.descriptor.displayName, detail: "Couldn't load \(source.descriptor.displayName). \(reason)", badge: "Failed", symbolName: "exclamationmark.triangle", severity: .blocked)
        }
    }
}

struct ReadinessCallout: View {
    let source: MediaSourceKind
    let presentation: SourceReadinessPresentation

    init(source: MediaSourceKind, status: SourceProviderStatus) {
        self.source = source
        self.presentation = SourceReadinessPresentation.make(source: source, status: status)
    }

    init(source: MediaSourceKind, presentation: SourceReadinessPresentation) {
        self.source = source
        self.presentation = presentation
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.standardSpacing) {
            Image(systemName: presentation.symbolName)
                .font(.callout.weight(.semibold))
                .frame(width: 30, height: 30)
                .background(source.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .foregroundStyle(source.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                    .font(.callout.weight(.semibold))
                Text(presentation.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(presentation.badge)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(presentation.severity.color.opacity(0.14), in: Capsule())
                .foregroundStyle(presentation.severity.color)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.title): \(presentation.badge). \(presentation.detail)")
    }
}
