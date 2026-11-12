import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var g: Guard
    @ObservedObject var l10n: L10n
    @ObservedObject var login: LoginItem

    @State private var permissionOK = true
    @State private var copied = false

    private let floors = [10, 15, 20, 25, 30]
    private let installCommand = "./scripts/install.sh"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            section(l10n.t(.general)) {
                card {
                    row(icon: "gearshape", label: l10n.t(.launchAtLogin)) {
                        Toggle("", isOn: Binding(get: { login.isOn }, set: { login.set($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    if login.failed {
                        Text(l10n.t(.loginUnavailable))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 32)
                            .padding(.bottom, 4)
                    }
                    hairline
                    row(icon: "battery.25", label: l10n.t(.batteryFloor)) {
                        Picker("", selection: Binding(get: { g.floor }, set: { g.setFloor($0) })) {
                            ForEach(floors, id: \.self) { Text("\($0)%").tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }
            }

            section(l10n.t(.permission)) {
                card {
                    if permissionOK {
                        row(icon: "lock.shield", label: l10n.t(.ready), tint: .green) {
                            EmptyView()
                        }
                    } else {
                        row(icon: "lock.shield", label: l10n.t(.permissionMissing), tint: .orange) {
                            permissionFix
                        }
                    }
                }
            }

            section(l10n.t(.language)) {
                card {
                    row(icon: "globe", label: l10n.t(.language)) {
                        Picker("", selection: $l10n.choice) {
                            Text(l10n.t(.systemLanguage)).tag(AppLanguage.system)
                            Text("English").tag(AppLanguage.english)
                            Text("简体中文").tag(AppLanguage.chinese)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }
            }

            section(l10n.t(.about)) {
                card { aboutRow }
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(Color(nsColor: .underPageBackgroundColor))
        .navigationTitle(l10n.t(.appTitle))
        .onAppear { permissionOK = Sys.canToggleSleepDisabled() }
    }

    private var permissionFix: some View {
        HStack(spacing: 6) {
            Text(installCommand)
                .font(.system(size: 11, design: .monospaced))
                .fixedSize()
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                )
            Button {
                copyInstallCommand()
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help(l10n.t(.copy))
        }
    }

    private var aboutRow: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 36, height: 36)
            Text("LidStay \(version)")
                .font(.system(size: 13, weight: .semibold))
                .textSelection(.enabled)
            Spacer(minLength: 12)
            Text(.init("[\(l10n.t(.repoURL))](https://github.com/TTT-qq-TT/lidstay)"))
                .font(.system(size: 12))
                .textSelection(.enabled)
        }
        .frame(height: 36)
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0"
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
            .padding(.leading, 32)
    }

    private func copyInstallCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(installCommand, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
    }

    private func row<Control: View>(
        icon: String,
        label: String,
        tint: Color = .secondary,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(tint)
                .frame(width: 22, alignment: .leading)
            Text(label)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer(minLength: 12)
            control()
        }
        .frame(height: 30)
    }
}
