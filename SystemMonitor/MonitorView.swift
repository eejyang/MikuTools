import SwiftUI
import WidgetKit

struct MonitorView: View {
    @Environment(\.widgetFamily) private var family
    let monitor: MonitorSnapshot

    private var compact: Bool { family == .systemSmall }

    var body: some View {
        VStack(spacing: compact ? 12 : 0) {
            if compact {
                HStack(spacing: 0) {
                    gauge(value: monitor.cpu, label: "CPU")
                    gauge(value: monitor.memory, label: "RAM")
                }
                .frame(maxHeight: .infinity)
                HStack(spacing: 0) {
                    gauge(value: monitor.disk, label: "DISK")
                    network
                }
                .frame(maxHeight: .infinity)
            } else {
                HStack(alignment: .bottom, spacing: 0) {
                    gauge(value: monitor.cpu, label: "CPU")
                    gauge(value: monitor.memory, label: "RAM")
                    gauge(value: monitor.disk, label: "DISK")
                    network
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 12 : 18)
        .padding(.vertical, compact ? 12 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var network: some View {
        VStack(spacing: compact ? 6 : 8) {
            VStack(alignment: .leading, spacing: compact ? 4 : 5) {
                rate("↓", value: monitor.download, title: "下载速度")
                rate("↑", value: monitor.upload, title: "上传速度")
            }
            .font(.system(size: compact ? 9.5 : 10, weight: .medium))
            // Match the gauge area so all four labels share a baseline.
            .frame(height: compact ? 28 : 40)
            label("NET")
        }
        .frame(maxWidth: .infinity)
    }

    private func gauge(value: Double?, label title: String) -> some View {
        VStack(spacing: compact ? 6 : 8) {
            ZStack(alignment: .bottom) {
                Arc().stroke(Color(white: 0.42), style: StrokeStyle(lineWidth: compact ? 4 : 5, lineCap: .round))
                Arc().trim(from: 0, to: min(1, max(0, value ?? 0)))
                    .stroke(.white, style: StrokeStyle(lineWidth: compact ? 4 : 5, lineCap: .round))
                Text(value.map { "\(Int(($0 * 100).rounded()))%" } ?? "--")
                    .font(.system(size: compact ? 14 : 18, weight: .medium))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: (value ?? 0) * 100))
                    .animation(.easeInOut(duration: 0.25), value: value)
                    .offset(y: 2)
            }
            .frame(width: compact ? 48 : 70, height: compact ? 28 : 40)
            label(title)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value.map { "\(Int(($0 * 100).rounded()))%" } ?? "暂无数据")
    }

    private func rate(_ arrow: String, value: Double?, title: String) -> some View {
        Text(arrow + " " + MonitorSnapshot.formattedRate(value))
            .monospacedDigit()
            .contentTransition(.numericText(value: value ?? 0))
            .animation(.easeInOut(duration: 0.25), value: value)
            .accessibilityLabel(title)
            .accessibilityValue(MonitorSnapshot.formattedRate(value))
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color(white: 0.65))
    }
}

private struct Arc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width / 2, rect.height)
        path.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: radius,
                    startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        return path
    }
}
