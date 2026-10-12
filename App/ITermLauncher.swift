import AppKit

enum ITermLauncher {
    static func open(path: String) {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") != nil else {
            showError("没有找到 iTerm2，请先安装 iTerm2。")
            return
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            showError("路径不存在：\(path)")
            return
        }
        let directory = isDirectory.boolValue ? path : URL(fileURLWithPath: path).deletingLastPathComponent().path
        let command = directoryCommand(directory)
        // Shell quoting and AppleScript string escaping are two separate layers.
        let literal = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application id "com.googlecode.iterm2"
            set newWindow to (create window with default profile)
            tell current session of newWindow
                write text "\(literal)"
            end tell
            activate
        end tell
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            showError("无法创建 iTerm2 AppleScript。")
            return
        }
        script.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? error.description
            showError("无法打开 iTerm2：\(message)\n\n若未授权，请在系统设置 → 隐私与安全性 → 自动化中允许 MikuTools 控制 iTerm2。")
        }
    }

    static func directoryCommand(_ path: String) -> String {
        // Keep ordinary paths readable. Single quotes protect $, backticks, spaces,
        // Unicode and shell metacharacters; an embedded quote closes/reopens them.
        if !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            return "cd -- '" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        // Never send literal control characters to a terminal. The sentinel also
        // preserves trailing newlines, which command substitution normally drops.
        let encoded = Data(path.utf8).base64EncodedString()
        return "mac_tools_directory=\"$(/usr/bin/printf '%s' '\(encoded)' | /usr/bin/base64 -D; /usr/bin/printf '.')\"; cd -- \"${mac_tools_directory%.}\"; unset mac_tools_directory"
    }

    private static func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "MikuTools"
        alert.informativeText = message
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
