// LidGuard — keep a MacBook running with the lid closed, on demand.
//
// The problem this solves:
//   You have a long job running (a coding agent, a build, a download) and you
//   need to close the lid and put the machine in a bag. macOS sleeps on lid
//   close unless you have an external display + power + keyboard attached.
//   `caffeinate` cannot help: it holds an IOKit power assertion, and lid-close
//   sleep sits below the assertion system entirely.
//
// Why not just disable sleep all the time?
//   Because a MacBook that never sleeps in a bag cooks itself and drains flat.
//   The sane default is "lid close = sleep". You opt into the keep-awake mode
//   only for the one trip where you actually need it, and it ends by itself.
//
// How it works:
//   arm    -> `sudo -n pmset -a disablesleep 1`  + touch a state file
//   disarm -> `sudo -n pmset -a disablesleep 0`  + remove the state file
//   Lid state is polled from IOPMrootDomain's AppleClamshellState every 2 s.
//
// The state machine:
//
//            "Keep running when lid closes"
//   idle ──────────────────────────────────► armedOpen
//     ▲                                          │
//     │                                          │ lid closes
//     │                                          ▼
//     │                                     armedClosed
//     │                                          │
//     └──────────────────────────────────────────┘
//        lid opens / battery floor / manual cancel / quit
//
// Safety rails:
//   - Battery floor (default 15%): disarms on battery to avoid a dead machine
//     in a bag.
//   - Quitting the app disarms.
//   - `disablesleep` is a runtime flag: a reboot clears it.
//   - The state file records whether the lid has already been closed
//     (armed-open vs armed-closed) so an external watchdog can tell "user just
//     pressed the button" from "the app died after the lid closed".
//
// Requires a scoped sudoers rule — see scripts/install.sh.
//
// MIT License. https://github.com/<you>/lidguard

import SwiftUI
import AppKit
import IOKit
import IOKit.ps

// MARK: - System state

enum Sys {
    private static func rootDomain() -> io_service_t {
        IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    }

    private static func boolProp(_ key: String) -> Bool {
        let svc = rootDomain()
        guard svc != 0 else { return false }
        defer { IOObjectRelease(svc) }
        guard let v = IORegistryEntryCreateCFProperty(
            svc, key as CFString, kCFAllocatorDefault, 0) else { return false }
        return (v.takeRetainedValue() as? Bool) ?? false
    }

    /// Whether the lid is physically closed.
    static func lidClosed() -> Bool { boolProp("AppleClamshellState") }

    /// Whether the kernel's SleepDisabled flag is set.
    static func sleepDisabled() -> Bool { boolProp("SleepDisabled") }

    /// (battery percentage, is on AC power)
    static func battery() -> (percent: Int, onAC: Bool) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let ps = list.first,
              let desc = IOPSGetPowerSourceDescription(blob, ps)?
                  .takeUnretainedValue() as? [String: Any]
        else { return (100, true) }
        let pct = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
        let onAC = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        return (pct, onAC)
    }

    /// Flip the kernel SleepDisabled flag via the scoped passwordless sudo rule.
    @discardableResult
    static func setSleepDisabled(_ on: Bool) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        p.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", on ? "1" : "0"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch { return false }
    }

    static func notify(_ title: String, _ body: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e",
            "display notification \"\(body)\" with title \"\(title)\" sound name \"Tink\""]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }
}

// MARK: - State file

/// Shared with an optional external watchdog so it can tell whether a lid-open
/// should be trusted to mean "the session is over".
let stateDir = NSString(string: "~/.config/lidguard").expandingTildeInPath
let armedMarker = stateDir + "/armed"

func ensureStateDir() {
    try? FileManager.default.createDirectory(
        atPath: stateDir, withIntermediateDirectories: true)
}

func readMarker() -> String? {
    guard let raw = try? String(contentsOfFile: armedMarker, encoding: .utf8) else { return nil }
    return raw.trimmingCharacters(in: .whitespacesAndNewlines)
}

func writeMarker(_ value: String) {
    ensureStateDir()
    try? value.write(toFile: armedMarker, atomically: true, encoding: .utf8)
}

