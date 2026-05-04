import Foundation

final class APIClient {
    private let configuration: APIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        configuration: APIConfiguration,
        session: URLSession = .shared,
        decoder: JSONDecoder = .openAPI,
        encoder: JSONEncoder = .openAPI
    ) {
        self.configuration = configuration
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    func get<Response: Decodable>(_ path: String) async throws -> Response {
        try await request(path: path, method: "GET", bodyData: nil)
    }

    func send<Response: Decodable>(_ path: String, method: String) async throws -> Response {
        try await request(path: path, method: method, bodyData: nil)
    }

    func send<Response: Decodable, Body: Encodable>(_ path: String, method: String, body: Body) async throws -> Response {
        let bodyData = try encoder.encode(body)
        return try await request(path: path, method: method, bodyData: bodyData)
    }

    func sendVoid(_ path: String, method: String) async throws {
        _ = try await data(path: path, method: method, bodyData: nil)
    }

    private func request<Response: Decodable>(path: String, method: String, bodyData: Data?) async throws -> Response {
        let responseData = try await data(path: path, method: method, bodyData: bodyData)
        guard !responseData.isEmpty else {
            throw APIClientError.emptyResponse
        }
        return try decoder.decode(Response.self, from: responseData)
    }

    private func data(path: String, method: String, bodyData: Data?) async throws -> Data {
        let url = configuration.baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bodyData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let problem = try? decoder.decode(OpenAPI.ProblemDetails.self, from: data) {
                throw APIClientError.problem(problem)
            }
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
        return data
    }
}

enum APIClientError: LocalizedError {
    case emptyResponse
    case httpStatus(Int)
    case invalidResponse
    case problem(OpenAPI.ProblemDetails)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            "The server returned an empty response."
        case .httpStatus(let status):
            "The server returned HTTP \(status)."
        case .invalidResponse:
            "The server returned an invalid response."
        case .problem(let problem):
            problem.detail ?? problem.title
        case .unsupported(let message):
            message
        }
    }
}

enum APIPath {
    nonisolated static func join(_ components: String...) -> String {
        "/" + components.map(escape).joined(separator: "/")
    }

    nonisolated private static func escape(_ component: String) -> String {
        var pathAllowed = CharacterSet.urlPathAllowed
        pathAllowed.remove(charactersIn: "/")
        return component.addingPercentEncoding(withAllowedCharacters: pathAllowed) ?? component
    }
}
