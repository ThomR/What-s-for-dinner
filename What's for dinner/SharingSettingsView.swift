import SwiftUI
import CloudKit

/// Het gedeelte in de instellingen waarmee je iemand aan je lijst toevoegt.
struct SharingSettingsView: View {

    /// Wat er op dit moment gedeeld is.
    enum State {
        case loading
        /// Alleen van jou.
        case privateList
        /// Van jou, en gedeeld met anderen.
        case sharedByMe(CKShare)
        /// Van iemand anders, jij bent uitgenodigd.
        case sharedWithMe
        case failed(String)
    }

    @SwiftUI.State private var state: State = .loading
    @SwiftUI.State private var isWorking = false
    @SwiftUI.State private var confirmStop = false

    var body: some View {
        Section {
            content
        } header: {
            Text(LocalizedStringKey("sharing_header")).font(.subheadline)
        } footer: {
            Text(LocalizedStringKey("sharing_footer")).font(.caption)
        }
        .task { await reload() }
        .alert(LocalizedStringKey("sharing_stop_confirm"), isPresented: $confirmStop) {
            Button(LocalizedStringKey("sharing_stop"), role: .destructive) {
                Task { await stopSharing() }
            }
            Button(LocalizedStringKey("cancel"), role: .cancel) {}
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            HStack {
                ProgressView()
                Text(LocalizedStringKey("sharing_loading")).foregroundStyle(.secondary)
            }

        case .privateList:
            Button {
                Task { await invite() }
            } label: {
                Label(LocalizedStringKey("sharing_invite"), systemImage: "person.badge.plus")
                    .fontDesign(.rounded)
            }
            .disabled(isWorking)

        case .sharedByMe(let share):
            ForEach(participants(in: share), id: \.self) { name in
                Label(name, systemImage: "person.fill")
                    .fontDesign(.rounded)
            }
            Button {
                show(share)
            } label: {
                Label(LocalizedStringKey("sharing_manage"), systemImage: "person.2")
                    .fontDesign(.rounded)
            }
            Button(role: .destructive) {
                confirmStop = true
            } label: {
                Label(LocalizedStringKey("sharing_stop"), systemImage: "person.badge.minus")
                    .fontDesign(.rounded)
            }

        case .sharedWithMe:
            Label(LocalizedStringKey("sharing_joined"), systemImage: "person.2.fill")
                .fontDesign(.rounded)
            Button(role: .destructive) {
                Task { await leave() }
            } label: {
                Label(LocalizedStringKey("sharing_leave"), systemImage: "rectangle.portrait.and.arrow.right")
                    .fontDesign(.rounded)
            }

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// De namen van de mensen die meedoen, zonder jezelf.
    private func participants(in share: CKShare) -> [String] {
        share.participants
            .filter { $0.role != .owner }
            .compactMap { participant in
                let identity = participant.userIdentity
                if let components = identity.nameComponents {
                    return PersonNameComponentsFormatter.localizedString(from: components, style: .default)
                }
                return identity.lookupInfo?.emailAddress ?? identity.lookupInfo?.phoneNumber
            }
    }

    // MARK: - Acties

    private func reload() async {
        guard CloudAvailability.isEnabled else {
            state = .failed(String(localized: "share_error_unavailable"))
            return
        }
        if CloudSync.shared.activeScope == .sharedDatabase {
            state = .sharedWithMe
            return
        }
        do {
            let share = try await CloudSharing.existingShareIfAny()
            state = share.map(State.sharedByMe) ?? .privateList
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func invite() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let share = try await CloudSharing.shareForOwnList()
            state = .sharedByMe(share)
            show(share)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Het systeemvenster openen en daarna opnieuw kijken wat er gedeeld is.
    private func show(_ share: CKShare) {
        CloudSharingPresenter.present(share: share, container: CloudSharing.container) {
            Task { await reload() }
        }
    }

    private func stopSharing() async {
        do {
            try await CloudSharing.stopSharing()
            state = .privateList
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func leave() async {
        do {
            try await CloudSharing.leaveSharedList()
            state = .privateList
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}


