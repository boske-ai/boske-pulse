import Foundation

public enum ConfigLoader {
    public enum Error: Swift.Error, Equatable {
        case fileNotFound(String)
        case decodeFailed(String)
    }

    public static func applicationSupportConfigURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Boske Pulse/boske-production.json", isDirectory: false)
    }

    public static func defaultConfigURL(bundle: Bundle = .main) -> URL? {
        let candidates = configCandidateURLs(bundle: bundle)
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    public static func configCandidateURLs(bundle: Bundle = .main) -> [URL] {
        var urls: [URL] = []
        urls.append(applicationSupportConfigURL())
        urls.append(contentsOf: bundledConfigCandidates(mainBundle: bundle))
        for relative in ["Config/boske-production.json", "Config/boske-production.example.json"] {
            let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            urls.append(cwd.appendingPathComponent(relative))
        }
        return urls
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

    public static func loadDefault(bundle: Bundle = .main) throws -> ProductionConfig {
        guard let url = defaultConfigURL(bundle: bundle) else {
            throw Error.fileNotFound("boske-production.json")
        }
        return try load(from: url)
    }

    private static func bundledConfigCandidates(mainBundle: Bundle) -> [URL] {
        var urls: [URL] = []
        if let url = mainBundle.url(forResource: "boske-production", withExtension: "json") {
            urls.append(url)
        }
        if let url = mainBundle.url(forResource: "boske-production.example", withExtension: "json") {
            urls.append(url)
        }
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "boske-production.example", withExtension: "json") {
            urls.append(url)
        }
        #endif
        return urls
    }
}
