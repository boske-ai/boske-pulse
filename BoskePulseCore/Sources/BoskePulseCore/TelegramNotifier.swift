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
        guard let url = URL(string: "https://api.telegram.org/bot\(botToken)/sendMessage") else {
            throw TelegramError.invalidURL
        }

        let payload: [String: Any] = [
            "chat_id": SecurityPolicy.sanitizedTelegramField(chatID),
            "text": SecurityPolicy.sanitizedTelegramMessage(text),
            "disable_web_page_preview": true,
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

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
        var lines = [
            "\(emoji) Boske Pulse — \(snapshot.overall.rawValue.uppercased())",
            SecurityPolicy.sanitizedTelegramField(snapshot.smokeSummary),
        ]
        for server in snapshot.servers where server.overall != .healthy {
            let serverName = SecurityPolicy.sanitizedTelegramField(server.name)
            lines.append("• \(serverName): \(server.overall.rawValue)")
            for check in server.endpointChecks where check.status == .fail {
                let label = SecurityPolicy.sanitizedTelegramField(check.label)
                let message = SecurityPolicy.sanitizedTelegramField(check.message ?? "fail")
                lines.append("  - \(label): \(message)")
            }
        }
        return SecurityPolicy.sanitizedTelegramMessage(lines.joined(separator: "\n"))
    }
}

public enum TelegramError: Error, Equatable {
    case invalidURL
    case httpStatus(Int)
    case notConfigured
}
