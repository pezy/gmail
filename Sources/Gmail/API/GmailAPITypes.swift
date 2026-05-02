import Foundation

struct GmailProfile: Sendable, Equatable {
    let emailAddress: String
    let historyId: String
    let messagesTotal: Int
}

struct MessageListResponse: Sendable, Equatable {
    let messageIds: [String]
    let resultSizeEstimate: Int
}

struct HistoryResponse: Sendable, Equatable {
    let historyId: String
    let changes: [HistoryChange]
}

enum HistoryChange: Sendable, Equatable {
    case messageAdded(id: String)
    case messageDeleted(id: String)
    case labelAdded(messageId: String, label: String)
    case labelRemoved(messageId: String, label: String)
}

protocol GmailAPIClienting: Sendable {
    func getProfile(accessToken: String) async throws -> GmailProfile
    func listUnreadMessages(accessToken: String, maxResults: Int) async throws -> MessageListResponse
    func getMessageMetadata(accessToken: String, id: String) async throws -> EmailMessage
    func listHistory(accessToken: String, startHistoryId: String) async throws -> HistoryResponse
}
