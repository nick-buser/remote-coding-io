import Foundation

// JSONDecoder/JSONEncoder used by the in-memory mock fixtures. The
// generated client manages its own coders via the OpenAPI runtime; this
// helper exists only for code paths that decode JSON outside of the
// generated client (currently the Mock repository's seed fixtures).

extension JSONDecoder {
    static var openAPI: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
