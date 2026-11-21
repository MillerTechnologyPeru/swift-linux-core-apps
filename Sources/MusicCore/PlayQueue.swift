//
//  PlayQueue.swift
//  CoreApps
//

/// What happens when the queue's last track ends.
public enum RepeatMode: String, CaseIterable, Hashable, Sendable {
    /// Playing stops.
    case off
    /// The queue starts again.
    case all
    /// The same track plays again.
    case one

    /// The mode a tap on the repeat button moves to.
    public var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}

/// The tracks lined up to play, and which is playing.
public struct PlayQueue<Element: Hashable & Sendable>: Equatable, Sendable {

    /// The tracks in the order they were lined up.
    public private(set) var items: [Element]

    /// The order they play in: positions in `items`, mixed when shuffling.
    public private(set) var order: [Int]

    /// The position in `order` of the one playing; `nil` when none is.
    public private(set) var position: Int?

    public private(set) var isShuffled = false

    public var repeatMode = RepeatMode.off

    public init(_ items: [Element] = []) {
        self.items = items
        self.order = Array(items.indices)
        self.position = nil
    }

    public var current: Element? {
        position.flatMap { order.indices.contains($0) ? items[order[$0]] : nil }
    }

    public var isEmpty: Bool { items.isEmpty }

    /// The tracks still to play after the current one, in order.
    public var upcoming: [Element] {
        guard let position else { return order.map { items[$0] } }
        return order.dropFirst(position + 1).map { items[$0] }
    }

    /// Whether there is a track after the current one, counting a queue
    /// that repeats as never running out.
    public var hasNext: Bool {
        guard let position else { return !items.isEmpty }
        return position + 1 < order.count || (repeatMode == .all && !items.isEmpty)
    }

    public var hasPrevious: Bool {
        guard let position else { return false }
        return position > 0 || (repeatMode == .all && !items.isEmpty)
    }

    /// Lines up tracks and starts at one of them.
    public mutating func play(_ items: [Element], startingAt item: Element? = nil, using generator: inout some RandomNumberGenerator) {
        self.items = items
        order = Array(items.indices)
        let start = item.flatMap { items.firstIndex(of: $0) } ?? 0
        position = items.isEmpty ? nil : start
        if isShuffled {
            isShuffled = false
            setShuffled(true, using: &generator)
        }
    }

    public mutating func play(_ items: [Element], startingAt item: Element? = nil) {
        var generator = SystemRandomNumberGenerator()
        play(items, startingAt: item, using: &generator)
    }

    /// Mixes the order, or puts it back. The track playing keeps playing:
    /// mixed, it comes first and the rest follow it.
    public mutating func setShuffled(_ shuffled: Bool, using generator: inout some RandomNumberGenerator) {
        guard shuffled != isShuffled else { return }
        let playing = position.map { order[$0] }
        isShuffled = shuffled
        if shuffled {
            var rest = Array(items.indices).filter { $0 != playing }
            rest.shuffle(using: &generator)
            order = (playing.map { [$0] } ?? []) + rest
            position = playing == nil ? nil : 0
        } else {
            order = Array(items.indices)
            position = playing
        }
    }

    public mutating func setShuffled(_ shuffled: Bool) {
        var generator = SystemRandomNumberGenerator()
        setShuffled(shuffled, using: &generator)
    }

    /// Goes to the next track because the user asked. A queue that isn't
    /// repeating stays on its last track.
    ///
    /// - Returns: Whether the track changed.
    @discardableResult
    public mutating func next() -> Bool {
        guard let position, !items.isEmpty else { return false }
        if position + 1 < order.count {
            self.position = position + 1
            return true
        }
        guard repeatMode == .all else { return false }
        self.position = 0
        return true
    }

    /// Goes to the track before. Past the first few seconds of a track,
    /// the same track starts again instead, as players have it.
    ///
    /// - Parameter elapsed: How far into the track playing has got.
    /// - Returns: Whether the track changed, rather than starting again.
    @discardableResult
    public mutating func previous(elapsed: Double = 0) -> Bool {
        guard let position, !items.isEmpty, elapsed <= 3 else { return false }
        if position > 0 {
            self.position = position - 1
            return true
        }
        guard repeatMode == .all else { return false }
        self.position = order.count - 1
        return true
    }

    /// The track playing came to its end.
    ///
    /// - Returns: The track to play now, or `nil` if playing stops.
    public mutating func finished() -> Element? {
        guard let position else { return nil }
        switch repeatMode {
        case .one:
            return current
        case .all:
            self.position = position + 1 < order.count ? position + 1 : 0
            return current
        case .off:
            guard position + 1 < order.count else { return nil }
            self.position = position + 1
            return current
        }
    }

    /// Jumps to a track in the queue.
    public mutating func jump(to item: Element) {
        guard let index = items.firstIndex(of: item), let place = order.firstIndex(of: index) else { return }
        position = place
    }
}
