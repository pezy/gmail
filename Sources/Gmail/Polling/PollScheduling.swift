import Foundation

protocol PollScheduling: Sendable {
    func schedule(interval: TimeInterval, action: @escaping @Sendable () async -> Void) async
    func invalidate() async
}
