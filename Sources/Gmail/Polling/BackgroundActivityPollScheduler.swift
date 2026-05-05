import Foundation

// NSBackgroundActivityScheduler is energy-efficient but macOS can defer it by
// several minutes, which is unacceptable for a mail notifier. A Task.sleep loop
// fires reliably and cancels instantly when invalidated.
actor BackgroundActivityPollScheduler: PollScheduling {
    private var task: Task<Void, Never>?

    func schedule(interval: TimeInterval, action: @escaping @Sendable () async -> Void) async {
        await invalidate()
        task = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                await action()
            }
        }
    }

    func invalidate() async {
        task?.cancel()
        task = nil
    }
}
