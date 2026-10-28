import SwiftUI
import ChatMemoryDomain

struct TimelineScreen: View {
    @ObservedObject var store: ChatStore
    @Environment(\.colorScheme) private var colorScheme

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                header

                if store.visibleMessages.isEmpty {
                    emptyState
                } else {
                    let groups = store.groupedVisibleMessages().reversed()

                    ForEach(Array(groups), id: \.day) { group in
                        Section {
                            ForEach(group.messages) { message in
                                MessageCard(store: store, message: message)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                                        removal: .opacity.combined(with: .scale(scale: 0.96))
                                    ))
                            }
                        } header: {
                            dayHeader(group.day)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 42)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(ChatTheme.canvasGradient(for: colorScheme).ignoresSafeArea())
        .refreshable {
            withAnimation(ChatTheme.quick) {
                store.isRefreshing = true
            }
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(ChatTheme.quick) {
                store.isRefreshing = false
            }
        }
        .animation(ChatTheme.smooth, value: store.visibleMessages)
        .sheet(isPresented: $store.isShowingCaptureSheet) {
            MessageCaptureView(store: store)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 15) {
            if let person = store.selectedPerson {
                ZStack(alignment: .bottomLeading) {
                    ChatTheme.heroGradient
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 190)
                        .offset(x: 100, y: -75)

                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        .frame(width: 130)
                        .offset(x: 145, y: 25)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.20))
                                Text(person.initials)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 58, height: 58)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.name)
                                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(person.subtitle)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.82))
                            }

                            Spacer(minLength: 12)

                            Button {
                                store.isShowingCaptureSheet = true
                            } label: {
                                Label("录入", systemImage: "plus.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 9)
                                    .background(Capsule(style: .continuous).fill(.white.opacity(0.20)))
                            }
                            .buttonStyle(PressableButtonStyle())
                            .keyboardShortcut("n", modifiers: .command)
                        }

                        HStack(spacing: 8) {
                            statPill(
                                title: "消息",
                                value: "\(store.selectedMessages.count)",
                                symbolName: "bubble.left.and.bubble.right.fill",
                                tint: .white
                            )
                            statPill(
                                title: "平台",
                                value: "\(Set(store.selectedMessages.map(\.platform)).count)",
                                symbolName: "square.grid.2x2.fill",
                                tint: .white
                            )
                            statPill(
                                title: "标签",
                                value: "\(messageTagCount)",
                                symbolName: "tag.fill",
                                tint: .white
                            )
                        }
                    }
                    .padding(19)
                }
            }

            searchControls

            if !store.searchText.isEmpty {
                HStack {
                    Label("\(store.visibleMessages.count) 条结果", systemImage: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ChatTheme.secondaryText)
                    Spacer()
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ChatPlatform.allCases) { platform in
                        PlatformPill(
                            platform: platform,
                            isSelected: store.selectedPlatforms.contains(platform)
                        ) {
                            store.toggle(platform)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var messageTagCount: Int {
        Set(store.selectedMessages.flatMap(\.tagIDs)).count
    }

    private var searchControls: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            VStack(alignment: .leading, spacing: 8) {
                SearchField(text: $store.searchText)
                scopePicker
            }
        } else {
            HStack(spacing: 8) {
                SearchField(text: $store.searchText)
                scopePicker
                    .frame(width: 180)
            }
        }
        #else
        HStack(spacing: 8) {
            SearchField(text: $store.searchText)
            scopePicker
                .frame(width: 180)
        }
        #endif
    }

    private var scopePicker: some View {
        Picker("搜索范围", selection: $store.searchScope) {
            ForEach(SearchScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 13) {
                IconBadge(systemName: "sparkle.magnifyingglass", tint: .purple, size: 52)
                Text("没有找到这条记忆")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ChatTheme.primaryText)
                Text("换个关键词，或重新选择平台来源。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ChatTheme.secondaryText)
                Button {
                    withAnimation(ChatTheme.smooth) {
                        store.searchText = ""
                        store.searchScope = .currentPerson
                        store.selectedPlatforms = Set(ChatPlatform.allCases)
                        store.applySearch()
                    }
                } label: {
                    Text("重置筛选")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 10)
                        .background(Capsule(style: .continuous).fill(Color.purple))
                }
                .buttonStyle(PressableButtonStyle())
            }
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .padding(27)
        }
    }

    private func dayHeader(_ day: Date) -> some View {
        HStack {
            Label(Self.dayFormatter.string(from: day), systemImage: "calendar")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ChatTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule(style: .continuous).fill(ChatTheme.surface(for: colorScheme)))
                .shadow(color: ChatTheme.softShadow, radius: 8, y: 4)
            Spacer()
        }
        .padding(.vertical, 7)
        .background(ChatTheme.canvasGradient(for: colorScheme))
    }

    private func statPill(title: String, value: String, symbolName: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .bold))
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .opacity(0.82)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule(style: .continuous).fill(.white.opacity(0.17)))
    }
}

