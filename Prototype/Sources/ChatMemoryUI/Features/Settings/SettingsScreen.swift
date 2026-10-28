import SwiftUI
import ChatMemoryDomain
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct SettingsScreen: View {
    @ObservedObject var store: ChatStore
    @Environment(\.colorScheme) private var colorScheme

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter
    }()

    private static let inboxPath = ChatStore.inboxDirectoryURL.path

    private var automationTargetBinding: Binding<UUID?> {
        Binding(
            get: { store.automationTargetPersonID },
            set: { store.setAutomationTarget($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                privacyCard
                storageCard
                freshnessCard
            }
            .padding(17)
            .frame(maxWidth: 770)
            .frame(maxWidth: .infinity)
        }
        .background(ChatTheme.canvasGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle("设置")
        .fileImporter(
            isPresented: $store.isShowingJSONImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importJSON(result)
        }
        .confirmationDialog(
            "清空所有本地数据？",
            isPresented: $store.isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空", role: .destructive) {
                store.replace(
                    with: ChatStoreSnapshot(
                        people: [],
                        messages: [],
                        tags: [],
                        importStatuses: []
                    )
                )
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("清空后需要重新录入或导入 JSON。")
        }
        .confirmationDialog(
            "恢复示例数据？",
            isPresented: $store.isShowingSampleConfirmation,
            titleVisibility: .visible
        ) {
            Button("恢复示例") {
                let sample = MockChatData.makeStore()
                store.replace(with: sample.makeSnapshot())
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前手动录入的数据会被示例数据替换。")
        }
        .alert(
            "导入失败",
            isPresented: Binding(
                get: { store.importError != nil },
                set: { if !$0 { store.importError = nil } }
            ),
            presenting: store.importError
        ) { _ in
            Button("好", role: .cancel) { store.importError = nil }
        } message: { error in
            Text(error)
        }
    }

    private var privacyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                Text("隐私与安全")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(ChatTheme.primaryText)
                securityRow(
                    title: "本地优先存储",
                    detail: "数据保存在本机 Application Support，不上传聊天内容。",
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
                    detail: "只处理用户主动录入、导入或分享的数据。",
                    symbolName: "hand.raised.fill",
                    tint: .orange
                )
            }
            .padding(18)
        }
    }

    private var storageCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("本地数据")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(ChatTheme.primaryText)

                HStack(spacing: 10) {
                    metricCard("联系人", "\(store.people.count)", "person.2.fill", .purple)
                    metricCard("消息", "\(store.messages.count)", "bubble.left.and.bubble.right.fill", .blue)
                    metricCard("标签", "\(store.tags.count)", "tag.fill", .orange)
                }

                if !store.importBatches.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近导入")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(ChatTheme.primaryText)

                        ForEach(store.importBatches.sorted { $0.importedAt > $1.importedAt }.prefix(3)) { batch in
                            HStack(spacing: 10) {
                                IconBadge(
                                    systemName: "shippingbox.fill",
                                    tint: batch.format == .wechatSQLite ? .green : .purple,
                                    size: 32
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(batch.format.title) · \(batch.importedCount) 条")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(ChatTheme.primaryText)
                                    Text(batch.fileName)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(ChatTheme.tertiaryText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Text(Self.relativeFormatter.localizedString(for: batch.importedAt, relativeTo: Date()))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(ChatTheme.tertiaryText)
                            }
                        }
                    }
                    .padding(11)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Color.purple.opacity(0.06))
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("自动导入 Inbox")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(ChatTheme.primaryText)

                    Toggle("自动导入", isOn: Binding(
                        get: { store.automationEnabled },
                        set: { store.setAutomationEnabled($0) }
                    ))

                    Picker("目标联系人", selection: automationTargetBinding) {
                        Text("未设置").tag(UUID?.none)
                        ForEach(store.people) { person in
                            Text(person.name).tag(UUID?.some(person.id))
                        }
                    }
                    .pickerStyle(.menu)

                    Text(Self.inboxPath)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(ChatTheme.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    HStack {
                        Button {
                            store.importInboxFiles()
                        } label: {
                            Label("立即检查", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)

                        #if os(macOS)
                        Button {
                            NSWorkspace.shared.open(ChatStore.inboxDirectoryURL)
                        } label: {
                            Label("打开 Inbox", systemImage: "folder")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.purple)
                        }
                        .buttonStyle(.plain)
                        #endif

                        Text(store.automationStatus)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ChatTheme.secondaryText)
                            .lineLimit(3)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.blue.opacity(0.06))
                )

                VStack(alignment: .leading, spacing: 9) {
                    if let json = exportJSON() {
                        ShareLink(
                            item: json,
                            subject: Text("ChatMemory 导出数据"),
                            message: Text("这是你从 ChatMemory 导出的本地聊天记忆 JSON。")
                        ) {
                            settingsAction("导出 JSON", "square.and.arrow.up", .blue)
                        }
                    }

                    Button {
                        store.isShowingJSONImporter = true
                    } label: {
                        settingsAction("导入 JSON", "square.and.arrow.down", .green)
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.isShowingSampleConfirmation = true
                    } label: {
                        settingsAction("恢复示例数据", "sparkles", .purple)
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.isShowingResetConfirmation = true
                    } label: {
                        settingsAction("清空本地数据", "trash", .red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
    }

    private var freshnessCard: some View {
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

    private func securityRow(
        title: String,
        detail: String,
        symbolName: String,
        tint: Color
    ) -> some View {
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

    private func metricCard(
        _ title: String,
        _ value: String,
        _ symbolName: String,
        _ tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            IconBadge(systemName: symbolName, tint: tint, size: 32)
            Text(value)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(ChatTheme.primaryText)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ChatTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }

    private func settingsAction(
        _ title: String,
        _ symbolName: String,
        _ tint: Color
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ChatTheme.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ChatTheme.tertiaryText)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }

    private func statusRow(_ status: ImportStatus) -> some View {
        HStack(spacing: 11) {
            IconBadge(
                systemName: status.platform.symbolName,
                tint: status.platform.accent,
                size: 34
            )
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
                .background(
                    Capsule(style: .continuous)
                        .fill(status.platform.accent.opacity(0.11))
                )
        }
    }

    private func exportJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try? String(
            data: encoder.encode(store.makeSnapshot()),
            encoding: .utf8
        )
    }

    private func importJSON(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let snapshot = try decoder.decode(ChatStoreSnapshot.self, from: data)
                store.replace(with: snapshot)
            } catch {
                store.importError = "无法解析该 JSON 文件：\(error.localizedDescription)"
            }

        case .failure(let error):
            store.importError = error.localizedDescription
        }
    }
}
