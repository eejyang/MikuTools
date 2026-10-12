import Foundation

struct MonitorSnapshot: Codable, Equatable {
    let date: Date
    let cpu: Double?
    let memory: Double?
    let disk: Double?
    let download: Double?
    let upload: Double?

    static var placeholder: MonitorSnapshot {
        MonitorSnapshot(date: Date(), cpu: 0.12, memory: 0.63, disk: 0.71,
                        download: 32_600_000, upload: 4_210_000)
    }

    static let unavailable = MonitorSnapshot(date: .distantPast, cpu: nil, memory: nil,
                                              disk: nil, download: nil, upload: nil)

    static func formattedRate(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite else { return "--" }
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = max(0, bytesPerSecond)
        var unit = 0
        while value >= 1_000, unit < units.count - 1 {
            value /= 1_000
            unit += 1
        }
        let digits = unit == 0 || value >= 100 ? 0 : (value >= 10 ? 1 : 2)
        return String(format: "%.*f %@", locale: Locale(identifier: "en_US_POSIX"), digits, value, units[unit])
    }
}

enum SharedMonitorStore {
    static let appGroupIdentifier = "group.local.mikutools.monitor"
    static let widgetKind = "MacToolsSystemMonitor"
    private static let snapshotKey = "latestMonitorSnapshot"
    private static let defaults = UserDefaults(suiteName: appGroupIdentifier)

    static func read() -> MonitorSnapshot? {
        guard let data = defaults?.data(forKey: snapshotKey) else { return nil }
        return try? PropertyListDecoder().decode(MonitorSnapshot.self, from: data)
    }

    static func save(_ snapshot: MonitorSnapshot) {
        guard let data = try? PropertyListEncoder().encode(snapshot) else { return }
        // One value keeps the timestamp and all five metrics consistent across processes.
        defaults?.set(data, forKey: snapshotKey)
    }

    static func flush() {
        // Only flush explicitly at shutdown to retain the final sample on exit.
        defaults?.synchronize()
    }
}
