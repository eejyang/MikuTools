import Darwin
import Foundation

final class CPUReader {
    private var previous: [UInt32]?
    private var previousTime: TimeInterval?

    func read() -> Double? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            previous = nil
            previousTime = nil
            return nil
        }

        let ticks = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
        let now = ProcessInfo.processInfo.systemUptime
        defer {
            previous = ticks
            previousTime = now
        }
        guard let previous, let previousTime, now - previousTime < 5 else { return nil }
        // Mach's cumulative 32-bit tick counters can wrap on a long-running Mac.
        let delta = zip(ticks, previous).map { UInt64($0 &- $1) }
        let total = delta.reduce(0, +)
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - Double(delta[Int(CPU_STATE_IDLE)]) / Double(total)))
    }
}
