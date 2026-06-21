import Foundation

struct DeviceRoutingCapability: Identifiable, Equatable {
    let id: String
    let symbol: String
    let title: String
    let status: String
    let detail: String
    let color: ColorName
}

protocol DeviceRoutingCapabilityProviding {
    func capabilities() -> [DeviceRoutingCapability]
}

struct StaticDeviceRoutingCapabilityProvider: DeviceRoutingCapabilityProviding {
    func capabilities() -> [DeviceRoutingCapability] {
        [
            .init(
                id: "youtube-player-route",
                symbol: "play.rectangle",
                title: "YouTube Playback Route",
                status: "Visible Player",
                detail: "The embedded YouTube player owns output selection. PhonoDeck can control play/pause/queue, but cannot force YouTube audio to a HomePod or Cast target through the public IFrame API.",
                color: .orange
            ),
            .init(
                id: "native-routes",
                symbol: "airplayaudio",
                title: "Native Music Routes",
                status: "System Picker",
                detail: "For Plex, Own Files, and future Apple Music playback, the system AirPlay picker is the right route surface. It can show HomePods, but Apple does not provide a public API to enumerate every route silently.",
                color: .blue
            ),
            .init(
                id: "home-service",
                symbol: "house",
                title: "Home App / HomePod Music Service",
                status: "Not Exposed",
                detail: "HomeKit can access home accessories with user permission, but it does not expose whether HomePod is configured to use YouTube Music as its default service.",
                color: .secondary
            ),
            .init(
                id: "cross-device-history",
                symbol: "iphone.gen3",
                title: "Cross-device History",
                status: "Limited",
                detail: "YouTube account APIs can expose some account activity, but not a full watch/listen history with device names such as iPhone, Tesla, TV, or speaker. Apple Music recently played is available only for Apple Music after MusicKit authorization.",
                color: .orange
            ),
            .init(
                id: "youtube-subscription-tier",
                symbol: "person.2.badge.gearshape",
                title: "YouTube Subscription Tier",
                status: "Not Exposed",
                detail: "Public YouTube APIs do not reveal Free, Premium, Student, Individual, or Family plan status. PhonoDeck can store a user-entered note later, but should not claim it from the API.",
                color: .secondary
            )
        ]
    }
}