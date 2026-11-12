import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english, chinese

    var id: String { rawValue }
}

enum Str {
    case idleStatus, armedOpenStatus, armedClosedStatus
    case battery, acPower, onBattery
    case keepRunning, cancelKeepAwake, batteryFloor, settings, quit
    case general, permission, language, about
    case launchAtLogin, ready, permissionMissing, copy, copied
    case systemLanguage, appTitle, repoURL, loginUnavailable
    case cannotArmTitle, cannotArmBody, armedTitle, armedBody, restoredTitle
    case reasonLidOpened, reasonCancelled, reasonQuit

    private var pair: (en: String, zh: String) {
        switch self {
        case .idleStatus: ("Idle · sleep on lid close", "空闲 · 合盖后睡眠")
        case .armedOpenStatus: ("Armed · waiting for the lid", "已就绪 · 等待合盖")
        case .armedClosedStatus: ("Running · lid closed", "运行中 · 已合盖")
        case .battery: ("Battery", "电池")
        case .acPower: ("AC power", "电源适配器")
        case .onBattery: ("on battery", "电池供电")
        case .keepRunning: ("Keep running when lid closes", "合盖后保持运行")
        case .cancelKeepAwake: ("Cancel keep-awake", "取消保持运行")
        case .batteryFloor: ("Battery floor", "电池下限")
        case .settings: ("Settings…", "设置…")
        case .quit: ("Quit LidStay", "退出 LidStay")
        case .general: ("General", "通用")
        case .permission: ("Permission", "权限")
        case .language: ("Language", "语言")
        case .about: ("About", "关于")
        case .launchAtLogin: ("Launch at login", "开机时启动")
        case .ready: ("Ready", "已就绪")
        case .permissionMissing: ("Permission not installed", "权限未安装")
        case .copy: ("Copy", "拷贝")
        case .copied: ("Copied", "已拷贝")
        case .systemLanguage: ("System", "跟随系统")
        case .appTitle: ("LidStay Settings", "LidStay 设置")
        case .repoURL: ("github.com/zitao-qiu/lidstay", "github.com/zitao-qiu/lidstay")
        case .loginUnavailable: ("Unavailable for this build", "当前构建不可用")
        case .cannotArmTitle: ("Could not arm", "无法启用")
        case .cannotArmBody: ("Missing sudoers rule — run scripts/install.sh", "缺少 sudo 权限规则，请先运行 scripts/install.sh")
        case .armedTitle: ("Armed", "已启用")
        case .armedBody: ("Will keep running after the lid closes; disarms when you open it", "合盖后继续运行，打开盖子后恢复睡眠")
        case .restoredTitle: ("Lid sleep restored", "已恢复合盖睡眠")
        case .reasonLidOpened: ("Lid opened", "盖子已打开")
        case .reasonCancelled: ("Cancelled", "已取消")
        case .reasonQuit: ("LidStay quit", "LidStay 已退出")
        }
    }

    var en: String { pair.en }

    var zh: String { pair.zh }
}

final class L10n: ObservableObject {
    static let shared = L10n()

    @Published var choice: AppLanguage {
        didSet {
            UserDefaults.standard.set(choice.rawValue, forKey: "language")
            isChinese = Self.resolveChinese(choice)
        }
    }

    @Published private(set) var isChinese: Bool

    private init() {
        let raw = UserDefaults.standard.string(forKey: "language") ?? AppLanguage.system.rawValue
        let initial = AppLanguage(rawValue: raw) ?? .system
        choice = initial
        isChinese = Self.resolveChinese(initial)
    }

    private static func resolveChinese(_ choice: AppLanguage) -> Bool {
        switch choice {
        case .chinese: return true
        case .english: return false
        case .system: return Locale.preferredLanguages.first?.hasPrefix("zh") == true
        }
    }

    func t(_ s: Str) -> String { isChinese ? s.zh : s.en }

    func statusLine(_ state: GuardState) -> String {
        switch state {
        case .idle: t(.idleStatus)
        case .armedOpen: t(.armedOpenStatus)
        case .armedClosed: t(.armedClosedStatus)
        }
    }

    func batteryLine(_ percent: Int, onAC: Bool) -> String {
        "\(t(.battery)) \(percent)% · \(onAC ? t(.acPower) : t(.onBattery))"
    }

    func batteryFloorTitle(_ floor: Int) -> String {
        isChinese ? "电池下限：\(floor)%" : "Battery floor: \(floor)%"
    }

    func disarmReason(_ reason: DisarmReason) -> String {
        switch reason {
        case .lidOpened: t(.reasonLidOpened)
        case .cancelled: t(.reasonCancelled)
        case .quit: t(.reasonQuit)
        case .batteryFloor(let percent, let floor):
            isChinese
                ? "电池 \(percent)% 已达到 \(floor)% 下限"
                : "Battery \(percent)% is at or below the \(floor)% floor"
        }
    }
}
