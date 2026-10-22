import Foundation
import Observation
import PeriodicalCore

/// Saved timeblocks, persisted as JSON in Application Support.
@Observable
final class BlockStore {
    private(set) var blocks: [TimeBlock] = []
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Periodical", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("timeblocks.json")
    }()

    init() {
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([TimeBlock].self, from: data) {
            blocks = saved
        }
    }

    func add(_ block: TimeBlock) {
        blocks.append(block)
        save()
    }

    func delete(_ block: TimeBlock) {
        blocks.removeAll { $0.id == block.id }
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(blocks) {
            try? data.write(to: url, options: .atomic)
        }
        onChange?()
    }
}

/// Publishes the current time once per second, on the second.
@Observable
final class Clock {
    private(set) var now = Date()
    @ObservationIgnored private var listeners: [() -> Void] = []

    init() {
        let nextSecond = Date(timeIntervalSinceReferenceDate: floor(Date().timeIntervalSinceReferenceDate) + 1)
        let timer = Timer(fire: nextSecond, interval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.05
        // .common keeps ticking while menus and scroll views are tracking.
        RunLoop.main.add(timer, forMode: .common)
    }

    func onTick(_ listener: @escaping () -> Void) {
        listeners.append(listener)
    }

    private func tick() {
        now = Date()
        listeners.forEach { $0() }
    }
}
