import Foundation
import SQLite3

public enum ImportFormat: String, Codable, Hashable, CaseIterable {
    case wechatSQLite
    case qqHTMLArchive
    case xiaohongshuExport
    case douyinExport
    case genericJSON

    public var title: String {
        switch self {
        case .wechatSQLite: "微信本地数据库"
        case .qqHTMLArchive: "QQ 网页归档"
        case .xiaohongshuExport: "小红书导出数据"
        case .douyinExport: "抖音导出数据"
        case .genericJSON: "通用聊天 JSON"
        }
    }

    public var guidance: String {
        switch self {
        case .wechatSQLite:
            "选择微信 Mac/iOS 备份中的 Message/*.db SQLite 文件。若数据库已加密，需要先使用官方备份或可信工具解密。"
        case .qqHTMLArchive:
            "选择 QQ 导出的 .mht / .html 聊天归档。"
        case .xiaohongshuExport:
            "选择小红书账号数据导出的 JSON / NDJSON / HTML 文件。"
        case .douyinExport:
            "选择抖音账号数据导出的 JSON / NDJSON / HTML 文件。"
        case .genericJSON:
            "选择包含 messages、data、items 或 records 数组的聊天 JSON 文件。"
        }
    }
}

public struct RawImportRecord: Identifiable, Hashable {
    public var id: UUID
    public var platform: ChatPlatform
    public var sender: MessageSender
    public var sentAt: Date
    public var text: String
    public var externalTitle: String?
    public var externalURL: String?
    public var sourceIdentifier: String
    public var confidence: Double

    public init(
        id: UUID = UUID(),
        platform: ChatPlatform,
        sender: MessageSender,
        sentAt: Date,
        text: String,
        externalTitle: String? = nil,
        externalURL: String? = nil,
        sourceIdentifier: String,
        confidence: Double = 0.95
    ) {
        self.id = id
        self.platform = platform
        self.sender = sender
        self.sentAt = sentAt
        self.text = text
        self.externalTitle = externalTitle
        self.externalURL = externalURL
        self.sourceIdentifier = sourceIdentifier
        self.confidence = confidence
    }

    public var stableKey: String {
        [
            platform.rawValue,
            String(sentAt.timeIntervalSince1970),
            text.lowercased(),
            externalTitle?.lowercased() ?? "",
            externalURL?.lowercased() ?? ""
        ].joined(separator: "|")
    }

    public var dedupSignature: String {
        let normalizedText = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()

        return [
            platform.rawValue,
            String(sentAt.timeIntervalSince1970),
            normalizedText,
            externalTitle?.lowercased() ?? "",
            externalURL?.lowercased() ?? ""
        ].joined(separator: "|")
    }

    func makeMessage(personID: UUID, batchID: UUID) -> ChatMessage {
        ChatMessage(
            personID: personID,
            platform: platform,
            sender: sender,
            sentAt: sentAt,
            text: text,
            externalTitle: externalTitle,
            externalURL: externalURL,
            sourceIdentifier: sourceIdentifier,
            importBatchID: batchID,
            confidence: confidence
        )
    }
}

public struct ImportOutput {
    public var records: [RawImportRecord]
    public var format: ImportFormat
    public var warnings: [String]
}

public struct RealChatImporter {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterWithoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateFormats: [DateFormatter] = [
        makeDateFormat("yyyy-MM-dd HH:mm:ss"),
        makeDateFormat("yyyy-MM-dd HH:mm"),
        makeDateFormat("yyyy/MM/dd HH:mm:ss"),
        makeDateFormat("yyyy/MM/dd HH:mm"),
        makeDateFormat("yyyy年M月d日 HH:mm:ss"),
        makeDateFormat("yyyy年M月d日 HH:mm"),
        makeDateFormat("yyyy-MM-dd'T'HH:mm:ss")
    ]