func clearMarker() {
    try? FileManager.default.removeItem(atPath: armedMarker)
}

// MARK: - State machine

enum GuardState {
    case idle          // lid close sleeps normally
    case armedOpen     // armed, waiting for the lid to close
    case armedClosed   // armed, lid is closed, job is running
}

final class Guard: ObservableObject {
    @Published var state: GuardState = .idle
    @Published var battery: Int = 100
    @Published var onAC: Bool = true
    @Published var floor: Int = 15

    private var timer: Timer?
    private let defaults = UserDefaults.standard

    init() {
        floor = defaults.object(forKey: "batteryFloor") as? Int ?? 15

        // Reconcile with reality: if the marker says armed but the kernel flag
        // is gone (a reboot clears it), do not pretend to be armed.
        if readMarker() != nil {
            if Sys.sleepDisabled() {
                state = Sys.lidClosed() ? .armedClosed : .armedOpen
            } else {
                clearMarker()
            }
        }

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    // MARK: Actions

    func arm() {
        guard Sys.setSleepDisabled(true) else {
            Sys.notify("Could not arm", "Missing sudoers rule — run scripts/install.sh")
            return
        }
        writeMarker(Sys.lidClosed() ? "armed-closed" : "armed-open")
        state = Sys.lidClosed() ? .armedClosed : .armedOpen
        Sys.notify("Armed", "Will keep running after the lid closes; disarms when you open it")
    }

    func disarm(reason: String = "") {
        _ = Sys.setSleepDisabled(false)
        clearMarker()
        state = .idle
        if !reason.isEmpty {
            Sys.notify("Lid sleep restored", reason)
        }
    }

    func setFloor(_ v: Int) {
        floor = v
        defaults.set(v, forKey: "batteryFloor")
    }

    func shutdown() {
        if state != .idle { disarm(reason: "LidGuard quit") }
    }

    // MARK: Polling

    private func refresh() {
        let (pct, ac) = Sys.battery()
        battery = pct
        onAC = ac
    }

    private func tick() {
        refresh()

        switch state {
        case .idle:
            break
        case .armedOpen:
            if Sys.lidClosed() {
                writeMarker("armed-closed")
                state = .armedClosed
            }
        case .armedClosed:
            if !Sys.lidClosed() {
                disarm(reason: "Lid opened")
                return
            }
        }

        // Battery floor: only meaningful off AC. Stops a machine left in a bag
        // from running itself flat.
        if state != .idle && !onAC && battery <= floor {
            disarm(reason: "Battery \(battery)% is at or below the \(floor)% floor")
        }
    }
}

// MARK: - UI

struct ContentView: View {
    @ObservedObject var g: Guard

    private var stateText: String {
        switch g.state {
        case .idle:        return "Lid close = normal sleep"
        case .armedOpen:   return "Armed · waiting for the lid to close…"
        case .armedClosed: return "Running · restores sleep when the lid opens"
        }
    }

    var body: some View {
        Group {
            Text(stateText)
            Text("Battery \(g.battery)% · \(g.onAC ? "AC power" : "on battery")")

            Divider()

            if g.state == .idle {
                Button("⚡ Keep running when lid closes") { g.arm() }
                Text("For: a job that must survive being carried away")
            } else {
                Button("Cancel — restore lid sleep now") { g.disarm(reason: "Cancelled") }
            }

            Divider()

            Menu("Battery floor: \(g.floor)%") {
                ForEach([10, 15, 20, 25, 30], id: \.self) { v in
                    Button("\(v)%") { g.setFloor(v) }
                }
            }
            Text("Auto-disarms at or below this level")

            Divider()

            Button("Quit LidGuard") {
                g.shutdown()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

@main
struct LidGuardApp: App {
    @StateObject private var guardState = Guard()

    init() {
        // Headless CLI modes, useful for scripting and for debugging.
        let args = CommandLine.arguments
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

    var body: some Scene {
        MenuBarExtra {
            ContentView(g: guardState)
        } label: {
            Image(systemName: guardState.state == .idle
                  ? "laptopcomputer"
                  : "bolt.fill")
        }
        .menuBarExtraStyle(.menu)
    }
}
