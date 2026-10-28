import SwiftUI
import ChatMemoryDomain

struct MessageInspector: View {
    @ObservedObject var store: ChatStore
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                header
                messageBody
                contextCard
                tagCard
                actionCard
            }
            .padding(17)
            .frame(maxWidth: 470)
            .frame(maxWidth: .infinity)
        }
        .background(ChatTheme.canvasGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle("消息详情")
        .sheet(isPresented: $store.isShowingMessageEditorSheet) {
            if let selectedMessage = store.selectedMessage {
                MessageEditView(store: store, original: selectedMessage)
            }
        }
        .confirmationDialog(
            "删除这条消息？",
            isPresented: $store.isShowingDeleteMessageConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                store.deleteMessage(id: message.id)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不可恢复。")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            IconBadge(
                systemName: message.platform.symbolName,
                tint: message.platform.accent,
                size: 42
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(message.platform.displayName)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(ChatTheme.primaryText)
                Text("\(message.sender.displayName) · \(Self.timeFormatter.string(from: message.sentAt))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ChatTheme.tertiaryText)
            }
            Spacer()

            Button {
                store.toggleFavorite(message)
            } label: {
                Image(systemName: message.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(message.isFavorite ? Color.orange : ChatTheme.tertiaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(message.isFavorite ? "取消收藏" : "收藏")
        }
    }

    private var messageBody: some View {
        Text(message.text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(ChatTheme.primaryText)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var contextCard: some View {
        GlassCard(cornerRadius: 19) {
            VStack(alignment: .leading, spacing: 10) {
                Text("上下文")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(ChatTheme.primaryText)

                if let previous {
                    contextRow("上一条", previous)
                }

                contextRow("当前", message, isCurrent: true)

                if let next {
                    contextRow("下一条", next)
                }
            }
            .padding(14)
        }
    }

    private var tagCard: some View {
        GlassCard(cornerRadius: 19) {
            VStack(alignment: .leading, spacing: 11) {
                Text("标签")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(ChatTheme.primaryText)

                ForEach(store.tags) { tag in
                    tagToggle(tag)
                }
            }
            .padding(14)
        }
    }

    private var actionCard: some View {
        HStack(spacing: 10) {
            Button {
                store.isShowingMessageEditorSheet = true
            } label: {
                Label("编辑", systemImage: "square.and.pencil")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.blue.opacity(0.12))
                    )
                    .foregroundStyle(.blue)
            }
            .buttonStyle(PressableButtonStyle())

            Button {
                store.isShowingDeleteMessageConfirmation = true
            } label: {
                Label("删除", systemImage: "trash")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.red.opacity(0.11))
                    )
                    .foregroundStyle(.red)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var contextMessages: [ChatMessage] {
        store.selectedMessages
    }

    private var messageIndex: Int? {
        contextMessages.firstIndex { $0.id == message.id }
    }

    private var previous: ChatMessage? {
        guard let index = messageIndex, index > 0 else { return nil }
        return contextMessages[index - 1]
    }

    private var next: ChatMessage? {
        guard let index = messageIndex, index < contextMessages.count - 1 else { return nil }
        return contextMessages[index + 1]
    }

    private func contextRow(_ title: String, _ item: ChatMessage, isCurrent: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(title)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(item.platform.accent)
                .frame(width: 34, alignment: .leading)

            Text(item.text)
                .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                .foregroundStyle(isCurrent ? ChatTheme.primaryText : ChatTheme.secondaryText)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isCurrent ? item.platform.accent.opacity(0.09) : Color.clear)
        )
    }

    private func tagToggle(_ tag: ChatTag) -> some View {
        let isSelected = message.tagIDs.contains(tag.id)
        let color = ChatTheme.color(for: tag.color)

        return Button {
            store.toggleTag(tag, on: message)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? color : ChatTheme.tertiaryText)
                Text(tag.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ChatTheme.primaryText)
                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? color.opacity(0.10) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