    private static func makeDateFormat(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    public init() {}

    public func detectFormat(url: URL, data: Data) -> ImportFormat {
        let ext = url.pathExtension.lowercased()
        if ["db", "sqlite", "sqlite3", "db3"].contains(ext) {
            return .wechatSQLite
        }

        let sample = String(decoding: data.prefix(2_000_000), as: UTF8.self).lowercased()
        if ext == "json" || ext == "ndjson" || sample.hasPrefix("{") || sample.hasPrefix("[") {
            if sample.contains("xiaohongshu") || sample.contains("小红书") || sample.contains("note") {
                return .xiaohongshuExport
            }
            if sample.contains("douyin") || sample.contains("抖音") || sample.contains("aweme") {
                return .douyinExport
            }
            return .genericJSON
        }

        if ["html", "htm", "mht", "mhtml"].contains(ext) {
            if sample.contains("xiaohongshu") || sample.contains("小红书") {
                return .xiaohongshuExport
            }
            if sample.contains("douyin") || sample.contains("抖音") {
                return .douyinExport
            }
            return .qqHTMLArchive
        }

        return .genericJSON
    }

    public func parse(data: Data, url: URL) throws -> ImportOutput {
        let format = detectFormat(url: url, data: data)

        switch format {
        case .wechatSQLite:
            return try parseSQLite(data: data, url: url, platform: .wechat)
        case .genericJSON, .xiaohongshuExport, .douyinExport:
            return try parseJSON(data: data, url: url, fallbackPlatform: format.fallbackPlatform)
        case .qqHTMLArchive:
            return parseHTMLArchive(data: data, url: url)
        }
    }
}

extension ImportFormat {
    var fallbackPlatform: ChatPlatform {
        switch self {
        case .xiaohongshuExport: .xiaohongshu
        case .douyinExport: .douyin
        case .qqHTMLArchive: .qq
        default: .wechat
        }
    }
}

private extension RealChatImporter {
    func parseJSON(data: Data, url: URL, fallbackPlatform: ChatPlatform) throws -> ImportOutput {
        let text = String(decoding: data, as: UTF8.self)
        var warnings: [String] = []
        var objects: [[String: Any]] = []

        if let object = try? JSONSerialization.jsonObject(with: data) {
            collectObjects(from: object, into: &objects)
        } else {
            let decoder = JSONDecoder()
            let lines = text.components(separatedBy: .newlines)
            for line in lines where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let lineData = line.data(using: .utf8),
                      let object = try? decoder.decode([String: AnyDecodableValue].self, from: lineData) else {
                    continue
                }
                objects.append(object.mapValues(\.anyValue))
            }
            if objects.isEmpty {
                warnings.append("JSON 结构无法识别，未找到对象数组。")
            }
        }

        let records = objects.compactMap {
            record(fromObject: $0, fallbackPlatform: fallbackPlatform, sourcePrefix: url.lastPathComponent)
        }

        return ImportOutput(records: records, format: exportFormat(for: fallbackPlatform), warnings: warnings)
    }

    func recordStableKey(
        platform: ChatPlatform,
        sender: MessageSender,
        date: Date,
        text: String
    ) -> String {
        [
            platform.rawValue,
            String(date.timeIntervalSince1970),
            text.lowercased(),
            sender.rawValue
        ].joined(separator: "|")
    }

