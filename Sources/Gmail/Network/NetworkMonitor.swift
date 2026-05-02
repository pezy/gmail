import Foundation
import Network

protocol NetworkMonitoring: Sendable {
    func start() async
    func stop() async
    var stateStream: AsyncStream<ConnectionState> { get async }
}

actor NetworkMonitor: NetworkMonitoring {
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private var continuation: AsyncStream<ConnectionState>.Continuation?
    private var stream: AsyncStream<ConnectionState>?
    private var lastState: ConnectionState = .unknown
    private var started = false

    init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "com.pezy.gmail.network-monitor")
    }

    var stateStream: AsyncStream<ConnectionState> {
        get {
            if let stream { return stream }
            let new = AsyncStream<ConnectionState> { continuation in
                self.assignContinuation(continuation)
            }
            stream = new
            return new
        }
    }

    func start() async {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let state: ConnectionState = path.status == .satisfied ? .online : .offline
            Task { [weak self] in
                await self?.publish(state)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() async {
        guard started else { return }
        started = false
        monitor.cancel()
        continuation?.finish()
        continuation = nil
        stream = nil
    }

    private func assignContinuation(_ continuation: AsyncStream<ConnectionState>.Continuation) {
        self.continuation = continuation
        if lastState != .unknown {
            continuation.yield(lastState)
        }
    }

    private func publish(_ state: ConnectionState) {
        guard state != lastState else { return }
        lastState = state
        continuation?.yield(state)
    }
}
