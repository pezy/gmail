import Foundation

actor BackgroundActivityPollScheduler: PollScheduling {
    private var activity: NSBackgroundActivityScheduler?
    private let identifier: String

    init(identifier: String = "com.pezy.gmail.polling") {
        self.identifier = identifier
    }

    func schedule(interval: TimeInterval, action: @escaping @Sendable () async -> Void) async {
        await invalidate()
        let activity = NSBackgroundActivityScheduler(identifier: identifier)
        activity.interval = interval
        activity.tolerance = max(1, interval * 0.2)
        activity.repeats = true
        activity.qualityOfService = .utility
        activity.schedule { completion in
            Task {
                await action()
                completion(.finished)
            }
        }
        self.activity = activity
    }

    func invalidate() async {
        activity?.invalidate()
        activity = nil
    }
}