    func parseSQLite(data: Data, url: URL, platform: ChatPlatform) throws -> ImportOutput {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chatmemory-import-\(UUID().uuidString)-\(url.lastPathComponent)")
        try data.write(to: temporaryURL)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        var database: OpaquePointer?
        guard sqlite3_open_v2(
            temporaryURL.path,
            &database,
            SQLITE_OPEN_READONLY,
            nil
        ) == SQLITE_OK else {
            let message = database.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "无法打开数据库"
            sqlite3_close_v2(database)
            throw ImportError(message: "无法打开 SQLite 数据库：\(message)")
        }
        defer { sqlite3_close_v2(database) }

        guard let database else {
            throw ImportError(message: "数据库句柄无效。")
        }

        let tableNames = sqliteTableNames(database)
        var records: [RawImportRecord] = []
        var warnings: [String] = []

        for table in tableNames {
            let quotedTable = table.replacingOccurrences(of: "\"", with: "\"\"")
            let sql = "SELECT rowid AS chatmemory_rowid, * FROM \"\(quotedTable)\""
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
                continue
            }
            defer { sqlite3_finalize(statement) }

            let columns = (0..<sqlite3_column_count(statement)).map { index in
                String(cString: sqlite3_column_name(statement, index)).lowercased()
            }

            let contentIndex = columns.firstIndex {
                ["strcontent", "content", "message", "msg", "text", "msgcontent"].contains($0)
            }
            let dateIndex: Int? = columns.firstIndex {
                ["createtime", "create_time", "msgcreatetime", "timestamp", "time", "sentat", "sent_at"].contains($0)
            }
            let directionIndex: Int? = columns.firstIndex {
                ["issender", "is_sender", "isme", "is_me", "des", "direction", "sendertype", "sender_type"].contains($0)
            }
            let senderIndex: Int? = columns.firstIndex {
                ["talker", "sender", "sendername", "sender_name", "username", "user_name"].contains($0)
            }
            let typeIndex: Int? = columns.firstIndex {
                ["type", "msgtype", "msg_type", "messagetype"].contains($0)
            }

            guard let contentIndex else { continue }

            while sqlite3_step(statement) == SQLITE_ROW {
                let rawContent = sqliteText(statement, contentIndex)
                let messageType = typeIndex.flatMap { sqliteInt(statement, $0) }
                let cleaned = cleanMessageText(rawContent, messageType: messageType)
                guard !cleaned.isEmpty else { continue }

                let timestamp = dateIndex.flatMap { sqliteDate(statement, $0) } ?? Date.distantPast
                let direction = directionIndex.map { sqliteText(statement, $0) }
                let senderName = senderIndex.map { sqliteText(statement, $0) }

                var title: String?
                var externalURL: String?
                if rawContent.contains("<msg>") || rawContent.contains("<title>") {
                    title = xmlValue("title", in: rawContent)
                    externalURL = xmlValue("url", in: rawContent)
                }

                let sourceID = columns.firstIndex(of: "chatmemory_rowid")
                    .flatMap { sqliteInt(statement, $0) }
                    .map(String.init) ?? rawContent.hashValue.description

                records.append(
                    RawImportRecord(
                        platform: platform,
                        sender: senderValue(direction: direction, senderName: senderName, fallback: .peer),
                        sentAt: timestamp,
                        text: cleaned,
                        externalTitle: title,
                        externalURL: externalURL,
                        sourceIdentifier: "\(url.lastPathComponent):\(table):\(sourceID)",
                        confidence: 0.97
                    )
                )
            }
        }

        if tableNames.isEmpty {
            warnings.append("SQLite 文件中没有数据表，可能不是微信消息库。")
        }
        if records.isEmpty && !tableNames.isEmpty {
            warnings.append("已扫描 SQLite 表，但没有匹配到消息列。")
        }

