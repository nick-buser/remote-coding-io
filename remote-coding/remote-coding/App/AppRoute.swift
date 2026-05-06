import Foundation

/// Typed navigation destinations pushed onto a tab's `NavigationStack`.
///
/// Every case carries exactly one associated value. That invariant is
/// what lets `Codable` use the flat
/// `[discriminator, value]` shape — adding a multi-payload case
/// requires extending the encoder/decoder below.
enum AppRoute: Hashable {
    case projectDetail(idOrSlug: String)
    case featureDetail(featureID: Int64)
    case ticketDetail(publicID: String)
    case docDetail(docID: Int64)
    case sessionsForFeature(featureID: Int64)
    case agentSession(sessionID: Int64)
}

extension AppRoute: Codable {
    private enum Kind: String, Codable {
        case projectDetail
        case featureDetail
        case ticketDetail
        case docDetail
        case sessionsForFeature
        case agentSession
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let kind = try container.decode(Kind.self)
        switch kind {
        case .projectDetail:
            self = .projectDetail(idOrSlug: try container.decode(String.self))
        case .featureDetail:
            self = .featureDetail(featureID: try container.decode(Int64.self))
        case .ticketDetail:
            self = .ticketDetail(publicID: try container.decode(String.self))
        case .docDetail:
            self = .docDetail(docID: try container.decode(Int64.self))
        case .sessionsForFeature:
            self = .sessionsForFeature(featureID: try container.decode(Int64.self))
        case .agentSession:
            self = .agentSession(sessionID: try container.decode(Int64.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .projectDetail(let idOrSlug):
            try container.encode(Kind.projectDetail)
            try container.encode(idOrSlug)
        case .featureDetail(let featureID):
            try container.encode(Kind.featureDetail)
            try container.encode(featureID)
        case .ticketDetail(let publicID):
            try container.encode(Kind.ticketDetail)
            try container.encode(publicID)
        case .docDetail(let docID):
            try container.encode(Kind.docDetail)
            try container.encode(docID)
        case .sessionsForFeature(let featureID):
            try container.encode(Kind.sessionsForFeature)
            try container.encode(featureID)
        case .agentSession(let sessionID):
            try container.encode(Kind.agentSession)
            try container.encode(sessionID)
        }
    }
}
