import Darwin
import Foundation

enum MemoryReader {
    static func read() -> Double? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        var pageSize: vm_size_t = 0
        guard result == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }
        // Count physical compressed pages, not their uncompressed logical size.
        // Exclude reclaimable file-backed and purgeable pages from used memory.
        let occupied = UInt64(info.active_count) + UInt64(info.inactive_count)
            + UInt64(info.wire_count) + UInt64(info.compressor_page_count)
        let reclaimable = UInt64(info.external_page_count) + UInt64(info.purgeable_count)
        let used = occupied > reclaimable ? occupied - reclaimable : 0
        let total = ProcessInfo.processInfo.physicalMemory
        guard total > 0 else { return nil }
        return min(1, Double(used) * Double(pageSize) / Double(total))
    }
}