        return ImportOutput(
            records: records.sorted { $0.sentAt < $1.sentAt },
            format: .wechatSQLite,
            warnings: warnings
        )
    }

    func sqliteTableNames(_ database: OpaquePointer) -> [String] {
        var statement: OpaquePointer?
        let sql = "SELECT name FROM sqlite_master WHERE type = 'table'"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var names: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let cString = sqlite3_column_text(statement, 0) else { continue }
            names.append(String(cString: cString))
        }
        return names
    }

    func sqliteText(_ statement: OpaquePointer, _ index: Int) -> String {
        guard let cString = sqlite3_column_text(statement, Int32(index)) else { return "" }
        return String(cString: cString)
    }

    func sqliteInt(_ statement: OpaquePointer, _ index: Int) -> Int? {
        guard sqlite3_column_type(statement, Int32(index)) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(statement, Int32(index)))
    }

    func sqliteDate(_ statement: OpaquePointer, _ index: Int) -> Date? {
        guard sqlite3_column_type(statement, Int32(index)) != SQLITE_NULL else { return nil }
        let type = sqlite3_column_type(statement, Int32(index))

        if type == SQLITE_INTEGER || type == SQLITE_FLOAT {
            let value = sqlite3_column_double(statement, Int32(index))
            if value > 10_000_000_000 {
                return Date(timeIntervalSince1970: value / 1000)
            }
            return Date(timeIntervalSince1970: value)
        }

        let text = sqliteText(statement, index)
        return parseDate(text)
    }

    func parseHTMLArchive(data: Data, url: URL) -> ImportOutput {
        let sample = String(decoding: data.prefix(200), as: UTF8.self).lowercased()
        let fullText = String(decoding: data, as: UTF8.self)
        let decoded = sample.contains("quoted-printable") ? decodeQuotedPrintable(fullText) : fullText
        let format: ImportFormat = decoded.lowercased().contains("xiaohongshu")
            ? .xiaohongshuExport
            : decoded.lowercased().contains("douyin") ? .douyinExport : .qqHTMLArchive

        var records = parseHTMLTableRows(decoded, url: url, fallbackPlatform: format.fallbackPlatform)
        if records.isEmpty {
            records = parseJSONScripts(in: decoded, url: url, fallbackPlatform: format.fallbackPlatform)
        }
        if records.isEmpty {
            records = parseMetadataRecord(decoded, url: url, format: format)
        }

        let warnings = records.isEmpty
            ? ["HTML/MHT 已解析，但没有识别到聊天表格或嵌入 JSON。"]
            : []

        return ImportOutput(
            records: records.sorted { $0.sentAt < $1.sentAt },
            format: format,
            warnings: warnings
        )
    }

    func parseHTMLTableRows(
        _ html: String,
        url: URL,
        fallbackPlatform: ChatPlatform
    ) -> [RawImportRecord] {
        let rowRegex = try? NSRegularExpression(
            pattern: "<tr[^>]*>(.*?)</tr>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        )
        let cellRegex = try? NSRegularExpression(
            pattern: "<t[dh][^>]*>(.*?)</t[dh]>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        )
        guard let rowRegex, let cellRegex else { return [] }

        let rowRange = NSRange(html.startIndex..., in: html)
        let rowMatches = rowRegex.matches(in: html, range: rowRange)
        var records: [RawImportRecord] = []

        for match in rowMatches.reversed() {
            guard let rowRange = Range(match.range(at: 1), in: html) else { continue }
            let row = String(html[rowRange])
            let cellMatches = cellRegex.matches(in: row, range: NSRange(row.startIndex..., in: row))
            let cells = cellMatches.compactMap { match -> String? in
                guard let range = Range(match.range(at: 1), in: row) else { return nil }
                return cleanHTML(String(row[range]))
            }
            .filter { !$0.isEmpty }

            guard cells.count >= 3,
                  let dateIndex = cells.lastIndex(where: { parseDate($0) != nil }),
                  dateIndex > 0 else {
                continue
            }

            let date = parseDate(cells[dateIndex]) ?? Date.distantPast
            let senderCell = cells[dateIndex - 1]
            let contentCandidates = cells.enumerated()
                .filter { $0.offset != dateIndex && $0.offset != dateIndex - 1 }
                .map(\.element)
            guard let content = contentCandidates.max(by: { $0.count < $1.count }),
                  !content.isEmpty else {
                continue
            }

            let detectedURL = firstHTTPURL(content)
            records.append(
                RawImportRecord(
                    platform: fallbackPlatform,
                    sender: senderValue(text: senderCell, fallback: .peer),
                    sentAt: date,
                    text: content,
                    externalURL: detectedURL?.absoluteString,
                    sourceIdentifier: "\(url.lastPathComponent):row-\(records.count):\(date.timeIntervalSince1970):\(content.hashValue)",
                    confidence: 0.84
                )
            )
        }

        return records
    }

    func parseJSONScripts(
        in html: String,
        url: URL,
        fallbackPlatform: ChatPlatform
    ) -> [RawImportRecord] {
        let regex = try? NSRegularExpression(
            pattern: "<script[^>]*>(.*?)</script>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        )
        guard let regex else { return [] }

        var objects: [[String: Any]] = []
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let content = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            let jsonText = content
                .replacingOccurrences(of: "window.__INITIAL_STATE__\\s*=\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: ";$", with: "", options: [.regularExpression, .anchored])
            guard let data = jsonText.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) else {
                continue
            }
            collectObjects(from: object, into: &objects)
        }

        return objects.compactMap {
            record(fromObject: $0, fallbackPlatform: fallbackPlatform, sourcePrefix: url.lastPathComponent)
        }
    }

    func parseMetadataRecord(
        _ html: String,
        url: URL,
        format: ImportFormat
    ) -> [RawImportRecord] {
        let title = htmlMetaValue("og:title", in: html)
            ?? htmlMetaValue("twitter:title", in: html)
            ?? htmlTagValue("title", in: html)
        let link = htmlMetaValue("og:url", in: html) ?? url.absoluteString
        guard let title, !title.isEmpty else { return [] }

        return [
            RawImportRecord(
                platform: format.fallbackPlatform,
                sender: .peer,
                sentAt: Date.distantPast,
                text: title,
                externalTitle: title,
                externalURL: link,
                sourceIdentifier: "html-meta:\(url.absoluteString):\(title)",
                confidence: 0.62
            )
        ]
    }

    func collectObjects(from value: Any, into result: inout [[String: Any]]) {
        switch value {
        case let dictionary as [String: Any]:
            if isMessageLike(dictionary) {
                result.append(dictionary)
            }
            dictionary.values.forEach { collectObjects(from: $0, into: &result) }
        case let array as [Any]:
            array.forEach { collectObjects(from: $0, into: &result) }
        default:
            break
        }
    }

    func isMessageLike(_ dictionary: [String: Any]) -> Bool {
        let text = stringValue(
            in: dictionary,
            keys: ["text", "content", "message", "msg", "strContent", "str_content", "desc"]
        )
        let time = numberValue(
            in: dictionary,
            keys: ["timestamp", "createTime", "create_time", "msgCreateTime", "time", "sentAt", "sent_at"]
        )
        let sender = stringValue(
            in: dictionary,
            keys: ["sender", "senderName", "sender_name", "talker", "userName", "user_name", "des", "direction"]
        )
        return !text.isEmpty && (time != nil || !sender.isEmpty)
    }

    func record(
        fromObject dictionary: [String: Any],
        fallbackPlatform: ChatPlatform,
        sourcePrefix: String
    ) -> RawImportRecord? {
        let rawText = stringValue(
            in: dictionary,
            keys: ["text", "content", "message", "msg", "strContent", "str_content", "desc"]
        )
        let cleanedText = cleanMessageText(rawText)
        guard !cleanedText.isEmpty else { return nil }

        let date = dateValue(
            in: dictionary,
            keys: ["timestamp", "createTime", "create_time", "msgCreateTime", "time", "sentAt", "sent_at"]
        ) ?? Date.distantPast
        let sender = senderValue(in: dictionary, fallback: .peer)
        let externalURL = firstHTTPURL(
            stringValue(in: dictionary, keys: ["url", "link", "shareUrl", "share_url", "webpageUrl", "webpage_url"])
        ) ?? firstHTTPURL(cleanedText)
        var title: String? = stringValue(in: dictionary, keys: ["title", "notice", "appTitle", "app_title"])
        if title == nil, let externalURL {
            title = externalURL.host
        }

        let platformName = stringValue(in: dictionary, keys: ["platform", "source", "app", "channel"]).lowercased()
        let platform = importPlatform(from: platformName, fallback: fallbackPlatform)
        let sourceID: String? = stringValue(in: dictionary, keys: ["id", "msgId", "msg_id", "messageId", "message_id", "recordId", "record_id"])

        return RawImportRecord(
            platform: platform,
            sender: sender,
            sentAt: date,
            text: cleanedText,
            externalTitle: title,
            externalURL: externalURL?.absoluteString,
            sourceIdentifier: "\(sourcePrefix):\(sourceID ?? recordStableKey(platform: platform, sender: sender, date: date, text: cleanedText))",
            confidence: 0.94
        )
    }

    func importPlatform(from text: String, fallback: ChatPlatform) -> ChatPlatform {
        if text.contains("wechat") || text.contains("微信") {
            return .wechat
        }
        if text == "qq" || text.contains("tencent qq") {
            return .qq
        }
        if text.contains("xiaohongshu") || text.contains("xhs") || text.contains("小红书") || text.contains("rednote") {
            return .xiaohongshu
        }
        if text.contains("douyin") || text.contains("抖音") || text.contains("tiktok") {
            return .douyin
        }
        return fallback
    }

    func senderValue(direction: String?, senderName: String?, fallback: MessageSender) -> MessageSender {
        let normalized = (direction ?? senderName ?? "").lowercased()
        if ["1", "true", "me", "self", "send", "sender", "out"].contains(normalized) {
            return .me
        }
        if ["0", "false", "peer", "receive", "received", "in"].contains(normalized) {
            return .peer
        }
        if normalized.contains("system") || normalized.contains("系统") {
            return .system
        }
        if (senderName ?? "").contains("我") {
            return .me
        }
        return fallback
    }

    func senderValue(text: String, fallback: MessageSender) -> MessageSender {
        if text.contains("我") || text.lowercased().contains("me") || text.lowercased().contains("self") {
            return .me
        }
        if text.lowercased().contains("system") || text.contains("系统") {
            return .system
        }
        return fallback
    }

    func senderValue(in dictionary: [String: Any], fallback: MessageSender) -> MessageSender {
        let direction = stringValue(
            in: dictionary,
            keys: ["isMe", "is_me", "isSender", "is_sender", "des", "direction", "senderType", "sender_type"]
        )
        let senderName = stringValue(
            in: dictionary,
            keys: ["sender", "senderName", "sender_name", "talker", "userName", "user_name"]
        )
        return senderValue(direction: direction, senderName: senderName, fallback: fallback)
    }

    func stringValue(in dictionary: [String: Any], keys: [String]) -> String {
        for key in keys {
            guard let value = dictionary.first(where: { $0.key.lowercased() == key.lowercased() }).map(\.value) else {
                continue
            }
            switch value {
            case let string as String where !string.isEmpty:
                return string
            case let number as NSNumber:
                return number.stringValue
            default:
                continue
            }
        }
        return ""
    }

    func numberValue(in dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            guard let value = dictionary.first(where: { $0.key.lowercased() == key.lowercased() }).map(\.value) else {
                continue
            }
            switch value {
            case let number as NSNumber:
                return number.doubleValue
            case let string as String:
                return Double(string)
            default:
                continue
            }
        }
        return nil
    }

    func dateValue(in dictionary: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            guard let value = dictionary.first(where: { $0.key.lowercased() == key.lowercased() }).map(\.value) else {
                continue
            }
            if let number = value as? NSNumber {
                return date(fromUnix: number.doubleValue)
            }
            if let string = value as? String, let date = parseDate(string) {
                return date
            }
        }
        return nil
    }

    func date(fromUnix value: Double) -> Date {
        value > 10_000_000_000
            ? Date(timeIntervalSince1970: value / 1000)
            : Date(timeIntervalSince1970: value)
    }

    func parseDate(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let timestamp = Double(trimmed) {
            return date(fromUnix: timestamp)
        }
        if let date = Self.isoFormatter.date(from: trimmed) {
            return date
        }
        if let date = Self.isoFormatterWithoutFraction.date(from: trimmed) {
            return date
        }
        return Self.dateFormats.lazy.compactMap { $0.date(from: trimmed) }.first
    }

    func firstHTTPURL(_ text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return detector?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))?.url
    }

    func cleanMessageText(_ text: String, messageType: Int? = nil) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("<msg>") || value.contains("<appmsg>") {
            let title = xmlValue("title", in: value)
            let url = xmlValue("url", in: value)
            if let title {
                value = url == nil ? title : "\(title)\n\(url!)"
            }
        }

        if messageType == 10000 {
            value = value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
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

    func cleanHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func xmlValue(_ name: String, in text: String) -> String? {
        let regex = try? NSRegularExpression(
            pattern: "<\(name)[^>]*>(.*?)</\(name)>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        )
        guard let regex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return cleanHTML(String(text[range])).nilIfEmpty
    }

    func htmlMetaValue(_ name: String, in html: String) -> String? {
        let pattern = "<meta[^>]+(?:property|name)=[\"']\\Q\(name)\\E[\"'][^>]+content=[\"']([^\"']+)[\"']"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        guard let regex,
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return cleanHTML(String(html[range])).nilIfEmpty
    }

    func htmlTagValue(_ name: String, in html: String) -> String? {
        let regex = try? NSRegularExpression(
            pattern: "<\(name)[^>]*>(.*?)</\(name)>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        )
        guard let regex,
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return cleanHTML(String(html[range])).nilIfEmpty
    }

    func decodeQuotedPrintable(_ text: String) -> String {
        let withoutSoftBreaks = text
            .replacingOccurrences(of: "=\r\n", with: "")
            .replacingOccurrences(of: "=\n", with: "")

        var bytes: [UInt8] = []
        bytes.reserveCapacity(withoutSoftBreaks.utf8.count)
        let characters = Array(withoutSoftBreaks)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character == "=",
               index + 2 < characters.count,
               let high = characters[index + 1].hexDigitValue,
               let low = characters[index + 2].hexDigitValue {
                bytes.append(UInt8(high * 16 + low))
                index += 3
            } else {
                bytes.append(contentsOf: String(character).utf8)
                index += 1
            }
        }

        return String(decoding: bytes, as: UTF8.self)
    }
}

public struct ImportError: LocalizedError {
    public let message: String
    public var errorDescription: String? { message }

    public init(message: String) {
        self.message = message
    }
}

private struct AnyDecodableValue: Decodable {
    let anyValue: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            anyValue = NSNull()
        } else if let value = try? container.decode(Bool.self) {
            anyValue = value
        } else if let value = try? container.decode(Double.self) {
            anyValue = value
        } else if let value = try? container.decode(String.self) {
            anyValue = value
        } else if let value = try? container.decode([AnyDecodableValue].self) {
            anyValue = value.map(\.anyValue)
        } else if let value = try? container.decode([String: AnyDecodableValue].self) {
            anyValue = value.mapValues(\.anyValue)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }
}

private extension RawImportRecord {
    func recordStableKey(platform: ChatPlatform, sender: MessageSender, date: Date, text: String) -> String {
        [
            platform.rawValue,
            String(date.timeIntervalSince1970),
            text.lowercased(),
            sender.rawValue
        ].joined(separator: "|")
    }

    var exportFormat: ImportFormat {
        switch platform {
        case .xiaohongshu: .xiaohongshuExport
        case .douyin: .douyinExport
        case .qq: .qqHTMLArchive
        case .wechat: .genericJSON
        }
    }
}

