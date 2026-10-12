import Foundation
import WidgetKit

final class SystemMonitor {
    private let queue = DispatchQueue(label: "MikuTools.monitor", qos: .utility)
    private let cpuReader = CPUReader()
    private let networkReader = NetworkReader()
    private var timer: DispatchSourceTimer?
    private var activity: NSObjectProtocol?
    private var disk: Double?
    private var lastDiskRead: TimeInterval = -.infinity
    private var ticks = 0
    private let reloadWidget: () -> Void

    init(reloadWidget: @escaping () -> Void = {
        WidgetCenter.shared.reloadTimelines(ofKind: SharedMonitorStore.widgetKind)
    }) {
        self.reloadWidget = reloadWidget
    }

    func start() {
        guard timer == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                                                        reason: "采集系统监控数据")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in self?.sample() }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        queue.sync { SharedMonitorStore.flush() }
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    func requestWidgetRefresh() {
        queue.async { self.reloadWidget() }
    }

    private func sample() {
        let cpu = cpuReader.read()
        let memory = MemoryReader.read()
        let rates = networkReader.read()
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastDiskRead >= 15 {
            disk = DiskReader.read()
            lastDiskRead = now
        }
        SharedMonitorStore.save(MonitorSnapshot(date: Date(), cpu: cpu, memory: memory, disk: disk,
                                              download: rates?.download, upload: rates?.upload))
        // The same serial timer writes the latest sample before requesting a reload.
        // Calls are requests only; WidgetKit can throttle their actual rendering.
        if ticks % 2 == 0 {
            reloadWidget()
        }
        ticks += 1
    }
}
