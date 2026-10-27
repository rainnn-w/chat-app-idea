import SwiftUI
import ChatMemoryDomain

struct SettingsScreen: View {
    @ObservedObject var store: ChatStore
    @Environment(\.colorScheme) private var colorScheme

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 13) {
                        Text("隐私与安全")
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundStyle(ChatTheme.primaryText)
                        securityRow(
                            title: "本地优先存储",
                            detail: "当前原型仅使用内存数据；正式版使用加密 SQLite。",
                            symbolName: "lock.shield.fill",
                            tint: .green
                        )
                        securityRow(
                            title: "隐私锁",
                            detail: "iPad / iPhone 使用 Face ID 或 Touch ID，Mac 使用设备密码。",
                            symbolName: "faceid",
                            tint: .blue
                        )
                        securityRow(
                            title: "不无感抓取",
                            detail: "只处理用户主动导入、分享或选择的数据。",
                            symbolName: "hand.raised.fill",
                            tint: .orange
                        )
                    }
                    .padding(18)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("数据新鲜度")
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundStyle(ChatTheme.primaryText)

                        ForEach(store.importStatuses, id: \.platform) { status in
                            statusRow(status)
                        }
                    }
                    .padding(18)
                }
            }
            .padding(17)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(ChatTheme.canvasGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle("设置")
    }

    private func securityRow(title: String, detail: String, symbolName: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemName: symbolName, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ChatTheme.primaryText)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ChatTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    private func statusRow(_ status: ImportStatus) -> some View {
        HStack(spacing: 11) {
            IconBadge(systemName: status.platform.symbolName, tint: status.platform.accent, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.platform.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ChatTheme.primaryText)
                Text(Self.relativeFormatter.localizedString(for: status.lastUpdated, relativeTo: Date()))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ChatTheme.tertiaryText)
            }
            Spacer()
            Text(status.state.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(status.platform.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule(style: .continuous).fill(status.platform.accent.opacity(0.11)))
        }
    }
}

