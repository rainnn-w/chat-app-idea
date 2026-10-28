import SwiftUI
import ChatMemoryDomain

struct MessageCaptureView: View {
    @ObservedObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var model = MessageCaptureModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Picker("录入方式", selection: $model.mode) {
                ForEach(MessageCaptureModel.CaptureMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            GlassCard(cornerRadius: 21) {
                VStack(alignment: .leading, spacing: 15) {
                    if model.mode == .single {
                        singleForm
                    } else {
                        bulkForm
                    }
                }
                .padding(15)
            }

            HStack {
                Text("数据会保存在本机")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ChatTheme.tertiaryText)
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                saveButton
            }
        }
        .padding(20)
        .frame(width: 540, height: model.mode == .single ? 580 : 480)
        .background(ChatTheme.canvasGradient(for: colorScheme))
        .animation(ChatTheme.smooth, value: model.mode)
    }

    private var header: some View {
        HStack(spacing: 10) {
            IconBadge(systemName: "plus.square.dashed.on.square", tint: .purple, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("录入聊天记忆")
                    .font(.system(size: 21, weight: .heavy))
                Text(store.selectedPerson.map { "当前联系人：\($0.name)" } ?? "请先选择联系人")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ChatTheme.secondaryText)
            }
            Spacer()
        }
    }

    private var singleForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            platformPicker
            senderPicker(allowSystem: true)

            DatePicker("时间", selection: $model.sentAt)
                .datePickerStyle(.compact)

            LabeledEditor(title: "内容", text: $model.text, minHeight: 105)

            HStack(spacing: 10) {
                captionField("原帖标题", text: $model.externalTitle, prompt: "京都咖啡地图")
                captionField("原帖链接", text: $model.externalURL, prompt: "https://")
            }

            tagPicker
        }
    }

    private var bulkForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            platformPicker
            senderPicker(allowSystem: false)

            LabeledEditor(title: "每行一条消息", text: $model.bulkText, minHeight: 175)

            Text("适合快速粘贴口头约定、食物偏好或待办事项。")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ChatTheme.tertiaryText)
        }
    }

    private var saveButton: some View {
        Button {
            model.save(to: store)
            dismiss()
        } label: {
            Label("保存", systemImage: "tray.and.arrow.down.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(model.canSave ? ChatTheme.heroGradient : ChatTheme.disabledGradient)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .keyboardShortcut(.defaultAction)
        .disabled(!model.canSave)
    }

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("标签")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.tags) { tag in
                        TagChip(tag: tag) {
                            withAnimation(ChatTheme.quick) {
                                model.toggle(tag)
                            }
                        }
                        .opacity(model.selectedTags.contains(tag.id) ? 1 : 0.48)
                    }
                }
            }
        }
    }

    private var platformPicker: some View {
        Picker("平台", selection: $model.platform) {
            ForEach(ChatPlatform.allCases) { platform in
                Text(platform.displayName).tag(platform)
            }
        }
        .pickerStyle(.segmented)
    }

    private func senderPicker(allowSystem: Bool) -> some View {
        Picker("发送者", selection: $model.sender) {
            ForEach(allowSystem ? MessageSender.allCases : [.peer, .me], id: \.self) { sender in
                Text(sender.displayName).tag(sender)
            }
        }
        .pickerStyle(.segmented)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(ChatTheme.surface(for: colorScheme))
            .stroke(Color.black.opacity(0.05), lineWidth: 1)
    }

    private func captionField(
        _ title: String,
        text: Binding<String>,
        prompt: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ChatTheme.secondaryText)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .padding(10)
                .background(fieldBackground)
        }
    }

    private struct LabeledEditor: View {
        let title: String
        @Binding var text: String
        let minHeight: CGFloat
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ChatTheme.secondaryText)
                TextEditor(text: $text)
                    .font(.system(size: 14))
                    .frame(minHeight: minHeight)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ChatTheme.surface(for: colorScheme))
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
            }
        }
    }
}

final class MessageCaptureModel: ObservableObject {
    @Published var mode = CaptureMode.single
    @Published var text = ""
    @Published var bulkText = ""
    @Published var platform: ChatPlatform = .wechat
    @Published var sender: MessageSender = .peer
    @Published var sentAt = Date()
    @Published var externalTitle = ""
    @Published var externalURL = ""
    @Published var selectedTags: Set<UUID> = []

    enum CaptureMode: String, CaseIterable, Identifiable {
        case single
        case bulk

        var id: String { rawValue }
        var title: String {
            switch self {
            case .single: "单条"
            case .bulk: "多行"
            }
        }
    }

    var canSave: Bool {
        mode == .single
            ? !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : !bulkLines.isEmpty
    }

    var bulkLines: [String] {
        bulkText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func toggle(_ tag: ChatTag) {
        if selectedTags.contains(tag.id) {
            selectedTags.remove(tag.id)
        } else {
            selectedTags.insert(tag.id)
        }
    }

    func save(to store: ChatStore) {
        guard let personID = store.selectedPersonID else { return }

        if mode == .single {
            store.addMessage(
                personID: personID,
                platform: platform,
                sender: sender,
                sentAt: sentAt,
                text: text,
                externalTitle: externalTitle,
                externalURL: externalURL,
                tagIDs: selectedTags
            )
        } else {
            for (offset, line) in bulkLines.enumerated() {
                store.addMessage(
                    personID: personID,
                    platform: platform,
                    sender: sender,
                    sentAt: sentAt.addingTimeInterval(TimeInterval(-offset)),
                    text: line
                )
            }
        }
    }
}
