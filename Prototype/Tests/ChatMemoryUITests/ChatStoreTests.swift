import XCTest
@testable import ChatMemoryDomain

final class ChatStoreTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func makeStore(now: Date = Date()) -> ChatStore {
        let person = ChatPerson(name: "小鹿", subtitle: "测试联系人")
        let food = ChatTag(name: "食物爱好", symbolName: "fork.knife", color: .coral)
        let travel = ChatTag(name: "旅行灵感", symbolName: "airplane", color: .sky)
        let messages = [
            ChatMessage(
                personID: person.id,
                platform: .wechat,
                sender: .peer,
                sentAt: now.addingTimeInterval(-60),
                text: "晚上想吃清淡一点，千万不要香菜！",
                tagIDs: [food.id]
            ),
            ChatMessage(
                personID: person.id,
                platform: .xiaohongshu,
                sender: .me,
                sentAt: now.addingTimeInterval(-120),
                text: "这家京都咖啡店看起来很适合我们明年去。",
                externalTitle: "京都咖啡地图",
                externalURL: "https://example.com",
                tagIDs: [travel.id]
            ),
            ChatMessage(
                personID: person.id,
                platform: .qq,
                sender: .peer,
                sentAt: now.addingTimeInterval(-180),
                text: "周五看展的票记得取。"
            )
        ]

        return ChatStore(
            people: [person],
            messages: messages,
            tags: [food, travel],
            importStatuses: ChatPlatform.allCases.map {
                ImportStatus(platform: $0, lastUpdated: now, state: .fresh)
            }
        )
    }

    func testSearchFiltersByTextAndTag() {
        let store = makeStore()

        store.searchText = "香菜"
        XCTAssertEqual(store.visibleMessages.count, 1)
        XCTAssertTrue(store.visibleMessages[0].text.contains("香菜"))

        store.searchText = "旅行"
        XCTAssertEqual(store.visibleMessages.count, 1)
        XCTAssertEqual(store.visibleMessages[0].platform, .xiaohongshu)

        store.searchText = ""
        XCTAssertEqual(store.visibleMessages.count, 3)
    }

    func testPlatformToggleNarrowsResults() {
        let store = makeStore()

        for platform in ChatPlatform.allCases where platform != .wechat {
            store.toggle(platform)
        }

        XCTAssertEqual(Set(store.visibleMessages.map(\.platform)), [.wechat])
    }

    func testTogglingLastPlatformRestoresAllPlatforms() {
        let store = makeStore()

        for platform in ChatPlatform.allCases where platform != .qq {
            store.toggle(platform)
        }
        XCTAssertEqual(store.selectedPlatforms, [.qq])

        store.toggle(.qq)
        XCTAssertEqual(store.selectedPlatforms, Set(ChatPlatform.allCases))
    }

    func testMessagesAreGroupedByDayAndSortedAscending() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = makeStore(now: now)

        let groups = store.groupedVisibleMessages(calendar: calendar)
        let group = try XCTUnwrap(groups.first)
        XCTAssertEqual(group.messages.count, 3)
        XCTAssertEqual(group.messages.map(\.sentAt), group.messages.map(\.sentAt).sorted())
        XCTAssertEqual(calendar.startOfDay(for: group.day), calendar.startOfDay(for: now))
    }

    func testTagToggleUpdatesMessage() throws {
        let store = makeStore()
        let message = try XCTUnwrap(store.selectedMessages.first)
        let tag = try XCTUnwrap(store.tags.first)
        let originallySelected = message.tagIDs.contains(tag.id)

        store.toggleTag(tag, on: message)
        let updated = try XCTUnwrap(store.messages.first { $0.id == message.id })

        XCTAssertEqual(updated.tagIDs.contains(tag.id), !originallySelected)
    }
}

