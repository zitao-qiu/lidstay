import AppKit
import SwiftUI

struct MenuContent: View {
    @ObservedObject var g: Guard
    @ObservedObject var l10n: L10n

    private let floors = [10, 15, 20, 25, 30]

    var body: some View {
        Group {
            Text(l10n.statusLine(g.state))
            Text(l10n.batteryLine(g.battery, onAC: g.onAC))

            Divider()

            if g.state == .idle {
                Button {
                    g.arm()
                } label: {
                    Label(l10n.t(.keepRunning), systemImage: "bolt.fill")
                }
            } else {
                Button {
                    g.disarm(reason: .cancelled)
                } label: {
                    Label(l10n.t(.cancelKeepAwake), systemImage: "bolt.slash")
                }
            }

            Divider()

            Menu(l10n.batteryFloorTitle(g.floor)) {
                ForEach(floors, id: \.self) { value in
                    Button("\(value)%") { g.setFloor(value) }
                }
            }

            Button(l10n.t(.settings)) { SettingsOpener.request() }
                .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button(l10n.t(.quit)) {
                g.shutdown()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
