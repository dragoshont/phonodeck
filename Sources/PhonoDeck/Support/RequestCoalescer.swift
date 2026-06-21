import Foundation

actor RequestCoalescer<Key: Hashable & Sendable> {
    private var activeKeys = Set<Key>()

    func begin(_ key: Key) -> Bool {
        activeKeys.insert(key).inserted
    }

    func end(_ key: Key) {
        activeKeys.remove(key)
    }
}