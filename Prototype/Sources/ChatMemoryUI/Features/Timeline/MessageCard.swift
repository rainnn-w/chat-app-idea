import SwiftUI
import ChatMemoryDomain

struct MessageCard: View {
    @ObservedObject var store: ChatStore
    let message: ChatMessage
    @Environment(\.openURL) private var openURL

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        let isSelected = store.selectedMessageID == message.id

        GlassCard(cornerRadius: 22) {
            HStack(alignment: .top, spacing: 13) {
                VStack(spacing: 0) {
                    IconBadge(systemName: message.platform.symbolName, tint: message.platform.accent)
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [message.platform.accent.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(message.sender.displayName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ChatTheme.primaryText)

                        Text(message.platform.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(message.platform.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule(style: .continuous).fill(message.platform.accent.opacity(0.11)))

                        Spacer(minLength: 8)

                        Text(Self.timeFormatter.string(from: message.sentAt))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(ChatTheme.tertiaryText)

                        favoriteButton
                    }

                    Text(message.text)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(ChatTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                    if let title = message.externalTitle {
                        externalLinkPreview(title: title)
                    }

                    if !messageTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(messageTags) { tag in
                                    TagChip(tag: tag) {
                                        withAnimation(ChatTheme.quick) {
                                            store.searchText = tag.name
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(15)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(ChatTheme.smooth) {
                    store.selectedMessageID = message.id
                }
            }
            .onHover { hovering in
                withAnimation(ChatTheme.quick) {
                    store.hoveringMessageID = hovering ? message.id : nil
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isSelected ? message.platform.accent : Color.clear,
                    lineWidth: 2
                )
        )
        .scaleEffect(store.hoveringMessageID == message.id ? 1.008 : 1)
        .opacity(isSelected ? 1 : 0.97)
        .contextMenu {
            Button {
                store.toggleFavorite(message)
            } label: {
                Label(
                    message.isFavorite ? "取消收藏" : "收藏",
                    systemImage: message.isFavorite ? "star.slash" : "star"
                )
            }

            if let url = externalURL {
                Button {
                    openURL(url)
                } label: {
                    Label("打开原帖", systemImage: "safari")
                }
            }
        }
    }

    private var messageTags: [ChatTag] {
        store.messageTags(for: message)
    }

    private var externalURL: URL? {
        message.externalURL.flatMap(URL.init(string:))
    }

    private var favoriteButton: some View {
        Button {
            store.toggleFavorite(message)
        } label: {
            Image(systemName: message.isFavorite ? "star.fill" : "star")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(message.isFavorite ? Color(red: 0.98, green: 0.73, blue: 0.20) : ChatTheme.tertiaryText)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(message.isFavorite ? "取消收藏" : "收藏")
    }

    private func externalLinkPreview(title: String) -> some View {
        Button {
            if let externalURL {
                openURL(externalURL)
            }
        } label: {
            HStack(spacing: 10) {
                IconBadge(systemName: "link", tint: message.platform.accent, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ChatTheme.primaryText)
                        .lineLimit(1)
                    Text("查看原帖")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ChatTheme.tertiaryText)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(message.platform.accent)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(message.platform.accent.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}

