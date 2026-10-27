import SwiftUI
import ChatMemoryDomain

public struct AppRootView: View {
    @StateObject private var store = MockChatData.makeStore()
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    public var body: some View {
        Group {
            #if os(iOS)
            if horizontalSizeClass == .regular {
                splitLayout
            } else {
                compactLayout
            }
            #else
            splitLayout
            #endif
        }
        .preferredColorScheme(nil)
    }

    private var splitLayout: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            PersonSidebar(store: store)
        } content: {
            TimelineScreen(store: store)
                .navigationTitle(store.selectedPerson?.name ?? "时间线")
        } detail: {
            if let message = store.selectedMessage {
                MessageInspector(store: store, message: message)
            } else {
                inspectorPlaceholder
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    #if os(iOS)
    private var compactLayout: some View {
        TabView {
            NavigationStack {
                TimelineScreen(store: store)
                    .navigationTitle(store.selectedPerson?.name ?? "时间线")
                    .toolbarBackground(.hidden, for: .tabBar)
            }
            .sheet(item: compactSelectedMessage) { message in
                NavigationStack {
                    MessageInspector(store: store, message: message)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") {
                                    store.selectedMessageID = nil
                                }
                            }
                        }
                }
            }
            .tabItem {
                Label("时间线", systemImage: "bubble.left.and.bubble.right.fill")
            }

            NavigationStack {
                TagLibraryScreen(store: store)
            }
            .tabItem {
                Label("标签", systemImage: "tag.fill")
            }

            NavigationStack {
                PersonSidebar(store: store)
            }
            .tabItem {
                Label("联系人", systemImage: "person.2.fill")
            }

            NavigationStack {
                SettingsScreen(store: store)
            }
            .tabItem {
                Label("设置", systemImage: "gearshape.fill")
            }
        }
    }
    #endif

    private var inspectorPlaceholder: some View {
        VStack(spacing: 12) {
            IconBadge(systemName: "sidebar.right", tint: .purple, size: 52)
            Text("选择一条消息")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(ChatTheme.primaryText)
            Text("在这里查看上下文、管理标签和跳转原帖。")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ChatTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChatTheme.canvasGradient(for: colorScheme).ignoresSafeArea())
    }

    private var compactSelectedMessage: Binding<ChatMessage?> {
        Binding(
            get: { store.selectedMessage },
            set: { newValue in
                if newValue == nil {
                    store.selectedMessageID = nil
                }
            }
        )
    }
}

