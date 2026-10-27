import SwiftUI
import ChatMemoryDomain

struct MessageInspector: View {
    @ObservedObject var store: ChatStore
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 10) {
                    IconBadge(systemName: message.platform.symbolName, tint: message.platform.accent, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.platform.displayName)
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(ChatTheme.primaryText)
                        Text(message.sender.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ChatTheme.tertiaryText)
                    }
                    Spacer()
                }

                Text(message.text)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ChatTheme.primaryText)
                    .lineSpacing(4)

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
            .padding(17)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .background(ChatTheme.canvasGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle("消息详情")
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

