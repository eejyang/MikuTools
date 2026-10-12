import Darwin
import Foundation
import SystemConfiguration

final class NetworkReader {
    struct Sample {
        let interface: String
        let received: UInt32
        let sent: UInt32
        let time: TimeInterval
    }

    private let store = SCDynamicStoreCreate(nil, "mac-tools.monitor" as CFString, nil, nil)
    private var previous: Sample?

    func read() -> (download: Double, upload: Double)? {
        guard let current = sample() else {
            previous = nil
            return nil
        }
        defer { previous = current }
        guard let previous, previous.interface == current.interface else { return (0, 0) }
        let elapsed = current.time - previous.time
        // Re-prime after sleep rather than showing an averaged or spurious rate.
        guard elapsed > 0, elapsed < 5 else { return (0, 0) }
        // getifaddrs exposes 32-bit counters on macOS. Wrapping subtraction
        // handles rollover without a negative rate or a huge traffic spike.
        return (Double(current.received &- previous.received) / elapsed,
                Double(current.sent &- previous.sent) / elapsed)
    }

    private func primaryInterface() -> String? {
        guard let store else { return nil }
        for family in ["IPv4", "IPv6"] {
            let key = "State:/Network/Global/\(family)" as CFString
            if let state = SCDynamicStoreCopyValue(store, key) as? [String: Any],
               let interface = state[kSCDynamicStorePropNetPrimaryInterface as String] as? String {
                return interface
            }
        }
        return nil
    }

    private func sample() -> Sample? {
        guard let primary = primaryInterface() else { return nil }
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(first) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let pointer = cursor {
            let address = pointer.pointee
            cursor = address.ifa_next
            guard String(cString: address.ifa_name) == primary,
                  address.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                  address.ifa_flags & UInt32(IFF_UP) != 0,
                  address.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
                  let data = address.ifa_data else { continue }
            let statistics = data.assumingMemoryBound(to: if_data.self).pointee
            return Sample(interface: primary, received: statistics.ifi_ibytes,
                          sent: statistics.ifi_obytes, time: ProcessInfo.processInfo.systemUptime)
        }
        return nil
    }

}
