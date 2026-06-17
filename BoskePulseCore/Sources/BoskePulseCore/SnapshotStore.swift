import Foundation

public struct SnapshotStore: Sendable {
    public let appGroupIdentifier: String
    private let fileName = "production-snapshot.json"

    public init(appGroupIdentifier: String) {
        self.appGroupIdentifier = appGroupIdentifier
    }

    public var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }

    public func write(_ snapshot: ProductionSnapshot) throws {
        guard let url = snapshotURL else {
            throw SnapshotStoreError.appGroupUnavailable
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    public func read() throws -> ProductionSnapshot? {
        guard let url = snapshotURL, FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProductionSnapshot.self, from: data)
    }
}

public enum SnapshotStoreError: Error, Equatable {
    case appGroupUnavailable
}
