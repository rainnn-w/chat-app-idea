import SwiftUI
import ChatMemoryDomain

struct TagLibraryScreen: View {
    @ObservedObject var store: ChatStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 230), spacing: 13)],
                spacing: 13
            ) {
                ForEach(store.tags) { tag in
                    tagCard(tag)
                }
            }
            .padding(17)
            .frame(maxWidth: 880)
            .frame(maxWidth: .infinity)
        }
        .background(ChatTheme.canvasGradient(for: colorScheme).ignoresSafeArea())
        .navigationTitle("标签")
    }

    private func tagCard(_ tag: ChatTag) -> some View {
        let color = ChatTheme.color(for: tag.color)
        let messages = store.messages.filter { $0.tagIDs.contains(tag.id) }

        return GlassCard(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    IconBadge(systemName: tag.symbolName, tint: color, size: 38)
                    Spacer()
                    Text("\(messages.count)")
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .foregroundStyle(color)
                }

                Text(tag.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(ChatTheme.primaryText)

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(messages.prefix(2)) { message in
                        Text(message.text)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ChatTheme.secondaryText)
                            .lineLimit(2)
                    }
                }
                .frame(minHeight: 42, alignment: .top)

                Button {
                    store.select(store.selectedPerson)
                    withAnimation(ChatTheme.smooth) {
                        store.searchText = tag.name
                    }
                } label: {
                    Label("查看标签结果", systemImage: "arrow.right.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
            }
            .padding(15)
        }
    }
}

