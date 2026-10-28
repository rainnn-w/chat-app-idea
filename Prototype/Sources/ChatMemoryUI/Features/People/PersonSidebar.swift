import SwiftUI
import ChatMemoryDomain

struct PersonSidebar: View {
    @ObservedObject var store: ChatStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 9) {
                IconBadge(systemName: "heart.text.square.fill", tint: .pink, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("聊天记忆库")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                    Text("跨平台 · 本地优先")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ChatTheme.tertiaryText)
                }
                Spacer()
            }

            Picker("模块", selection: $store.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)

            ScrollView {
                VStack(spacing: 9) {
                    if store.selectedSection == .timeline {
                        ForEach(store.people) { person in
                            personButton(person)
                        }

                        Button {
                            store.isShowingPersonEditorSheet = true
                        } label: {
                            Label("添加联系人", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill(ChatTheme.heroGradient)
                                )
                        }
                        .buttonStyle(PressableButtonStyle())
                    } else {
                        GlassCard(cornerRadius: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                IconBadge(
                                    systemName: store.selectedSection.symbolName,
                                    tint: .purple,
                                    size: 34
                                )
                                Text(store.selectedSection.title)
                                    .font(.system(size: 15, weight: .heavy))
                                Text(store.selectedSection == .tags ? "按标签回顾偏好、约定和待办。" : "管理本地数据、备份和隐私说明。")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(ChatTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $store.isShowingPersonEditorSheet) {
            PersonEditorView(store: store)
        }
        .padding(13)
        .frame(minWidth: 245)
        .navigationTitle("联系人")
        .navigationSplitViewColumnWidth(min: 235, ideal: 265, max: 320)
    }

    private func personButton(_ person: ChatPerson) -> some View {
        let isSelected = store.selectedPersonID == person.id
        let messageCount = store.messages.filter { $0.personID == person.id }.count

        return Button {
            store.select(person)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(ChatTheme.personGradient(for: person))
                    Text(person.initials)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ChatTheme.primaryText)
                    Text("\(messageCount) 条记忆")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ChatTheme.tertiaryText)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.purple)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.purple.opacity(colorScheme == .dark ? 0.20 : 0.11)
                            : ChatTheme.surface(for: colorScheme)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.purple.opacity(0.22) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

