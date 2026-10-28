import Foundation
import ChatMemoryDomain
import SQLite3

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

        expect(persistenceError == nil, "JSON 写入\(persistenceError.map { "：\($0)" } ?? "")")

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

        let importer = RealChatImporter()
        let jsonURL = URL(fileURLWithPath: "/tmp/chatmemory-wechat-sample.json")
        let jsonData = Data("""
        {
          "data": {
            "messages": [
              {
                "msgId": "wx-1001",
                "createTime": 1800000000,
                "strContent": "不要香菜",
                "isMe": false,
                "platform": "微信"
              }
            ]
          }
        }
        """.utf8)

        do {
            let output = try importer.parse(data: jsonData, url: jsonURL)
            expect(output.records.count == 1, "微信 JSON 导入")
            expect(output.records.first?.platform == .wechat, "微信 JSON 平台")
            expect(output.records.first?.text == "不要香菜", "微信 JSON 内容")

            let importStore = ChatStore(
                people: [person],
                messages: [],
                tags: [food],
                importStatuses: []
            )
            let firstBatch = importStore.importRealRecords(
                output.records,
                personID: person.id,
                fileName: "wechat.json",
                format: output.format
            )
            let secondBatch = importStore.importRealRecords(
                output.records,
                personID: person.id,
                fileName: "wechat.json",
                format: output.format
            )
            expect(firstBatch?.importedCount == 1, "首次真实导入")
            expect(secondBatch?.importedCount == 0 && secondBatch?.skippedCount == 1, "重复导入去重")
            expect(
                importStore.messages.first?.sourceIdentifier == "chatmemory-wechat-sample.json:wx-1001",
                "导入来源标识：\(importStore.messages.first?.sourceIdentifier ?? "nil")"
            )
        } catch {
            failures.append("真实 JSON 导入：\(error)")
        }

        let htmlURL = URL(fileURLWithPath: "/tmp/chatmemory-qq-sample.mht")
        let htmlData = Data("""
        <html><body><h1>QQ 聊天记录</h1>
        <table>
          <tr><td>我</td><td>2026-10-28 10:00</td><td>看看这个 https://example.com</td></tr>
        </table></body></html>
        """.utf8)

        do {
            let htmlOutput = try importer.parse(data: htmlData, url: htmlURL)
            expect(htmlOutput.records.count == 1, "QQ HTML 导入")
            expect(htmlOutput.format == .qqHTMLArchive, "QQ HTML 格式")
            expect(htmlOutput.records.first?.externalURL == "https://example.com", "QQ HTML 链接")
        } catch {
            failures.append("QQ HTML 导入：\(error)")
        }

        let scanRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("chatmemory-scan-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Message", isDirectory: true)
        try? FileManager.default.createDirectory(at: scanRoot, withIntermediateDirectories: true)
        try? Data("SQLite format 3\0fixture".utf8).write(to: scanRoot.appendingPathComponent("Chat_test.db"))
        try? Data("encrypted-sqlcipher-fixture".utf8).write(to: scanRoot.appendingPathComponent("Chat_encrypted.db"))
        try? Data("not a database".utf8).write(to: scanRoot.appendingPathComponent("notes.txt"))

        let scanResult = ChatArchiveScanner().scanDirectories(
            at: [scanRoot.deletingLastPathComponent()],
            platform: .wechat,
            format: .wechatSQLite
        )
        expect(scanResult.archives.count == 2, "微信数据库扫描")
        expect(
            scanResult.archives.contains { $0.fileName == "Chat_test.db" && !$0.isEncrypted },
            "未加密微信数据库扫描"
        )
        expect(
            scanResult.archives.first?.reason == "微信 Message 目录",
            "微信扫描目录：\(scanResult.archives.first?.reason ?? "nil") / \(scanResult.archives.first?.relativePath ?? "nil")"
        )
        expect(
            scanResult.archives.contains { $0.fileName == "Chat_encrypted.db" && $0.isEncrypted },
            "加密微信数据库识别"
        )

        do {
            _ = try importer.parse(
                data: Data("encrypted-sqlcipher-fixture".utf8),
                url: URL(fileURLWithPath: "/tmp/message_encrypted.db")
            )
            failures.append("加密微信数据库应当拒绝导入")
        } catch {
            expect(!error.localizedDescription.isEmpty, "加密微信数据库错误提示")
        }

        let exportJSONURL = URL(fileURLWithPath: "/tmp/chatmemory-ydotdog.json")
        let exportJSONData = Data("""
        [
          {
            "time": "2026-10-28 10:00:00",
            "timestamp": 1792173600,
            "sender": "小鹿",
            "type": 1,
            "type_name": "文本",
            "content": "不要香菜",
            "server_id": "server-1001",
            "db": "message_0.db"
          }
        ]
        """.utf8)

        do {
            let output = try importer.parse(data: exportJSONData, url: exportJSONURL)
            expect(output.format == .wechatExportJSON, "开源微信导出格式识别")
            expect(output.records.count == 1, "开源微信导出 JSON 解析")
            expect(output.records.first?.text == "不要香菜", "开源微信导出内容")
            expect(output.records.first?.sender == .peer, "开源微信导出发送者")
            expect(
                output.records.first?.sourceIdentifier == "chatmemory-ydotdog.json:server-1001",
                "开源微信导出来源 ID：\(output.records.first?.sourceIdentifier ?? "nil")"
            )
        } catch {
            failures.append("开源微信导出 JSON：\(error)")
        }

        let decryptedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("chatmemory-decrypted-\(UUID().uuidString)", isDirectory: true)
        let decryptedContactURL = decryptedRoot
            .appendingPathComponent("contact/contact.db")
        let decryptedMessageURL = decryptedRoot
            .appendingPathComponent("message/message_0.db")
        try? FileManager.default.createDirectory(
            at: decryptedContactURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: decryptedMessageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var contactDatabase: OpaquePointer?
        sqlite3_open(decryptedContactURL.path, &contactDatabase)
        sqlite3_exec(contactDatabase, "CREATE TABLE contact(username TEXT, nick_name TEXT, remark TEXT, alias TEXT)", nil, nil, nil)
        sqlite3_exec(contactDatabase, "INSERT INTO contact VALUES('contact_user','小鹿','','')", nil, nil, nil)
        sqlite3_exec(contactDatabase, "INSERT INTO contact VALUES('wxid_self','我','','')", nil, nil, nil)
        sqlite3_close(contactDatabase)

        var messageDatabase: OpaquePointer?
        sqlite3_open(decryptedMessageURL.path, &messageDatabase)
        sqlite3_exec(messageDatabase, "CREATE TABLE Name2Id(rowid INTEGER PRIMARY KEY, user_name TEXT)", nil, nil, nil)
        sqlite3_exec(messageDatabase, "INSERT INTO Name2Id(rowid,user_name) VALUES(11,'contact_user')", nil, nil, nil)
        sqlite3_exec(messageDatabase, "INSERT INTO Name2Id(rowid,user_name) VALUES(12,'wxid_self')", nil, nil, nil)
        let contactHash = WechatDecryptedImporter.md5Hex("contact_user")
        sqlite3_exec(
            messageDatabase,
            "CREATE TABLE Msg_\(contactHash)(local_id INTEGER, server_id TEXT, local_type INTEGER, create_time INTEGER, real_sender_id INTEGER, message_content TEXT, source TEXT, WCDB_CT_message_content BLOB)",
            nil,
            nil,
            nil
        )
        sqlite3_exec(
            messageDatabase,
            "INSERT INTO Msg_\(contactHash) VALUES(1,'server-1',1,1800000000,12,'不要香菜','','')",
            nil,
            nil,
            nil
        )
        sqlite3_exec(
            messageDatabase,
            "INSERT INTO Msg_\(contactHash) VALUES(2,'server-2',1,1800000060,11,'不要花生','','')",
            nil,
            nil,
            nil
        )
        sqlite3_close(messageDatabase)

        do {
            let decryptedImport = try WechatDecryptedImporter().importDirectory(at: decryptedRoot)
            expect(decryptedImport.selfWxid == "wxid_self", "解密目录自我识别")
            expect(decryptedImport.conversations.count == 1, "解密目录会话导入")
            expect(decryptedImport.conversations.first?.messages.count == 2, "解密目录消息导入")
            expect(
                decryptedImport.conversations.first?.messages.first?.sourceIdentifier == "wechat-decrypt:message_0.db:Msg_\(contactHash):1",
                "解密目录来源标识"
            )

            let decryptedStore = ChatStore(
                people: [ChatPerson(name: "小鹿", subtitle: "微信 · contact_user")],
                messages: [],
                tags: [food],
                importStatuses: []
            )
            let decryptedBatch = decryptedStore.importWechatDecryptedDirectory(
                decryptedImport,
                fileName: "decrypted-wechat"
            )
            expect(decryptedBatch.importedCount == 2, "解密目录批量导入")
            expect(decryptedStore.messages.count == 2, "解密目录入库")
            expect(
                decryptedStore.messages.first?.sourceIdentifier == "wechat-decrypt:message_0.db:Msg_\(contactHash):1",
                "解密目录消息来源"
            )
        } catch {
            failures.append("解密微信目录导入：\(error)")
        }

        try? FileManager.default.removeItem(at: scanRoot.deletingLastPathComponent())
        try? FileManager.default.removeItem(at: decryptedRoot)

        try? FileManager.default.removeItem(at: repositoryURL)

        if failures.isEmpty {
            print("Domain smoke tests passed: 39/39")
        } else {
            print("Domain smoke tests failed:")
            failures.forEach { print(" - \($0)") }
            exit(1)
        }
    }
}

