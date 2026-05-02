import Foundation

struct EmailMessage: Identifiable, Equatable, Sendable {
    let id: String
    let threadId: String
    let from: String
    let subject: String
    let internalDate: Date
    let snippet: String?
}
