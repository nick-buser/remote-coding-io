import Foundation
import Testing
@testable import remote_coding

@MainActor
struct PushRegistrationServiceTests {

    private func makePreferences() -> UserPreferences {
        let suite = "PushRegistrationServiceTests-\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        store.removePersistentDomain(forName: suite)
        return UserPreferences(store: store)
    }

    private func makeService(
        repository: TmuxAgentRepository,
        preferences: UserPreferences,
        pushSystem: any PushSystem,
        environment: Components.Schemas.DeviceEnvironment = .sandbox
    ) -> PushRegistrationService {
        PushRegistrationService(
            repositoryProvider: { repository },
            preferences: preferences,
            pushSystem: pushSystem,
            environment: environment
        )
    }

    // MARK: - requestPermissionIfNeeded

    @Test func notDeterminedPromptsAndRegistersOnGrant() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .notDetermined, grantsAuthorization: true)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.requestPermissionIfNeeded()

        #expect(push.requestedAuthorization == true)
        #expect(push.registerForRemoteCallCount == 1)
    }

    @Test func notDeterminedThenDeniedSetsStatusDenied() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .notDetermined, grantsAuthorization: false)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.requestPermissionIfNeeded()

        #expect(push.requestedAuthorization == true)
        #expect(push.registerForRemoteCallCount == 0)
        #expect(service.status == .denied)
    }

    @Test func deniedStatusDoesNotPrompt() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .denied)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.requestPermissionIfNeeded()

        #expect(push.requestedAuthorization == false)
        #expect(push.registerForRemoteCallCount == 0)
        #expect(service.status == .denied)
    }

    @Test func authorizedStatusReRegistersWithoutPrompting() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .authorized)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.requestPermissionIfNeeded()

        #expect(push.requestedAuthorization == false)
        #expect(push.registerForRemoteCallCount == 1)
    }

    // MARK: - applyDeviceToken

    @Test func applyDeviceTokenHexEncodesAndPersists() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .authorized)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        let bytes: [UInt8] = [0xAB, 0xCD, 0x01, 0x02]
        let data = Data(bytes)

        await service.applyDeviceToken(data)

        #expect(prefs.pushToken == "abcd0102")
        #expect(repo.registeredDevices.count == 1)
        #expect(repo.registeredDevices.first?.deviceToken == "abcd0102")
        #expect(service.status == .registered(token: "abcd0102"))
    }

    @Test func applyDeviceTokenIncludesEnvironmentAndPreferences() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        prefs.mutedProjectIDs = [5, 11]
        prefs.quietHoursStart = 22
        prefs.quietHoursEnd = 7

        let push = MockPushSystem()
        let service = makeService(
            repository: repo,
            preferences: prefs,
            pushSystem: push,
            environment: .production
        )

        await service.applyDeviceToken(Data([0x00, 0xff]))

        let registration = repo.registeredDevices.first
        #expect(registration?.environment == .production)
        #expect(registration?.mutedProjectIds == [5, 11])
        #expect(registration?.quietHoursStart == 22)
        #expect(registration?.quietHoursEnd == 7)
    }

    // MARK: - deregister

    @Test func deregisterClearsTokenAndCallsRepository() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .authorized)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.applyDeviceToken(Data([0x12, 0x34]))
        await service.deregister()

        #expect(prefs.pushToken == nil)
        #expect(repo.deregisteredDeviceTokens == ["1234"])
        #expect(service.status == .unknown)
    }

    @Test func deregisterWithNoTokenIsNoOp() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem()
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.deregister()

        #expect(prefs.pushToken == nil)
        #expect(repo.deregisteredDeviceTokens.isEmpty)
    }

    // MARK: - reregister

    @Test func reregisterReplaysWithCurrentPreferences() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .authorized)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.applyDeviceToken(Data([0x01]))
        prefs.mutedProjectIDs = [42]
        prefs.quietHoursStart = 23
        prefs.quietHoursEnd = 6
        await service.reregister()

        #expect(repo.registeredDevices.count == 1) // upsert
        let registration = repo.registeredDevices.first
        #expect(registration?.mutedProjectIds == [42])
        #expect(registration?.quietHoursStart == 23)
        #expect(registration?.quietHoursEnd == 6)
    }

    @Test func reregisterWithoutTokenIsNoOp() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem()
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.reregister()

        #expect(repo.registeredDevices.isEmpty)
    }

    // MARK: - setMasterToggle / setMutedProjectIDs / setQuietHours

    @Test func masterToggleOffCallsDeregister() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .authorized)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.applyDeviceToken(Data([0xff, 0xee]))
        #expect(prefs.pushToken == "ffee")

        await service.setMasterToggle(false)

        #expect(repo.deregisteredDeviceTokens == ["ffee"])
        #expect(prefs.pushToken == nil)
    }

    @Test func masterToggleOnRunsPermissionFlow() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .notDetermined, grantsAuthorization: true)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.setMasterToggle(true)

        #expect(push.requestedAuthorization == true)
        #expect(push.registerForRemoteCallCount == 1)
    }

    @Test func settingMutedProjectsReRegistersWithUpdatedList() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .authorized)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.applyDeviceToken(Data([0x01]))
        #expect(repo.registeredDevices.count == 1)

        await service.setMutedProjectIDs([3, 4])

        #expect(prefs.mutedProjectIDs == [3, 4])
        #expect(repo.registeredDevices.count == 1) // upsert
        #expect(repo.registeredDevices.first?.mutedProjectIds == [3, 4])
    }

    @Test func settingMutedProjectsWithoutTokenIsNoOpForServer() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem()
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.setMutedProjectIDs([7])

        #expect(prefs.mutedProjectIDs == [7]) // local prefs still updated
        #expect(repo.registeredDevices.isEmpty)
    }

    @Test func settingQuietHoursReRegistersWithUpdatedRange() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .authorized)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.applyDeviceToken(Data([0x01]))

        await service.setQuietHours(start: 21, end: 6)

        #expect(prefs.quietHoursStart == 21)
        #expect(prefs.quietHoursEnd == 6)
        #expect(repo.registeredDevices.first?.quietHoursStart == 21)
        #expect(repo.registeredDevices.first?.quietHoursEnd == 6)
    }

    @Test func settingQuietHoursToNilClearsTheWindow() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        prefs.quietHoursStart = 22
        prefs.quietHoursEnd = 7
        let push = MockPushSystem(initialStatus: .authorized)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)
        await service.applyDeviceToken(Data([0x01]))

        await service.setQuietHours(start: nil, end: nil)

        #expect(prefs.quietHoursStart == nil)
        #expect(prefs.quietHoursEnd == nil)
    }

    // MARK: - refreshStatus

    @Test func refreshStatusDoesNotPrompt() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .notDetermined)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.refreshStatus()

        #expect(push.requestedAuthorization == false)
        #expect(service.status == .notDetermined)
    }

    @Test func refreshStatusReflectsDenied() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem(initialStatus: .denied)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.refreshStatus()

        #expect(service.status == .denied)
    }

    @Test func refreshStatusReportsRegisteredWhenTokenStored() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        prefs.pushToken = "cafebabe"
        let push = MockPushSystem(initialStatus: .authorized)
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        await service.refreshStatus()

        #expect(service.status == .registered(token: "cafebabe"))
    }

    // MARK: - handleRegistrationFailure

    @Test func handleRegistrationFailureRecordsErrorWithoutThrowing() async throws {
        let repo = MockTmuxAgentRepository()
        let prefs = makePreferences()
        let push = MockPushSystem()
        let service = makeService(repository: repo, preferences: prefs, pushSystem: push)

        struct Boom: Error {}
        service.handleRegistrationFailure(Boom())

        #expect(service.lastError is Boom)
    }
}
