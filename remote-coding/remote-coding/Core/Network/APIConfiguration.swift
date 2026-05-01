import Foundation

struct APIConfiguration: Hashable {
    static let defaultBaseURL = URL(string: "http://127.0.0.1:8080")!
    static let `default` = APIConfiguration(baseURL: defaultBaseURL)

    let baseURL: URL

    init(baseURL: URL) {
        var absolute = baseURL.absoluteString
        while absolute.count > 1 && absolute.hasSuffix("/") {
            absolute.removeLast()
        }
        self.baseURL = URL(string: absolute) ?? baseURL
    }

    init(baseURLString: String) throws {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, let host = url.host else {
            throw APIConfigurationError.invalidBaseURL
        }
        guard ["http", "https"].contains(scheme.lowercased()), !host.isEmpty else {
            throw APIConfigurationError.invalidBaseURL
        }
        self.init(baseURL: url)
    }
}

enum APIConfigurationError: LocalizedError {
    case invalidBaseURL

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Enter a valid http:// or https:// backend URL."
        }
    }
}

enum APIConfigurationStore {
    private static let baseURLKey = "tmuxAgent.apiBaseURL"

    static func load(defaults: UserDefaults = .standard) -> APIConfiguration {
        guard let value = defaults.string(forKey: baseURLKey),
              let configuration = try? APIConfiguration(baseURLString: value) else {
            return .default
        }
        return configuration
    }

    static func save(_ configuration: APIConfiguration, defaults: UserDefaults = .standard) {
        defaults.set(configuration.baseURL.absoluteString, forKey: baseURLKey)
    }
}

