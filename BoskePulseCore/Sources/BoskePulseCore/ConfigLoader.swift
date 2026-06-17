import Foundation

public enum ConfigLoader {
    public enum Error: Swift.Error, Equatable {
        case fileNotFound(String)
        case decodeFailed(String)
    }

    public static func load(from url: URL) throws -> ProductionConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw Error.fileNotFound(url.path)
        }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(ProductionConfig.self, from: data)
        } catch {
            throw Error.decodeFailed(error.localizedDescription)
        }
    }

    public static func defaultConfigURL(bundle: Bundle = .main) -> URL? {
        if let url = bundle.url(forResource: "boske-production", withExtension: "json") {
            return url
        }
        if let url = bundle.url(forResource: "boske-production.example", withExtension: "json") {
            return url
        }
        for relative in ["Config/boske-production.json", "Config/boske-production.example.json"] {
            let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let candidate = cwd.appendingPathComponent(relative)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
