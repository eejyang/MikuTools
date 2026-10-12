import SwiftUI
import WidgetKit

struct MonitorEntry: TimelineEntry {
    let date: Date
    let monitor: MonitorSnapshot
}

struct MonitorProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonitorEntry {
        MonitorEntry(date: Date(), monitor: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MonitorEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonitorEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> MonitorEntry {
        MonitorEntry(date: Date(), monitor: SharedMonitorStore.read() ?? .unavailable)
    }
}

@main
struct MonitorWidget: Widget {
    let kind = SharedMonitorStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonitorProvider()) { entry in
            MonitorView(monitor: entry.monitor)
                .containerBackground(for: .widget) { Color(white: 0.10) }
                .widgetURL(URL(string: "mac-tools://refresh-monitor"))
        }
        .configurationDisplayName("系统监控")
        .description("主 App 每秒采样，每 2 秒请求刷新；实际刷新由系统调度。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}
