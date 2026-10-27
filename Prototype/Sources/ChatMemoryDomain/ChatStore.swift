import Foundation
import Combine

public final class ChatStore: ObservableObject {
    @Published public var people: [ChatPerson]
    @Published public var messages: [ChatMessage]
    @Published public var tags: [ChatTag]
    @Published public var importStatuses: [ImportStatus]
    @Published public var selectedPersonID: UUID?
    @Published public var selectedMessageID: UUID?
    @Published public var hoveringMessageID: UUID?
    @Published public var isRefreshing = false
    @Published public var searchText = "" {
        didSet { applySearch() }
    }
    @Published public var selectedPlatforms: Set<ChatPlatform> = Set(ChatPlatform.allCases)
    @Published public private(set) var visibleMessages: [ChatMessage] = []

    public init(
        people: [ChatPerson],
        messages: [ChatMessage],
        tags: [ChatTag],
        importStatuses: [ImportStatus]
    ) {
        self.people = people
        self.messages = messages
        self.tags = tags
        self.importStatuses = importStatuses
        selectedPersonID = people.first?.id
        applySearch()
    }

    public var selectedPerson: ChatPerson? {
        people.first { $0.id == selectedPersonID }
    }

    public var selectedMessage: ChatMessage? {
        messages.first { $0.id == selectedMessageID }
    }

    public var selectedMessages: [ChatMessage] {
        guard let selectedPersonID else { return [] }
        return messages
            .filter { $0.personID == selectedPersonID }
            .sorted { $0.sentAt < $1.sentAt }
    }

    public var tagDictionary: [UUID: ChatTag] {
        Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
    }

    public func select(_ person: ChatPerson?) {
        selectedPersonID = person?.id
        selectedMessageID = nil
        applySearch()
    }

    public func toggle(_ platform: ChatPlatform) {
        if selectedPlatforms.contains(platform), selectedPlatforms.count == 1 {
            selectedPlatforms = Set(ChatPlatform.allCases)
        } else if selectedPlatforms.contains(platform) {
            selectedPlatforms.remove(platform)
        } else {
            selectedPlatforms.insert(platform)
        }
        applySearch()
    }

    public func toggleFavorite(_ message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index].isFavorite.toggle()
    }

    public func toggleTag(_ tag: ChatTag, on message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        if messages[index].tagIDs.contains(tag.id) {
            messages[index].tagIDs.remove(tag.id)
        } else {
            messages[index].tagIDs.insert(tag.id)
        }
    }

    public func messageTags(for message: ChatMessage) -> [ChatTag] {
        message.tagIDs.compactMap { tagDictionary[$0] }.sorted { $0.name < $1.name }
    }

    public func groupedVisibleMessages(calendar: Calendar = .current) -> [(day: Date, messages: [ChatMessage])] {
        let groups = Dictionary(grouping: visibleMessages) { calendar.startOfDay(for: $0.sentAt) }
        return groups
            .map { (day: $0.key, messages: $0.value.sorted { $0.sentAt < $1.sentAt }) }
            .sorted { $0.day < $1.day }
    }

    public func applySearch() {
        let personID = selectedPersonID
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let platforms = selectedPlatforms

        visibleMessages = messages
            .filter { $0.personID == personID }
            .filter { platforms.contains($0.platform) }
            .filter { message in
                guard !query.isEmpty else { return true }
                let tagText = message.tagIDs
                    .compactMap { tagDictionary[$0]?.name }
                    .joined(separator: " ")
                let haystack = "\(message.text) \(tagText) \(message.platform.displayName) \(message.sender.displayName)"
                return haystack.lowercased().contains(query)
            }
            .sorted { $0.sentAt > $1.sentAt }
    }
}

