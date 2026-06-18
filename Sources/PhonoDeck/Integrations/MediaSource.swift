import Foundation
import SwiftUI

enum MediaSourceKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case plex
    case youtubeMusic
    case spotify
    case localFiles

    var id: String { rawValue }

    var descriptor: MediaSourceDescriptor {
        switch self {
        case .plex:
            MediaSourceDescriptor(id: self, displayName: "Plex", symbolName: "rectangle.stack.badge.play", nativeRole: "Primary native playback, library, and download source")
        case .youtubeMusic:
            MediaSourceDescriptor(id: self, displayName: "YouTube Music", symbolName: "play.rectangle", nativeRole: "Discovery and policy-compliant embedded playback")
        case .spotify:
            MediaSourceDescriptor(id: self, displayName: "Spotify", symbolName: "dot.radiowaves.left.and.right", nativeRole: "Metadata, library surfaces, and Spotify Connect control")
        case .localFiles:
            MediaSourceDescriptor(id: self, displayName: "Local", symbolName: "externaldrive", nativeRole: "User-owned files, imports, and iTunes XML compatibility")
        }
    }

    var tint: Color {
        switch self {
        case .plex: .orange
        case .youtubeMusic: .red
        case .spotify: .green
        case .localFiles: .blue
        }
    }
}

struct MediaSourceDescriptor: Identifiable, Equatable {
    let id: MediaSourceKind
    let displayName: String
    let symbolName: String
    let nativeRole: String
}

protocol MediaSource {
    var descriptor: MediaSourceDescriptor { get }

    func search(query: String) async throws -> [MediaItem]
    func librarySnapshot() async throws -> [MediaItem]
}

struct MediaItem: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let source: MediaSourceKind
    let playbackPolicy: PlaybackPolicy
}

enum PlaybackPolicy: Equatable {
    case nativeStream
    case embeddedPlayer
    case externalRemoteControl
    case localFile
    case unavailable(reason: String)
}

enum MediaSourceError: Error, Equatable {
    case notConfigured
    case notImplemented
    case unsupportedByPolicy(String)
}
