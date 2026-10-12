import AppKit
import WidgetKit

@main
struct MacToolsApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = SystemMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        WidgetCenter.shared.reloadTimelines(ofKind: SharedMonitorStore.widgetKind)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  components.scheme == "mac-tools" else { continue }
            if components.host == "refresh-monitor" {
                monitor.requestWidgetRefresh()
                continue
            }
            let paths = (components.queryItems ?? []).filter { $0.name == "path" }
                .compactMap(\.value).filter { $0.hasPrefix("/") }
            guard !paths.isEmpty else { continue }
            if components.host == "open-vscode" {
                openInVSCode(paths: paths)
            } else if components.host == "open-iterm" {
                for path in paths { ITermLauncher.open(path: path) }
            }
        }
    }

    private func openInVSCode(paths: [String]) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") else {
            showError("没有找到 vscode，请先安装。")
            return
        }
        let urls = paths.map { URL(fileURLWithPath: $0) }
        // Open the whole selection in one request, without the `code` CLI.
        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                DispatchQueue.main.async { self.showError("无法使用 vscode 打开：\(error.localizedDescription)") }
            }
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "MikuTools"
        alert.informativeText = message
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
