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
            )
        ]
        let store = ChatStore(
            people: [person],
            messages: messages,
            tags: [food, travel],
            importStatuses: ChatPlatform.allCases.map {
                ImportStatus(platform: $0, lastUpdated: now, state: .fresh)
            }
        )

        store.searchText = "香菜"
        expect(store.visibleMessages.count == 1, "文本搜索")
        store.searchText = "旅行"
        expect(
            store.visibleMessages.count == 1 && store.visibleMessages[0].platform == .xiaohongshu,
            "标签搜索"
        )
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

        if failures.isEmpty {
            print("Domain smoke tests passed: 8/8")
        } else {
            print("Domain smoke tests failed:")
            failures.forEach { print(" - \($0)") }
            exit(1)
        }
    }
}

