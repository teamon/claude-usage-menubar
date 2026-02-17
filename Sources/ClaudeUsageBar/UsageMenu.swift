import AppKit
import ServiceManagement

final class UsageMenu {
    private let menu = NSMenu()
    private let fiveHourItem = NSMenuItem()
    private let sevenDayItem = NSMenuItem()
    private let launchAtLoginItem = NSMenuItem()

    var onRefresh: (() -> Void)?

    init() {
        buildMenu()
    }

    var nsMenu: NSMenu { menu }

    func update(with usage: UsageData) {
        fiveHourItem.title = formatWindowTitle("5h", usage.fiveHour)
        sevenDayItem.title = formatWindowTitle("7d", usage.sevenDay)

        fiveHourItem.isHidden = false
        sevenDayItem.isHidden = false
    }

    func showError(_ message: String) {
        fiveHourItem.title = message
        fiveHourItem.isHidden = false
        sevenDayItem.isHidden = true
    }

    // MARK: - Menu Construction

    private func buildMenu() {
        fiveHourItem.isEnabled = false
        fiveHourItem.title = "Loading..."
        menu.addItem(fiveHourItem)

        sevenDayItem.isEnabled = false
        sevenDayItem.isHidden = true
        menu.addItem(sevenDayItem)

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshClicked(_:)), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let openSettingsItem = NSMenuItem(title: "Open Usage Settings...", action: #selector(openSettings(_:)), keyEquivalent: "")
        openSettingsItem.target = self
        menu.addItem(openSettingsItem)

        menu.addItem(.separator())

        launchAtLoginItem.title = "Launch at Login"
        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin(_:))
        launchAtLoginItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func refreshClicked(_ sender: Any?) {
        onRefresh?()
    }

    @objc private func openSettings(_ sender: Any?) {
        if let url = URL(string: "https://claude.ai/settings/usage") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: Any?) {
        let newState = !isLaunchAtLoginEnabled
        do {
            if newState {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail - the state check below will reflect actual state
        }
        launchAtLoginItem.state = isLaunchAtLoginEnabled ? .on : .off
    }

    private func formatWindowTitle(_ label: String, _ w: UsageData.Window) -> String {
        let usage = Int(w.utilization.rounded())
        let period = Int(w.timeElapsedPercent.rounded())
        return "\(label): \(usage)% used, \(period)% elapsed  (\(w.timeRemainingFormatted) left)"
    }

    private var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
