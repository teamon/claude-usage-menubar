import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let usageAPI = UsageAPI()
    private let usageMenu = UsageMenu()
    private var refreshTimer: Timer?

    private static let refreshInterval: TimeInterval = 300 // 5 minutes

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = usageMenu.nsMenu

        // Set initial placeholder icon
        if let button = statusItem.button {
            button.image = MenuBarRenderer.renderError()
        }

        usageMenu.onRefresh = { [weak self] in
            self?.refresh()
        }

        // Initial fetch
        refresh()

        // Schedule periodic refresh
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    private func refresh() {
        Task {
            do {
                let usage = try await usageAPI.fetchUsage()
                await MainActor.run {
                    if let button = statusItem.button {
                        button.image = MenuBarRenderer.render(usage: usage)
                    }
                    usageMenu.update(with: usage)
                }
            } catch {
                await MainActor.run {
                    if let button = statusItem.button {
                        button.image = MenuBarRenderer.renderError()
                    }
                    let message: String
                    switch error {
                    case UsageAPIError.noCredentials:
                        message = "Not logged in — run: claude login"
                    case UsageAPIError.tokenExpired:
                        message = "Token expired — run: claude login"
                    case UsageAPIError.refreshFailed(let detail):
                        message = "Refresh failed: \(detail)"
                    case UsageAPIError.fetchFailed(let detail):
                        message = "Fetch failed: \(detail)"
                    default:
                        message = "Error: \(error.localizedDescription)"
                    }
                    usageMenu.showError(message)
                }
            }
        }
    }
}
