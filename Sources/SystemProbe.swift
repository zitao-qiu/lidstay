import Foundation
import IOKit
import IOKit.ps
import ServiceManagement

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

    static func lidClosed() -> Bool { boolProp("AppleClamshellState") }

    static func sleepDisabled() -> Bool { boolProp("SleepDisabled") }

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

    // disablesleep is undocumented and the only thing that overrides lid-close sleep; caffeinate and IOKit assertions cannot.
    @discardableResult
    static func setSleepDisabled(_ on: Bool) -> Bool {
        run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", on ? "1" : "0"])
    }

    static func notify(_ title: String, _ body: String) {
        let script = "display notification \"\(body)\" with title \"\(title)\" sound name \"Tink\""
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }

    static func canToggleSleepDisabled() -> Bool {
        run("/usr/bin/sudo", ["-n", "-l", "/usr/bin/pmset", "-a", "disablesleep", "0"])
    }

    static var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func setLaunchAtLogin(_ on: Bool) -> Bool {
        let status = SMAppService.mainApp.status
        do {
            if on, status != .enabled { try SMAppService.mainApp.register() }
            if !on, status == .enabled { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }
}

final class LoginItem: ObservableObject {
    static let shared = LoginItem()

    @Published private(set) var isOn = Sys.launchAtLogin
    @Published private(set) var failed = false

    func set(_ on: Bool) {
        let ok = Sys.setLaunchAtLogin(on)
        isOn = Sys.launchAtLogin
        failed = !ok
    }
}
