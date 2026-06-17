import Foundation

public struct PulseCredentials: Sendable, Equatable {
    public let coolifyBaseURL: URL?
    public let coolifyToken: String?
    public let hetznerToken: String?
    public let telegramBotToken: String?
    public let telegramChatID: String?

    public static let empty = PulseCredentials(
        coolifyBaseURL: nil,
        coolifyToken: nil,
        hetznerToken: nil,
        telegramBotToken: nil,
        telegramChatID: nil
    )
}

public protocol CredentialsStore: Sendable {
    func load() -> PulseCredentials
}

public struct InMemoryCredentialsStore: CredentialsStore {
    private let credentials: PulseCredentials

    public init(credentials: PulseCredentials) {
        self.credentials = credentials
    }

    public func load() -> PulseCredentials { credentials }
}
