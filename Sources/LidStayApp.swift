import AppKit
import SwiftUI

extension Notification.Name {
    static let lidStayOpenSettings = Notification.Name("lidStayOpenSettings")
}

@MainActor
enum SettingsOpener {
    static var pending = false

    static func request() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .lidStayOpenSettings, object: nil)
        }
    }

    static func consumePending() -> Bool {
        defer { pending = false }
        return pending
    }

    static func present(_ open: @escaping () -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        open()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard let window = settingsWindow() else { return }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    private static func settingsWindow() -> NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue.contains("Settings") == true }
    }
}

@available(macOS 14.0, *)
struct ModernMenuBarLabel: View {
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var g: Guard

    var body: some View {
        Image(systemName: g.menuBarSymbol)
            .onAppear {
                if SettingsOpener.consumePending() {
                    SettingsOpener.present { openSettings() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .lidStayOpenSettings)) { _ in
                SettingsOpener.present { openSettings() }
            }
    }
}

struct LegacyMenuBarLabel: View {
    @ObservedObject var g: Guard

    var body: some View {
        Image(systemName: g.menuBarSymbol)
            .onAppear {
                if SettingsOpener.consumePending() {
                    SettingsOpener.present(showSettingsWindow)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .lidStayOpenSettings)) { _ in
                SettingsOpener.present(showSettingsWindow)
            }
    }

    private func showSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

enum CLI {
    @MainActor
    static func runIfNeeded() {
        let args = CommandLine.arguments
        if args.contains("--settings") { SettingsOpener.pending = true }

        if args.contains("--status") {
            let (pct, ac) = Sys.battery()
            print("lid            : \(Sys.lidClosed() ? "closed" : "open")")
            print("sleepDisabled  : \(Sys.sleepDisabled())")
            print("battery        : \(pct)% \(ac ? "(AC)" : "(battery)")")
            print("marker         : \(readMarker() ?? "(none)")")
            exit(0)
        }
        if args.contains("--arm") {
            let ok = Sys.setSleepDisabled(true)
            if ok {
                writeMarker(Sys.lidClosed() ? "armed-closed" : "armed-open")
            }
            print(ok ? "armed" : "FAILED (sudoers rule missing?)")
            exit(ok ? 0 : 1)
        }
        if args.contains("--disarm") {
            let ok = Sys.setSleepDisabled(false)
            clearMarker()
            print(ok ? "disarmed" : "FAILED")
            exit(ok ? 0 : 1)
        }
    }
}

@main
struct LidStayApp: App {
    @StateObject private var guardState = Guard()
    @StateObject private var l10n = L10n.shared
    @StateObject private var loginItem = LoginItem.shared

    init() {
        CLI.runIfNeeded()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(g: guardState, l10n: l10n)
        } label: {
            if #available(macOS 14.0, *) {
                ModernMenuBarLabel(g: guardState)
            } else {
                LegacyMenuBarLabel(g: guardState)
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(g: guardState, l10n: l10n, login: loginItem)
        }
    }
}
