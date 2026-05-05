import Foundation

enum RepositoryError: Error {
    case network(URLError)
    case http(Int)
    case problem(Components.Schemas.ProblemDetails)
    case decoding(Error)
    case unsupported(String)
}

extension RepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .network(let urlError):
            urlError.localizedDescription
        case .http(let status):
            "The server returned HTTP \(status)."
        case .problem(let problem):
            problem.detail ?? problem.title ?? "Request failed."
        case .decoding(let error):
            "Could not decode the server response: \(error.localizedDescription)"
        case .unsupported(let message):
            message
        }
    }
}
