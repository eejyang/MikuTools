import Foundation

enum DiskReader {
    static func read() -> Double? {
        // The root volume's available space accounts for its APFS container.
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        guard let values = try? root.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
              let total = values.volumeTotalCapacity, total > 0,
              let available = values.volumeAvailableCapacity else { return nil }
        let used = max(0, total - available)
        return min(1, Double(used) / Double(total))
    }
}
