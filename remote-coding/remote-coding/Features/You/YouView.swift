import SwiftUI

/// You tab body — profile card + Workspace / Appearance / Agent
/// settings groups. The tmux server row pushes the existing
/// `SettingsView` (the API base URL form from Phase 1).
struct YouView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(UserPreferences.self) private var prefs
    @Environment(\.colorScheme) private var scheme

    @State private var liveProjectCount: Int?
    @State private var liveSessionCount: Int?
    @State private var availableProjects: [Components.Schemas.Project] = []
    @State private var showProjectPicker = false
    @State private var showComingSoonSheet: ComingSoonContent?
    @State private var signOutToast = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s5) {
                header
                profileCard
                workspaceSection
                appearanceSection
                agentSection
            }
            .padding(.bottom, Theme.Spacing.s5)
        }
        .background(Theme.Surface.bg(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadWorkspaceSummary()
        }
        .refreshable {
            await loadWorkspaceSummary()
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
            settingRow(title: "Notifications", detail: "Reviews & questions", chevron: false) {}
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

#Preview("You — light") {
    NavigationStack {
        YouView()
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
    .environment(UserPreferences(store: UserDefaults(suiteName: "preview-light") ?? .standard))
}

#Preview("You — dark") {
    NavigationStack {
        YouView()
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
    .environment(UserPreferences(store: UserDefaults(suiteName: "preview-dark") ?? .standard))
    .preferredColorScheme(.dark)
}
