import OSLog

enum AppLog {
    private static let subsystem = "ro.hont.phonodeck"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let cache = Logger(subsystem: subsystem, category: "cache")
    static let playback = Logger(subsystem: subsystem, category: "playback")
    static let player = Logger(subsystem: subsystem, category: "player")
    static let playlist = Logger(subsystem: subsystem, category: "playlist")
    static let search = Logger(subsystem: subsystem, category: "search")
}