import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// You tab body — profile card + Workspace / Notifications / Appearance /
/// Agent settings groups. The tmux server row pushes the existing
/// `SettingsView` (the API base URL form from Phase 1).
struct YouView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(UserPreferences.self) private var prefs
    @Environment(PushRegistrationService.self) private var pushService
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL

    @State private var liveProjectCount: Int?
    @State private var liveSessionCount: Int?
    @State private var availableProjects: [Components.Schemas.Project] = []
    @State private var showProjectPicker = false
    @State private var showComingSoonSheet: ComingSoonContent?
    @State private var signOutToast = false
    @State private var showMutedProjectsSheet = false
    @State private var showQuietHoursSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s5) {
                header
                profileCard
                workspaceSection
                notificationsSection
                appearanceSection
                agentSection
            }
            .padding(.bottom, Theme.Spacing.s5)
        }
        .background(Theme.Surface.bg(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadWorkspaceSummary()
            await pushService.refreshStatus()
        }
        .refreshable {
            await loadWorkspaceSummary()
            await pushService.refreshStatus()
        }
        .sheet(isPresented: $showMutedProjectsSheet) {
            mutedProjectsSheet
        }
        .sheet(isPresented: $showQuietHoursSheet) {
            quietHoursSheet
        }
        .sheet(item: $showComingSoonSheet) { content in
            EmptyState(systemImage: content.icon, title: content.title, message: content.message)
                .presentationDetents([.medium])
        }
        .navigationDestination(for: YouRoute.self) { route in
            switch route {
            case .tmuxServer:
                SettingsView()
            }
        }
        .alert("Signed out", isPresented: $signOutToast) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sign-out is a no-op today — credentials aren't stored locally.")
        }
    }

    // MARK: - Header

    private var header: some View {
        LargeTitleHeader(title: "You", subtitle: nil) {
            Menu {
                Button("Sign out") { signOutToast = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Text.fg(scheme))
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Profile actions")
        }
    }

    // MARK: - Profile

    private var profileCard: some View {
        let initial = prefs.displayName.first.map(String.init)?.uppercased() ?? "Y"
        return HStack(alignment: .center, spacing: Theme.Spacing.s4) {
            ZStack {
                Circle()
                    .fill(prefs.accent.value(for: scheme).opacity(0.18))
                    .frame(width: 64, height: 64)
                Circle()
                    .strokeBorder(prefs.accent.value(for: scheme), lineWidth: 1.5)
                    .frame(width: 64, height: 64)
                Text(initial)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(prefs.accent.value(for: scheme))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(prefs.displayName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.Text.fg(scheme))
                Text(workspaceSummary)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.s4)
    }

    private var workspaceSummary: String {
        let projects = liveProjectCount ?? 0
        let sessions = liveSessionCount ?? 0
        return "\(projects) project\(projects == 1 ? "" : "s") · \(sessions) session\(sessions == 1 ? "" : "s") live"
    }

    // MARK: - Sections

    private var workspaceSection: some View {
        section(title: "Workspace") {
            settingRow(title: "Default project", detail: defaultProjectLabel) {
                showProjectPicker = true
            }
            Divider().background(Theme.Surface.sep(scheme))
            NavigationLink(value: YouRoute.tmuxServer) {
                settingRow(title: "tmux server", detail: appModel.apiConfiguration.baseURL.host ?? "Unset", chevron: true)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showProjectPicker) {
            projectPickerSheet
        }
    }

    private var notificationsSection: some View {
        section(title: "Notifications") {
            masterToggleRow
            if isPushActive {
                Divider().background(Theme.Surface.sep(scheme))
                settingRow(title: "Muted projects", detail: mutedProjectsLabel) {
                    showMutedProjectsSheet = true
                }
                Divider().background(Theme.Surface.sep(scheme))
                settingRow(title: "Quiet hours", detail: quietHoursLabel) {
                    showQuietHoursSheet = true
                }
            }
            if isPushDenied {
                Divider().background(Theme.Surface.sep(scheme))
                Button {
                    #if canImport(UIKit)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                    #endif
                } label: {
                    HStack(spacing: 8) {
                        Text("Enable in Settings")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(prefs.accent.value(for: scheme))
                        Spacer(minLength: 8)
                        Chevron()
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var masterToggleRow: some View {
        HStack(spacing: 8) {
            Text("Push notifications")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.Text.fg(scheme))
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { isPushActive },
                set: { newValue in
                    Task { await pushService.setMasterToggle(newValue) }
                }
            ))
            .labelsHidden()
            .disabled(isPushDenied)
            .tint(prefs.accent.value(for: scheme))
        }
        .padding(.vertical, 10)
    }

    private var isPushActive: Bool {
        if case .registered = pushService.status { return true }
        return false
    }

    private var isPushDenied: Bool {
        pushService.status == .denied
    }

    private var mutedProjectsLabel: String {
        let count = prefs.mutedProjectIDs.count
        if count == 0 { return "None" }
        if count == 1 { return "1 project" }
        return "\(count) projects"
    }

    private var quietHoursLabel: String {
        guard let start = prefs.quietHoursStart, let end = prefs.quietHoursEnd else {
            return "Off"
        }
        return "\(Self.formatUTCHour(start)) → \(Self.formatUTCHour(end)) UTC"
    }

    static func formatUTCHour(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }

    private var appearanceSection: some View {
        section(title: "Appearance") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Accent color")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.Text.fg(scheme))
                @Bindable var bindablePrefs = prefs
                AccentSwatchPicker(selection: $bindablePrefs.accent)
            }
            .padding(.vertical, 6)

            Divider().background(Theme.Surface.sep(scheme))

            VStack(alignment: .leading, spacing: 10) {
                Text("Text size")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.Text.fg(scheme))
                textSizeControl
            }
            .padding(.vertical, 6)

            Divider().background(Theme.Surface.sep(scheme))

            VStack(alignment: .leading, spacing: 10) {
                Text("Appearance")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.Text.fg(scheme))
                appearanceControl
            }
            .padding(.vertical, 6)
        }
    }

    private var agentSection: some View {
        section(title: "Agent") {
            settingRow(title: "Default model", detail: "Claude Sonnet") {
                showComingSoonSheet = ComingSoonContent.model
            }
            Divider().background(Theme.Surface.sep(scheme))
            settingRow(title: "Pane budget", detail: "6 per window") {
                showComingSoonSheet = ComingSoonContent.paneBudget
            }
            Divider().background(Theme.Surface.sep(scheme))
            settingRow(title: "Context bundle", detail: "PRD + Decisions") {
                showComingSoonSheet = ComingSoonContent.contextBundle
            }
        }
    }

    // MARK: - Building blocks

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text(title.uppercased())
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, Theme.Spacing.s4)
            RoundedCard {
                VStack(spacing: 0) {
                    content()
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    private func settingRow(
        title: String,
        detail: String,
        chevron: Bool = true,
        onTap: @escaping () -> Void = {}
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.Text.fg(scheme))
                Spacer(minLength: 8)
                Text(detail)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                if chevron {
                    Chevron()
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Controls

    @ViewBuilder
    private var textSizeControl: some View {
        @Bindable var bindablePrefs = prefs
        let labels = UserPreferences.TextSize.allCases.map(\.label)
        let binding = Binding<String>(
            get: { prefs.textSize.label },
            set: { newLabel in
                if let match = UserPreferences.TextSize.allCases.first(where: { $0.label == newLabel }) {
                    bindablePrefs.textSize = match
                }
            }
        )
        SegmentedControl(items: labels, selection: binding)
    }

    @ViewBuilder
    private var appearanceControl: some View {
        @Bindable var bindablePrefs = prefs
        let labels = UserPreferences.AppearanceMode.allCases.map(\.label)
        let binding = Binding<String>(
            get: { prefs.appearance.label },
            set: { newLabel in
                if let match = UserPreferences.AppearanceMode.allCases.first(where: { $0.label == newLabel }) {
                    bindablePrefs.appearance = match
                }
            }
        )
        SegmentedControl(items: labels, selection: binding)
    }

    // MARK: - Project picker

    private var projectPickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    @Bindable var bindablePrefs = prefs
                    bindablePrefs.defaultProjectID = nil
                    showProjectPicker = false
                } label: {
                    HStack {
                        Text("None")
                        Spacer()
                        if prefs.defaultProjectID == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                ForEach(availableProjects, id: \.id) { project in
                    Button {
                        @Bindable var bindablePrefs = prefs
                        bindablePrefs.defaultProjectID = project.id
                        showProjectPicker = false
                    } label: {
                        HStack {
                            Pip(accent: ProjectAccentMapper.color(for: project.accent ?? ""), size: 8, radius: 2)
                            Text(project.name)
                            Spacer()
                            if prefs.defaultProjectID == project.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Default project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showProjectPicker = false }
                }
            }
        }
    }

    private var defaultProjectLabel: String {
        guard let id = prefs.defaultProjectID,
              let project = availableProjects.first(where: { $0.id == id })
        else { return "None" }
        return project.name
    }

    // MARK: - Muted projects sheet

    private var mutedProjectsSheet: some View {
        NavigationStack {
            List {
                if availableProjects.isEmpty {
                    Text("No projects loaded yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(availableProjects, id: \.id) { project in
                    Button {
                        toggleMute(for: project.id)
                    } label: {
                        HStack {
                            Pip(accent: ProjectAccentMapper.color(for: project.accent ?? ""), size: 8, radius: 2)
                            Text(project.name)
                            Spacer()
                            if prefs.mutedProjectIDs.contains(project.id) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Muted projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showMutedProjectsSheet = false }
                }
            }
        }
    }

    private func toggleMute(for projectID: Int64) {
        var ids = prefs.mutedProjectIDs
        if let index = ids.firstIndex(of: projectID) {
            ids.remove(at: index)
        } else {
            ids.append(projectID)
        }
        Task { await pushService.setMutedProjectIDs(ids.sorted()) }
    }

    // MARK: - Quiet hours sheet

    private var quietHoursSheet: some View {
        NavigationStack {
            QuietHoursForm(
                initialStart: prefs.quietHoursStart,
                initialEnd: prefs.quietHoursEnd
            ) { start, end in
                Task { await pushService.setQuietHours(start: start, end: end) }
                showQuietHoursSheet = false
            } onCancel: {
                showQuietHoursSheet = false
            }
            .navigationTitle("Quiet hours")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Load

    private func loadWorkspaceSummary() async {
        do {
            let projects = try await appModel.repository.listProjects()
            availableProjects = projects
            liveProjectCount = projects.count
            var live = 0
            for project in projects {
                let sessions = (try? await appModel.repository.listProjectAgentSessions(projectIDOrSlug: project.slug)) ?? []
                live += sessions.filter { $0.state == .active || $0.state == .awaitingInput }.count
            }
            liveSessionCount = live
        } catch {
            // Soft fail — the summary line just shows defaults.
        }
    }
}

// MARK: - Quiet hours form

/// Time pickers for start + end of the quiet-hours window. The user picks
/// in their local timezone for legibility; we convert to UTC hours (the
/// shape stored in `UserPreferences` and sent to the backend) on commit.
private struct QuietHoursForm: View {
    @Environment(\.colorScheme) private var scheme

    let initialStart: Int?
    let initialEnd: Int?
    let onSave: (Int?, Int?) -> Void
    let onCancel: () -> Void

    @State private var isEnabled: Bool
    @State private var startDate: Date
    @State private var endDate: Date

    init(
        initialStart: Int?,
        initialEnd: Int?,
        onSave: @escaping (Int?, Int?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialStart = initialStart
        self.initialEnd = initialEnd
        self.onSave = onSave
        self.onCancel = onCancel
        let enabled = initialStart != nil && initialEnd != nil
        _isEnabled = State(initialValue: enabled)
        _startDate = State(initialValue: Self.dateForUTCHour(initialStart ?? 22))
        _endDate = State(initialValue: Self.dateForUTCHour(initialEnd ?? 7))
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable quiet hours", isOn: $isEnabled)
            } footer: {
                Text("Pushes are suppressed during this window. Times are stored as UTC hours; pickers show your local timezone for display.")
                    .font(.footnote)
            }
            if isEnabled {
                Section("Start") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
                Section("End") {
                    DatePicker("End", selection: $endDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if isEnabled {
                        onSave(Self.utcHour(from: startDate), Self.utcHour(from: endDate))
                    } else {
                        onSave(nil, nil)
                    }
                }
            }
        }
    }

    private static func dateForUTCHour(_ hour: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }

    private static func utcHour(from date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar.component(.hour, from: date)
    }
}

// MARK: - Routes

enum YouRoute: Hashable {
    case tmuxServer
}

// MARK: - Sheet content

private struct ComingSoonContent: Identifiable {
    let id: String
    let icon: String
    let title: String
    let message: String

    static let model = ComingSoonContent(
        id: "model",
        icon: "brain.head.profile",
        title: "Default model",
        message: "Per-workspace model selection ships when the contract surfaces it."
    )
    static let paneBudget = ComingSoonContent(
        id: "paneBudget",
        icon: "rectangle.split.2x1",
        title: "Pane budget",
        message: "Per-window pane caps ship with the terminal phase."
    )
    static let contextBundle = ComingSoonContent(
        id: "contextBundle",
        icon: "shippingbox",
        title: "Context bundle",
        message: "Bundle composition ships when the agent contract supports custom packs."
    )
}

@MainActor
private func makeYouPreviewService(
    suite: String,
    pushStatus: PushAuthorizationStatus = .denied
) -> (AppModel, UserPreferences, PushRegistrationService) {
    let model = AppModel(repository: MockTmuxAgentRepository())
    let prefs = UserPreferences(store: UserDefaults(suiteName: suite) ?? .standard)
    let service = PushRegistrationService(
        repositoryProvider: { model.repository },
        preferences: prefs,
        pushSystem: MockPushSystem(initialStatus: pushStatus)
    )
    return (model, prefs, service)
}

#Preview("You — light") {
    let (model, prefs, push) = makeYouPreviewService(suite: "preview-light")
    return NavigationStack {
        YouView()
    }
    .environment(model)
    .environment(RootCoordinator())
    .environment(prefs)
    .environment(push)
}

#Preview("You — dark") {
    let (model, prefs, push) = makeYouPreviewService(suite: "preview-dark")
    return NavigationStack {
        YouView()
    }
    .environment(model)
    .environment(RootCoordinator())
    .environment(prefs)
    .environment(push)
    .preferredColorScheme(.dark)
}
