import AppKit
import FinderSync

final class FinderSync: FIFinderSync {
    private var lastMenuKind = FIMenuKind.contextualMenuForItems
    private var menuURLs: [URL] = []
    private var applicationIcons: [String: NSImage] = [:]
    private var iconsLoaded = false

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
        preloadApplicationIcons()
    }

    private func preloadApplicationIcons() {
        // Finder waits for menu(for:) to return. Launch Services and Icon
        // Services must run outside that callback, including lazy image drawing.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let workspace = NSWorkspace.shared
            var icons: [String: NSImage] = [:]
            for bundleID in ["com.microsoft.VSCode", "com.googlecode.iterm2"] {
                guard let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) else { continue }
                icons[bundleID] = Self.menuIcon(workspace.icon(forFile: appURL.path))
            }
            DispatchQueue.main.async { [weak self] in
                self?.applicationIcons = icons
                self?.iconsLoaded = true
            }
        }
    }

    private static func menuIcon(_ source: NSImage) -> NSImage {
        // Cache a rendered 16 pt / 2x icon so sending the menu to Finder
        // doesn't defer icon-service work until the user right-clicks.
        let size = NSSize(width: 16, height: 16)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32,
                                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                           isPlanar: false, colorSpaceName: .deviceRGB,
                                           bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            source.size = size
            return source
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        source.draw(in: NSRect(x: 0, y: 0, width: 32, height: 32),
                    from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        bitmap.size = size
        let icon = NSImage(size: size)
        icon.addRepresentation(bitmap)
        return icon
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind != .toolbarItemMenu else { return nil }
        lastMenuKind = menuKind
        let controller = FIFinderSyncController.default()
        let urls: [URL]
        if menuKind == .contextualMenuForItems,
           let selected = controller.selectedItemURLs(), !selected.isEmpty {
            urls = selected
        } else if let target = controller.targetedURL() {
            // Background and sidebar menus must not reuse an unrelated selection.
            urls = [target]
        } else {
            return nil
        }
        menuURLs = urls

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(makeItem("在 vscode 中打开", bundleID: "com.microsoft.VSCode",
                              action: #selector(openInVSCode(_:))))
        menu.addItem(makeItem("在 iTerm2 中打开", bundleID: "com.googlecode.iterm2",
                              action: #selector(openInITerm(_:))))
        return menu
    }

    private func makeItem(_ title: String, bundleID: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = applicationIcons[bundleID]
        // While the initial background load is pending, keep the actions usable.
        // The containing app handles a missing application when opening it.
        item.isEnabled = !iconsLoaded || item.image != nil
        return item
    }

    private func actionURLs() -> [URL] {
        // Finder copies menu items across processes. representedObject isn't
        // preserved, so ask Finder for the live selection in the action itself.
        let controller = FIFinderSyncController.default()
        if lastMenuKind == .contextualMenuForItems,
           let selected = controller.selectedItemURLs(), !selected.isEmpty {
            return selected
        }
        if let target = controller.targetedURL() { return [target] }
        return menuURLs
    }

    @objc private func openInVSCode(_ sender: NSMenuItem) {
        sendToApp(action: "open-vscode", urls: actionURLs())
    }

    @objc private func openInITerm(_ sender: NSMenuItem) {
        sendToApp(action: "open-iterm", urls: actionURLs())
    }

    private func sendToApp(action: String, urls: [URL]) {
        // Finder doesn't grant its extension access to all selected files.
        // Pass paths as URL data; the unsandboxed containing app opens them.
        let paths = urls.filter(\.isFileURL).map(\.path)
        guard !paths.isEmpty else { return }
        var components = URLComponents()
        components.scheme = "mac-tools"
        components.host = action
        components.queryItems = paths.map { URLQueryItem(name: "path", value: $0) }
        guard let request = components.url else { return }
        // Target the containing app explicitly so the URL handler works even
        // when this build has not yet been registered with Launch Services.
        let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open([request], withApplicationAt: appURL, configuration: configuration) { _, error in
            if let error { self.showError("无法将打开请求交给 MikuTools", error: error) }
        }
    }

    private func showError(_ message: String, error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
