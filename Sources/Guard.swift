import Foundation

let stateDir = NSString(string: "~/.config/lidstay").expandingTildeInPath
let armedMarker = stateDir + "/armed"

func ensureStateDir() {
    try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)
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

enum GuardState {
    case idle
    case armedOpen
    case armedClosed
}

enum DisarmReason {
    case lidOpened, cancelled, quit
    case batteryFloor(percent: Int, floor: Int)
}

final class Guard: ObservableObject {
    @Published private(set) var state: GuardState = .idle
    @Published private(set) var battery = 100
    @Published private(set) var onAC = true
    @Published private(set) var floor: Int

    private var timer: Timer?
    private let defaults = UserDefaults.standard

    init() {
        floor = defaults.object(forKey: "batteryFloor") as? Int ?? 15

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

    var menuBarSymbol: String { state == .idle ? "laptopcomputer" : "bolt.fill" }

    func arm() {
        guard Sys.setSleepDisabled(true) else {
            Sys.notify(L10n.shared.t(.cannotArmTitle), L10n.shared.t(.cannotArmBody))
            return
        }
        // The marker records armed-open vs armed-closed so an external watchdog can tell "just armed" from "died with the lid closed".
        writeMarker(Sys.lidClosed() ? "armed-closed" : "armed-open")
        state = Sys.lidClosed() ? .armedClosed : .armedOpen
        Sys.notify(L10n.shared.t(.armedTitle), L10n.shared.t(.armedBody))
    }

    func disarm(reason: DisarmReason? = nil) {
        _ = Sys.setSleepDisabled(false)
        clearMarker()
        state = .idle
        if let reason {
            Sys.notify(L10n.shared.t(.restoredTitle), L10n.shared.disarmReason(reason))
        }
    }

    func setFloor(_ value: Int) {
        floor = value
        defaults.set(value, forKey: "batteryFloor")
    }

    func shutdown() {
        if state != .idle { disarm(reason: .quit) }
    }

    private func refresh() {
        let (percent, ac) = Sys.battery()
        battery = percent
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
                disarm(reason: .lidOpened)
                return
            }
        }

        // The battery floor only applies off AC: on power there is nothing to protect, so a plugged-in machine never disarms.
        if state != .idle, !onAC, battery <= floor {
            disarm(reason: .batteryFloor(percent: battery, floor: floor))
        }
    }
}
