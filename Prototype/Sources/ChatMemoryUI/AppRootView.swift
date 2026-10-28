import SwiftUI
import ChatMemoryDomain

public struct AppRootView: View {
    @StateObject private var store: ChatStore
    @Environment(\.colorScheme) private var colorScheme
    private static let repository = ChatStoreRepository.defaultRepository()

    public init() {
        _store = StateObject(wrappedValue: Self.makeStore())
    }

    private static func makeStore() -> ChatStore {
        let store = repository.load(seed: MockChatData.makeStore())
        store.onDidChange = {
            try? repository.save(store)
        }
        try? repository.save(store)
        return store
    }

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
        .onAppear {
            store.startInboxAutomation()
        }
    }

    private var splitLayout: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            PersonSidebar(store: store)
        } content: {
            switch store.selectedSection {
            case .timeline:
                TimelineScreen(store: store)
                    .navigationTitle(store.selectedPerson?.name ?? "时间线")
            case .tags:
                TagLibraryScreen(store: store)
            case .settings:
                SettingsScreen(store: store)
            }
        } detail: {
            if store.selectedSection != .timeline {
                sectionDetailPlaceholder
            } else if let message = store.selectedMessage {
                MessageInspector(store: store, message: message)
            } else {
                inspectorPlaceholder
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    #if os(iOS)
    private var compactLayout: some View {
        TabView(selection: compactSectionBinding) {
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
            .tag(AppSection.timeline)
            .tabItem {
                Label("时间线", systemImage: "bubble.left.and.bubble.right.fill")
            }

            NavigationStack {
                TagLibraryScreen(store: store)
            }
            .tag(AppSection.tags)
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
            .tag(AppSection.settings)
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

    private var compactSectionBinding: Binding<AppSection> {
        Binding(
            get: { store.selectedSection },
            set: { section in
                store.selectedSection = section
            }
        )
    }

    private var sectionDetailPlaceholder: some View {
        VStack(spacing: 12) {
            IconBadge(
                systemName: store.selectedSection.symbolName,
                tint: .purple,
                size: 48
            )
            Text(store.selectedSection.title)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(ChatTheme.primaryText)
            Text("请在左侧调整筛选，或在中间区域管理内容。")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ChatTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChatTheme.canvasGradient(for: colorScheme).ignoresSafeArea())
    }
}

