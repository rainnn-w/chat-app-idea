import SwiftUI
import ChatMemoryDomain

struct MessageEditView: View {
    @ObservedObject var store: ChatStore
    let original: ChatMessage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var model: MessageEditModel

    init(store: ChatStore, original: ChatMessage) {
        self.store = store
        self.original = original
        _model = StateObject(wrappedValue: MessageEditModel(message: original))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                IconBadge(systemName: "square.and.pencil", tint: .blue, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("编辑消息")
                        .font(.system(size: 20, weight: .heavy))
                    Text("修正时间、内容、原帖和标签")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ChatTheme.secondaryText)
                }
                Spacer()
            }

            GlassCard(cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("平台", selection: $model.platform) {
                        ForEach(ChatPlatform.allCases) { platform in
                            Text(platform.displayName).tag(platform)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("发送者", selection: $model.sender) {
                        ForEach(MessageSender.allCases, id: \.self) { sender in
                            Text(sender.displayName).tag(sender)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("时间", selection: $model.sentAt)

                    field("内容", text: $model.text, minHeight: 105)

                    HStack(spacing: 10) {
                        field("原帖标题", text: $model.externalTitle, minHeight: 42)
                        field("原帖链接", text: $model.externalURL, minHeight: 42)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(store.tags) { tag in
                                TagChip(tag: tag) {
                                    model.toggle(tag)
                                }
                                .opacity(model.tagIDs.contains(tag.id) ? 1 : 0.48)
                            }
                        }
                    }
                }
                .padding(15)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button {
                    store.updateMessage(model.message(id: original.id, personID: original.personID))
                    dismiss()
                } label: {
                    Text("保存修改")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(Capsule(style: .continuous).fill(ChatTheme.heroGradient))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!model.canSave)
            }
        }
        .padding(20)
        .frame(width: 530, height: 590)
        .background(ChatTheme.canvasGradient(for: colorScheme))
    }

    private func field(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ChatTheme.secondaryText)
            if minHeight > 60 {
                TextEditor(text: text)
                    .font(.system(size: 14))
                    .frame(minHeight: minHeight)
                    .scrollContentBackground(.hidden)
                    .padding(8)
            } else {
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .padding(10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(ChatTheme.surface(for: colorScheme))
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

final class MessageEditModel: ObservableObject {
    @Published var platform: ChatPlatform
    @Published var sender: MessageSender
    @Published var sentAt: Date
    @Published var text: String
    @Published var externalTitle: String
    @Published var externalURL: String
    @Published var tagIDs: Set<UUID>
    private let isFavorite: Bool

    init(message: ChatMessage) {
        platform = message.platform
        sender = message.sender
        sentAt = message.sentAt
        text = message.text
        externalTitle = message.externalTitle ?? ""
        externalURL = message.externalURL ?? ""
        tagIDs = message.tagIDs
        isFavorite = message.isFavorite
    }

    var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func toggle(_ tag: ChatTag) {
        if tagIDs.contains(tag.id) {
            tagIDs.remove(tag.id)
        } else {
            tagIDs.insert(tag.id)
        }
    }

    func message(id: UUID, personID: UUID) -> ChatMessage {
        ChatMessage(
            id: id,
            personID: personID,
            platform: platform,
            sender: sender,
            sentAt: sentAt,
            text: text,
            externalTitle: externalTitle.isEmpty ? nil : externalTitle,
            externalURL: externalURL.isEmpty ? nil : externalURL,
            tagIDs: tagIDs,
            isFavorite: isFavorite
        )
    }
}
