import Foundation

public protocol TailscaleReachability: Sendable {
    func isConnected() async -> Bool
}

/// Default: attempts private probe to first configured private host when implemented in app layer.
/// Core ships a stub that callers override via injection.
public struct StubTailscaleReachability: TailscaleReachability {
    private let connected: Bool

    public init(connected: Bool) {
        self.connected = connected
    }

    public func isConnected() async -> Bool { connected }
}
