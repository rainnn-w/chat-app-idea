import Foundation
import SwiftUI
import ChatMemoryDomain

enum MockChatData {
    static func makeStore(now: Date = Date()) -> ChatStore {
        let lulu = ChatPerson(
            name: "小鹿",
            subtitle: "微信 · QQ · 小红书 · 抖音",
            initials: "鹿"
        )
        let mumu = ChatPerson(
            name: "沐沐",
            subtitle: "微信 · 小红书",
            initials: "沐"
        )

        let food = ChatTag(name: "食物爱好", symbolName: "fork.knife", color: .coral)
        let promise = ChatTag(name: "一起要做", symbolName: "sparkles", color: .lavender)
        let todo = ChatTag(name: "TODO", symbolName: "checklist", color: .mint)
        let travel = ChatTag(name: "旅行灵感", symbolName: "airplane", color: .sky)
        let gift = ChatTag(name: "礼物灵感", symbolName: "gift", color: .honey)
        let tags = [food, promise, todo, travel, gift]

        let messages: [ChatMessage] = [
            ChatMessage(
                personID: lulu.id,
                platform: .wechat,
                sender: .peer,
                sentAt: now.addingTimeInterval(-60 * 42),
                text: "晚上想吃清淡一点，千万不要香菜！",
                tagIDs: [food.id],
                isFavorite: true
            ),
            ChatMessage(
                personID: lulu.id,
                platform: .xiaohongshu,
                sender: .me,
                sentAt: now.addingTimeInterval(-60 * 105),
                text: "这家京都咖啡店看起来很适合我们明年去，记得收藏。",
                externalTitle: "京都 · 河边咖啡地图",
                externalURL: "https://www.xiaohongshu.com/explore/demo",
                tagIDs: [travel.id, promise.id]
            ),
            ChatMessage(
                personID: lulu.id,
                platform: .qq,
                sender: .peer,
                sentAt: now.addingTimeInterval(-60 * 190),
                text: "我把展览门票信息发你，周五晚上记得提醒我取票。",
                tagIDs: [todo.id]
            ),
            ChatMessage(
                personID: lulu.id,
                platform: .douyin,
                sender: .me,
                sentAt: now.addingTimeInterval(-60 * 260),
                text: "这个乐队巡演视频太好了，如果来上海我们就去！",
                externalTitle: "乐队 2027 巡演预告",
                externalURL: "https://www.douyin.com/video/demo",
                tagIDs: [promise.id]
            ),
            ChatMessage(
                personID: lulu.id,
                platform: .wechat,
                sender: .peer,
                sentAt: now.addingTimeInterval(-60 * 380),
                text: "你上次说的那本摄影集，我记在礼物清单里了。",
                tagIDs: [gift.id]
            ),
            ChatMessage(
                personID: mumu.id,
                platform: .wechat,
                sender: .peer,
                sentAt: now.addingTimeInterval(-60 * 55),
                text: "周六下午去逛市集吧，顺便看那家新开的甜品店。",
                tagIDs: [promise.id]
            ),
            ChatMessage(
                personID: mumu.id,
                platform: .xiaohongshu,
                sender: .me,
                sentAt: now.addingTimeInterval(-60 * 125),
                text: "这套秋日穿搭分享给你，颜色很像上次买的外套。",
                externalTitle: "温柔秋日通勤穿搭",
                externalURL: "https://www.xiaohongshu.com/explore/demo"
            )
        ]

        let statuses = ChatPlatform.allCases.map { platform in
            ImportStatus(
                platform: platform,
                lastUpdated: now.addingTimeInterval(platform == .qq ? -43_200 : -2_400),
                state: platform == .qq ? .stale : .fresh
            )
        }

        return ChatStore(
            people: [lulu, mumu],
            messages: messages,
            tags: tags,
            importStatuses: statuses
        )
    }
}

