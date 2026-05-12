import Foundation
import Testing
@testable import remote_coding

struct DeviceRegistrationRepositoryTests {

    private let validToken = String(repeating: "ab", count: 32)
    private let secondToken = String(repeating: "cd", count: 32)

    private func makeRequest(
        token: String,
        environment: Components.Schemas.DeviceEnvironment = .sandbox,
        mutedProjectIDs: [Int64]? = nil,
        quietStart: Int? = nil,
        quietEnd: Int? = nil
    ) -> Components.Schemas.DeviceRegistrationRequest {
        Components.Schemas.DeviceRegistrationRequest(
            deviceToken: token,
            environment: environment,
            mutedProjectIds: mutedProjectIDs,
            quietHoursStart: quietStart,
            quietHoursEnd: quietEnd
        )
    }

    @Test func registerDevicePersistsTheToken() async throws {
        let repo = MockTmuxAgentRepository()
        let request = makeRequest(token: validToken)

        let result = try await repo.registerDevice(request)

        #expect(result.deviceToken == validToken)
        #expect(result.environment == .sandbox)
        #expect(repo.registeredDevices.count == 1)
        #expect(repo.registeredDevices.first?.deviceToken == validToken)
    }

    @Test func registerDeviceIsIdempotentForSameToken() async throws {
        let repo = MockTmuxAgentRepository()
        _ = try await repo.registerDevice(makeRequest(token: validToken, mutedProjectIDs: [1]))
        let second = try await repo.registerDevice(makeRequest(token: validToken, mutedProjectIDs: [1, 2]))

        #expect(repo.registeredDevices.count == 1)
        #expect(second.mutedProjectIds == [1, 2])
        // createdAt preserved across re-registration; updatedAt advances.
        if let createdAt = second.createdAt, let updatedAt = second.updatedAt {
            #expect(updatedAt >= createdAt)
        } else {
            Issue.record("expected createdAt and updatedAt to be set")
        }
    }

    @Test func registerDeviceCarriesQuietHoursAndMuteList() async throws {
        let repo = MockTmuxAgentRepository()
        let request = makeRequest(
            token: validToken,
            environment: .production,
            mutedProjectIDs: [7, 9],
            quietStart: 22,
            quietEnd: 7
        )

        let result = try await repo.registerDevice(request)

        #expect(result.environment == .production)
        #expect(result.mutedProjectIds == [7, 9])
        #expect(result.quietHoursStart == 22)
        #expect(result.quietHoursEnd == 7)
    }

    @Test func deregisterRemovesRegistrationAndRecordsTheCall() async throws {
        let repo = MockTmuxAgentRepository()
        _ = try await repo.registerDevice(makeRequest(token: validToken))
        _ = try await repo.registerDevice(makeRequest(token: secondToken))

        try await repo.deregisterDevice(token: validToken)

        #expect(repo.deregisteredDeviceTokens == [validToken])
        #expect(repo.registeredDevices.map(\.deviceToken) == [secondToken])
    }

    @Test func deregisterUnknownTokenStillRecordsTheCall() async throws {
        let repo = MockTmuxAgentRepository()
        try await repo.deregisterDevice(token: validToken)
        #expect(repo.deregisteredDeviceTokens == [validToken])
        #expect(repo.registeredDevices.isEmpty)
    }
}
