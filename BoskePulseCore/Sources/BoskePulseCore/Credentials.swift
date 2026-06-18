import Foundation

public struct PulseCredentials: Sendable, Equatable {
    public let coolifyBaseURL: URL?
    public let coolifyToken: String?
    public let hetznerToken: String?
    public let telegramBotToken: String?
    public let telegramChatID: String?

    public init(
        coolifyBaseURL: URL?,
        coolifyToken: String?,
        hetznerToken: String?,
        telegramBotToken: String?,
        telegramChatID: String?
    ) {
        self.coolifyBaseURL = coolifyBaseURL
        self.coolifyToken = coolifyToken
        self.hetznerToken = hetznerToken
        self.telegramBotToken = telegramBotToken
        self.telegramChatID = telegramChatID
    }

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

/// Mutable store so the menu bar app can refresh credentials without rebuilding PulseEngine.
public final class LiveCredentialsStore: CredentialsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var credentials: PulseCredentials

    public init(credentials: PulseCredentials = .empty) {
        self.credentials = credentials
    }

    public func update(_ credentials: PulseCredentials) {
        lock.lock()
        self.credentials = credentials
        lock.unlock()
    }

    public func load() -> PulseCredentials {
        lock.lock()
        defer { lock.unlock() }
        return credentials
    }
}
