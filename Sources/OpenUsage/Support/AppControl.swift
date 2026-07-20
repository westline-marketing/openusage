import AppKit

/// Restarts the menu-bar app. Account changes only take effect at launch — the provider list is
/// built once at startup — so adding or removing an account relaunches the app to apply it.
@MainActor
enum AppControl {
    /// Marks the replacement instance of an intentional relaunch. The new copy necessarily starts
    /// while this one still holds the single-instance lock for a beat; the argument tells it to wait
    /// the lock out instead of declaring itself a duplicate — which would terminate BOTH copies and
    /// leave the app simply gone.
    static let relaunchHandoffArgument = "--relaunch-handoff"

    /// Launches a fresh instance, then terminates this one.
    static func restart() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = [relaunchHandoffArgument]
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in }
        // Best-effort handoff: give the new instance a moment to launch before this one exits. Not a
        // correctness guarantee — `terminate` synchronizes UserDefaults, so persisted account changes
        // are already on disk regardless of the timing here.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }
}
