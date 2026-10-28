import Foundation

public enum SearchScope: String, CaseIterable, Identifiable {
    case currentPerson
    case allPeople

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .currentPerson: "当前联系人"
        case .allPeople: "所有人"
        }
    }
}

public struct SearchQuery: Equatable {
    public var terms: [String]
    public var phrases: [String]
    public var personTerms: [String]
    public var platformTerms: [String]
    public var tagTerms: [String]
    public var favoriteOnly: Bool

    public var hasTextConditions: Bool {
        !terms.isEmpty || !phrases.isEmpty
    }

    public var isEmpty: Bool {
        self == SearchQuery(raw: "")
    }

    public init(
        terms: [String] = [],
        phrases: [String] = [],
        personTerms: [String] = [],
        platformTerms: [String] = [],
        tagTerms: [String] = [],
        favoriteOnly: Bool = false
    ) {
        self.terms = terms
        self.phrases = phrases
        self.personTerms = personTerms
        self.platformTerms = platformTerms
        self.tagTerms = tagTerms
        self.favoriteOnly = favoriteOnly
    }

    public init(raw: String) {
        self = SearchQuery.parse(raw)
    }

    public static func parse(_ raw: String) -> SearchQuery {
        var query = SearchQuery()
        var token = ""
        var isInPhrase = false
        var tokens: [String] = []

        func appendToken() {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                tokens.append(trimmed)
            }
            token = ""
        }

        for character in raw {
            if character == "\"" {
                if isInPhrase {
                    appendToken()
                    isInPhrase = false
                } else {
                    appendToken()
                    isInPhrase = true
                }
            } else if character.isWhitespace && !isInPhrase {
                appendToken()
            } else {
                token.append(character)
            }
        }
        appendToken()

        for item in tokens {
            let lowercasedItem = item.lowercased()

            if lowercasedItem == "is:favorite" || lowercasedItem == "is:收藏" {
                query.favoriteOnly = true
            } else if lowercasedItem.hasPrefix("person:"), let value = value(after: lowercasedItem, prefix: "person:") {
                query.personTerms.append(value)
            } else if lowercasedItem.hasPrefix("platform:"), let value = value(after: lowercasedItem, prefix: "platform:") {
                query.platformTerms.append(value)
            } else if lowercasedItem.hasPrefix("tag:"), let value = value(after: lowercasedItem, prefix: "tag:") {
                query.tagTerms.append(value)
            } else if item.contains(" ") {
                query.phrases.append(lowercasedItem)
            } else {
                query.terms.append(lowercasedItem)
            }
        }

        return query
    }

    public func matches(
        message: ChatMessage,
        person: ChatPerson?,
        tagNames: [String]
    ) -> Bool {
        if favoriteOnly && !message.isFavorite {
            return false
        }

        if !personTerms.isEmpty {
            let personText = [
                person?.name,
                person?.subtitle,
                person?.initials
            ]
                .compactMap { $0 }
                .joined(separator: " ")
                .lowercased()

            guard personTerms.allSatisfy({ personText.contains($0) }) else {
                return false
            }
        }

        if !tagTerms.isEmpty {
            let lowercasedTagNames = tagNames.map { $0.lowercased() }
            guard tagTerms.allSatisfy({ tagTerm in
                lowercasedTagNames.contains { $0.contains(tagTerm) }
            }) else {
                return false
            }
        }

        let haystack = [
            message.text,
            message.externalTitle,
            message.externalURL,
            message.platform.displayName,
            message.sender.displayName,
            person?.name,
            person?.subtitle,
            tagNames.joined(separator: " ")
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        let termsMatch = terms.allSatisfy { haystack.contains($0) }
        let phrasesMatch = phrases.allSatisfy { haystack.contains($0) }

        return termsMatch && phrasesMatch
    }

    public var platforms: Set<ChatPlatform> {
        let allPlatforms = ChatPlatform.allCases
        let matches = platformTerms.flatMap { term in
            allPlatforms.filter { platform in
                let aliases = [
                    platform.rawValue,
                    platform.displayName,
                    platform.shortName,
                    platform == .xiaohongshu ? "xhs" : platform.rawValue,
                    platform == .douyin ? "tiktok" : platform.rawValue
                ]
                return aliases.contains {
                    $0.lowercased().contains(term) || term.contains($0.lowercased())
                }
            }
        }

        return Set(matches)
    }

    private static func value(after text: String, prefix: String) -> String? {
        guard text.count > prefix.count else { return nil }
        return String(text.dropFirst(prefix.count))
    }
}
