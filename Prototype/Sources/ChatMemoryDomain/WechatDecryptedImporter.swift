import Foundation
import SQLite3
import CryptoKit

public struct WechatDecryptedContact: Identifiable, Hashable {
    public var id: String { username }
    public var username: String
    public var nickname: String
    public var remark: String
    public var alias: String
}

public struct WechatDecryptedMessage: Identifiable, Hashable {
    public var id: String
    public var conversationUsername: String
    public var senderWxid: String
    public var senderName: String
    public var sentAt: Date
    public var text: String
    public var messageType: Int
    public var sourceIdentifier: String
}

public struct WechatDecryptedConversation: Identifiable, Hashable {
    public var id: String
    public var username: String
    public var displayName: String
    public var nickname: String
    public var messages: [WechatDecryptedMessage]
}

public struct WechatDecryptedDirectoryImport {
    public var contacts: [WechatDecryptedContact]
    public var conversations: [WechatDecryptedConversation]
    public var warnings: [String]
    public var selfWxid: String?
}

public struct WechatDecryptedImporter {
    private let fileManager: FileManager

    public static func md5Hex(_ value: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func importDirectory(at root: URL) throws -> WechatDecryptedDirectoryImport {
        let messageDirectory = root.appendingPathComponent("message", isDirectory: true)
        let contactURL = root.appendingPathComponent("contact/contact.db")

        var warnings: [String] = []
        let contacts = fileManager.isReadableFile(atPath: contactURL.path)
            ? (try? readContacts(from: contactURL)) ?? []
            : []
        let selfWxid = contacts.first { $0.username.hasPrefix("wxid_") }.map(\.username)
        let messageURLs = messageDatabaseURLs(in: messageDirectory)

        if messageURLs.isEmpty {
            warnings.append("没有找到 message/message_*.db。")
        }
        if contacts.isEmpty {
            warnings.append("没有读取到 contact/contact.db，部分联系人会显示为 username。")
        }

        var conversations: [WechatDecryptedConversation] = []

        for messageURL in messageURLs {
            do {
                let conversationsInDatabase = try readConversations(
                    from: messageURL,
                    contacts: contacts,
                    selfWxid: selfWxid
                )
                conversations.append(contentsOf: conversationsInDatabase)
            } catch {
                warnings.append("\(messageURL.lastPathComponent)：\(error.localizedDescription)")
            }
        }

        return WechatDecryptedDirectoryImport(
            contacts: contacts,
            conversations: conversations.sorted { $0.username < $1.username },
            warnings: warnings,
            selfWxid: selfWxid
        )
    }
}

private extension WechatDecryptedImporter {
    func messageDatabaseURLs(in directory: URL) -> [URL] {
        let files = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return files.filter { url in
            let name = url.lastPathComponent.lowercased()
            return name.hasPrefix("message_")
                && name.hasSuffix(".db")
                && !name.contains("fts")
                && !name.contains("media")
                && !name.contains("resource")
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func readContacts(from url: URL) throws -> [WechatDecryptedContact] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let message = database.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "无法打开数据库"
            sqlite3_close_v2(database)
            throw ImportError(message: "无法打开 contact.db：\(message)")
        }
        defer { sqlite3_close_v2(database) }

        guard let database else { return [] }
        let sql = """
        SELECT username, nick_name, remark, alias
        FROM contact
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var contacts: [WechatDecryptedContact] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let username = SQLiteRow.text(statement, 0)
            guard !username.isEmpty else { continue }
            contacts.append(
                WechatDecryptedContact(
                    username: username,
                    nickname: SQLiteRow.text(statement, 1),
                    remark: SQLiteRow.text(statement, 2),
                    alias: SQLiteRow.text(statement, 3)
                )
            )
        }
        return contacts
    }

    func readConversations(
        from url: URL,
        contacts: [WechatDecryptedContact],
        selfWxid: String?
    ) throws -> [WechatDecryptedConversation] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let message = database.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "无法打开数据库"
            sqlite3_close_v2(database)
            throw ImportError(message: "无法打开 \(url.lastPathComponent)：\(message)")
        }
        defer { sqlite3_close_v2(database) }

        guard let database else { return [] }

        let tableNames = SQLiteRow.tableNames(database)
        guard !tableNames.isEmpty else { return [] }

        let name2ID = SQLiteRow.name2ID(database)
        let contactByTableHash = Dictionary(
            uniqueKeysWithValues: contacts.map {
                (SQLiteRow.md5($0.username), $0)
            }
        )

        var conversations: [WechatDecryptedConversation] = []

        for tableName in tableNames {
            let conversationUsername = contactByTableHash[tableName]
                .map(\.username)
                ?? String(tableName.dropFirst("Msg_".count))
            let contact = contactByTableHash[tableName]
            let displayName = contact?.remark
                ?? contact?.nickname
                ?? contact?.alias
                ?? conversationUsername

            let sql = """
            SELECT rowid AS chatmemory_rowid, *
            FROM "\(tableName.replacingOccurrences(of: "\"", with: "\"\""))"
            ORDER BY create_time ASC
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
                continue
            }
            defer { sqlite3_finalize(statement) }

            let columnNames = (0..<sqlite3_column_count(statement)).map {
                String(cString: sqlite3_column_name(statement, $0)).lowercased()
            }

            func columnIndex(_ names: [String]) -> Int? {
                columnNames.firstIndex { name in names.contains(name) }
            }

            let localIDIndex = columnIndex(["local_id", "localid"])
            let createTimeIndex = columnIndex(["create_time", "createtime"])
            let realSenderIndex = columnIndex(["real_sender_id", "real_sender"])
            let contentIndex = columnIndex(["message_content", "content", "strcontent"])
            let typeIndex = columnIndex(["local_type", "type"])

            guard let contentIndex else { continue }

            var messages: [WechatDecryptedMessage] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                let rowIDIndex = columnNames.firstIndex(of: "chatmemory_rowid")
                let rowID = rowIDIndex.flatMap { SQLiteRow.int(statement, $0) } ?? 0
                let localID = localIDIndex.flatMap { SQLiteRow.int(statement, $0) } ?? rowID
                let createTime = createTimeIndex.flatMap { SQLiteRow.int(statement, $0) } ?? 0
                let realSenderID = realSenderIndex.flatMap { SQLiteRow.int(statement, $0) } ?? -1
                let messageType = typeIndex.flatMap { SQLiteRow.int(statement, $0) } ?? 0
                let content = SQLiteRow.text(statement, contentIndex)

                let senderWxid = name2ID[realSenderID] ?? ""
                let sender: MessageSender = senderWxid == selfWxid ? .me : .peer
                let cleanedText = SQLiteRow.cleanMessage(content, messageType: messageType)
                let text = cleanedText.isEmpty
                    ? SQLiteRow.messagePlaceholder(messageType)
                    : cleanedText

                messages.append(
                    WechatDecryptedMessage(
                        id: UUID().uuidString,
                        conversationUsername: conversationUsername,
                        senderWxid: senderWxid,
                        senderName: contactByTableHash[tableName]?.nickname ?? senderWxid,
                        sentAt: Date(timeIntervalSince1970: TimeInterval(createTime)),
                        text: text,
                        messageType: messageType,
                        sourceIdentifier: "wechat-decrypt:\(url.lastPathComponent):\(tableName):\(localID)"
                    )
                )
            }

            if !messages.isEmpty {
                conversations.append(
                    WechatDecryptedConversation(
                        id: "\(url.lastPathComponent):\(tableName)",
                        username: conversationUsername,
                        displayName: displayName,
                        nickname: contact?.nickname ?? conversationUsername,
                        messages: messages.sorted { $0.sentAt < $1.sentAt }
                    )
                )
            }
        }

        return conversations
    }
}

