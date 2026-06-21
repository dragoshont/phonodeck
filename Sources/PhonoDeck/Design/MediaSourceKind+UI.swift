import SwiftUI

// UI-only extensions for the source model. The portable capability/tier core
// (Integrations/Core) never imports SwiftUI; colors live here.

extension MediaSourceKind {
    /// Brand tint for badges and discrete source markers.
    var tint: Color {
        switch self {
        case .youtube: .red
        case .plex: .orange
        case .youtubeMusic: .pink
        case .spotify: .green
        case .ownFiles: .blue
        }
    }
}

extension MusicSourceCapabilityStatus {
    /// Tint for a capability chip/dot. `unavailable` uses a neutral secondary
    /// tone (not red) so a missing capability never reads as an error.
    var uiColor: Color {
        switch self {
        case .active: .green
        case .limited: .orange
        case .planned: .secondary
        case .unavailable: .secondary
        }
    }
}
