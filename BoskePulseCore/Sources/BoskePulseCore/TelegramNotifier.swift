import Foundation

public struct TelegramNotifier: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(
        botToken: String,
        chatID: String,
        text: String
    ) async throws {
        var components = URLComponents(string: "https://api.telegram.org/bot\(botToken)/sendMessage")!
        components.queryItems = [
            URLQueryItem(name: "chat_id", value: chatID),
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "disable_web_page_preview", value: "true"),
        ]
        guard let url = components.url else {
            throw TelegramError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw TelegramError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    public func formatAlert(snapshot: ProductionSnapshot) -> String {
        let emoji: String
        switch snapshot.overall {
        case .healthy: emoji = "🟢"
        case .degraded: emoji = "🟡"
        case .down: emoji = "🔴"
        case .unknown: emoji = "⚪"
        }
        var lines = ["\(emoji) Boske Pulse — \(snapshot.overall.rawValue.uppercased())", snapshot.smokeSummary]
        for server in snapshot.servers where server.overall != .healthy {
            lines.append("• \(server.name): \(server.overall.rawValue)")
            for check in server.endpointChecks where check.status == .fail {
                lines.append("  - \(check.label): \(check.message ?? "fail")")
            }
        }
        return lines.joined(separator: "\n")
    }
}

public enum TelegramError: Error, Equatable {
    case invalidURL
    case httpStatus(Int)
    case notConfigured
}
