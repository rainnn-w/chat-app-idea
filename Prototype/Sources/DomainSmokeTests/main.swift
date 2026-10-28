import Foundation
import ChatMemoryDomain

@main
enum DomainSmokeTests {
    static func main() {
        var failures: [String] = []

        func expect(
            _ condition: @autoclosure () -> Bool,
            _ name: String
        ) {
            if !condition() {
                failures.append(name)
            }
        }

        let person = ChatPerson(name: "小鹿", subtitle: "测试联系人")
        let otherPerson = ChatPerson(name: "沐沐", subtitle: "另一位测试联系人")
        let food = ChatTag(name: "食物爱好", symbolName: "fork.knife", color: .coral)
        let travel = ChatTag(name: "旅行灵感", symbolName: "airplane", color: .sky)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let messages = [
            ChatMessage(
                personID: person.id,
                platform: .wechat,
                sender: .peer,
                sentAt: now.addingTimeInterval(-60),
                text: "晚上不要香菜",
                tagIDs: [food.id]
            ),
            ChatMessage(
                personID: person.id,
                platform: .xiaohongshu,
                sender: .me,
                sentAt: now.addingTimeInterval(-120),
                text: "明年去京都",
                externalTitle: "京都咖啡地图",
                externalURL: "https://example.com",
                tagIDs: [travel.id]
            ),
            ChatMessage(
                personID: person.id,
                platform: .qq,
                sender: .peer,
                sentAt: now.addingTimeInterval(-180),
                text: "周五看展取票"
            ),
            ChatMessage(
                personID: otherPerson.id,
                platform: .xiaohongshu,
                sender: .peer,
                sentAt: now.addingTimeInterval(-240),
                text: "周六想去市集",
                tagIDs: [travel.id]
            ),
            ChatMessage(
                personID: otherPerson.id,
                platform: .wechat,
                sender: .peer,
                sentAt: now.addingTimeInterval(-300),
                text: "不要花生",
                tagIDs: [food.id],
                isFavorite: true
            )
        ]
        let store = ChatStore(
            people: [person, otherPerson],
            messages: messages,
            tags: [food, travel],
            importStatuses: ChatPlatform.allCases.map {
                ImportStatus(platform: $0, lastUpdated: now, state: .fresh)
            }
        )

        store.searchText = "香菜"
        expect(store.visibleMessages.count == 1, "文本搜索")
        store.searchText = "tag:旅行"
        expect(
            store.visibleMessages.count == 1 && store.visibleMessages[0].platform == .xiaohongshu,
            "标签搜索"
        )
        store.searchText = ""
        store.searchScope = .allPeople
        expect(store.visibleMessages.count == 5, "全局搜索")
        store.searchText = "不要"
        expect(
            store.visibleMessages.count == 2,
            "全局文本搜索"
        )
        store.searchText = "person:沐沐 不要"
        expect(
            store.visibleMessages.count == 1 && store.visibleMessages[0].personID == otherPerson.id,
            "联系人过滤"
        )
        store.searchText = "platform:xhs 市集"
        expect(
            store.visibleMessages.count == 1 && store.visibleMessages[0].platform == .xiaohongshu,
            "平台别名过滤"
        )
        store.searchText = "is:favorite"
        expect(
            store.visibleMessages.count == 1 && store.visibleMessages[0].isFavorite,
            "收藏过滤"
        )
        store.searchText = ""
        store.searchScope = .currentPerson
        store.searchText = ""
        expect(store.visibleMessages.count == 3, "清空搜索")

        for platform in ChatPlatform.allCases where platform != .wechat {
            store.toggle(platform)
        }
        expect(
            Set(store.visibleMessages.map(\.platform)) == [.wechat],
            "平台筛选"
        )

        store.toggle(.wechat)
        expect(
            store.selectedPlatforms == Set(ChatPlatform.allCases),
            "恢复全部平台"
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let groups = store.groupedVisibleMessages(calendar: calendar)
        expect(groups.count == 1, "按日期分组")
        expect(
            groups[0].messages.map(\.sentAt) == groups[0].messages.map(\.sentAt).sorted(),
            "组内时间排序"
        )

        if let message = store.selectedMessages.first, let tag = store.tags.first {
            let wasSelected = message.tagIDs.contains(tag.id)
            store.toggleTag(tag, on: message)
            let updated = store.messages.first { $0.id == message.id }
            expect(
                updated?.tagIDs.contains(tag.id) == !wasSelected,
                "标签切换"
            )
        } else {
            failures.append("测试数据缺失")
        }

        let repositoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-memory-smoke-\(UUID().uuidString).json")
        let repository = ChatStoreRepository(fileURL: repositoryURL)
        var persistenceError: String?

        store.onDidChange = {
            do {
                try repository.save(store)
            } catch {
                persistenceError = "\(error)"
            }
        }

        store.addPerson(name: "沐沐", subtitle: "持久化测试")
        expect(
            Dictionary(grouping: store.importStatuses, by: \.platform)
                .values.allSatisfy { $0.count == 1 },
            "联系人创建不重复平台状态"
        )
        store.addMessage(
            platform: .douyin,
            sender: .me,
            text: "这是一条需要持久化的消息"
        )
        store.updateMessage(
            ChatMessage(
                id: messages[0].id,
                personID: person.id,
                platform: .wechat,
                sender: .peer,
                sentAt: messages[0].sentAt,
                text: "更新后的消息",
                tagIDs: [food.id]
            )
        )

        expect(persistenceError == nil, "JSON 写入")

        let restored = repository.load(seed: ChatStore(
            people: [],
            messages: [],
            tags: [],
            importStatuses: []
        ))
        expect(restored.people.contains { $0.name == "沐沐" }, "联系人恢复")
        expect(
            restored.messages.contains { $0.text == "这是一条需要持久化的消息" },
            "消息恢复"
        )
        expect(
            restored.messages.first { $0.id == messages[0].id }?.text == "更新后的消息",
            "消息更新恢复"
        )

        if let messageID = restored.messages.first(where: { $0.text == "这是一条需要持久化的消息" })?.id {
            restored.deleteMessage(id: messageID)
            expect(
                !restored.messages.contains { $0.id == messageID },
                "消息删除"
            )
        }

        try? FileManager.default.removeItem(at: repositoryURL)

        if failures.isEmpty {
            print("Domain smoke tests passed: 19/19")
        } else {
            print("Domain smoke tests failed:")
            failures.forEach { print(" - \($0)") }
            exit(1)
        }
    }
}