private struct SQLiteRow {
    static func tableNames(_ database: OpaquePointer) -> [String] {
        var statement: OpaquePointer?
        let sql = "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'Msg_%'"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }
        var names: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            names.append(text(statement, 0))
        }
        return names
    }

    static func name2ID(_ database: OpaquePointer) -> [Int: String] {
        var statement: OpaquePointer?
        let sql = "SELECT rowid, user_name FROM Name2Id"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }

        var mapping: [Int: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int64(statement, 0))
            let username = text(statement, 1)
            mapping[id] = username
        }
        return mapping
    }

    static func text(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cString)
    }

    static func text(_ statement: OpaquePointer?, _ index: Int) -> String {
        text(statement, Int32(index))
    }

    static func int(_ statement: OpaquePointer?, _ index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(statement, index))
    }

    static func int(_ statement: OpaquePointer?, _ index: Int) -> Int? {
        int(statement, Int32(index))
    }

    static let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    static func md5(_ value: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func cleanMessage(_ text: String, messageType: Int) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("<msg>") || value.contains("<appmsg>") {
            let title = xmlValue("title", in: value)
            let url = xmlValue("url", in: value)
            if let title {
                value = url == nil ? title : "\(title)\n\(url!)"
            }
        }

        return value
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func messagePlaceholder(_ messageType: Int) -> String {
        switch messageType {
        case 3: "[图片]"
        case 34: "[语音]"
        case 43: "[视频]"
        case 47: "[表情]"
        case 48: "[位置]"
        case 49: "[链接 / 文件 / 小程序]"
        case 50: "[通话]"
        default: "[消息]"
        }
    }

    static func xmlValue(_ name: String, in text: String) -> String? {
        let regex = try? NSRegularExpression(
            pattern: "<\(name)[^>]*>(.*?)</\(name)>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        )
        guard let regex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[range])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }
}

