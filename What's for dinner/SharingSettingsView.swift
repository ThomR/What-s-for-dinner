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
            // De lijst van een ander staat in zíjn iCloud, niet in de jouwe.
            if case .sharedWithMe = state {
                Text(LocalizedStringKey("sharing_footer_participant")).font(.caption)
            } else {
                Text(LocalizedStringKey("sharing_footer")).font(.caption)
            }
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
            ForEach(participants(in: share), id: \.self) { participant in
                participantRow(participant)
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
            VStack(alignment: .leading, spacing: 2) {
                if let owner = Preferences.sharedListOwnerName {
                    Text(LocalizedStringKey("sharing_joined_owner \(owner)"))
                        .fontDesign(.rounded)
                } else {
                    Text(LocalizedStringKey("sharing_joined"))
                        .fontDesign(.rounded)
                }
                Text(LocalizedStringKey(Preferences.sharedListReadOnly ? "sharing_permission_view" : "sharing_permission_edit"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    /// Iedereen behalve jezelf, en niet wie er al uit is gehaald.
    private func participants(in share: CKShare) -> [CKShare.Participant] {
        share.participants.filter { $0.role != .owner && $0.acceptanceStatus != .removed }
    }

    /// Eén deelnemer: naam, of hij al meedoet, en wat hij mag.
    ///
    /// Wie de uitnodiging nog niet heeft geaccepteerd heeft voor CloudKit nog
    /// geen naam. In 2.0 leverde dat een rij op met alleen een poppetje.
    private func participantRow(_ participant: CKShare.Participant) -> some View {
        let joined = participant.acceptanceStatus == .accepted
        let status: LocalizedStringKey = joined ? "sharing_status_joined" : "sharing_status_invited"
        let permission: LocalizedStringKey = participant.permission == .readWrite
            ? "sharing_permission_edit"
            : "sharing_permission_view"

        return HStack {
            Image(systemName: joined ? "person.fill.checkmark" : "person.badge.clock")
                .foregroundStyle(joined ? Color.accentColor : Color.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                if let name = CloudSync.displayName(of: participant) {
                    Text(verbatim: name).fontDesign(.rounded)
                } else {
                    Text(LocalizedStringKey("sharing_someone")).fontDesign(.rounded)
                }
                (Text(status) + Text(verbatim: " · ") + Text(permission))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
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
            CloudSync.shared.stoppedUsingSharedList()
            state = .privateList
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}


