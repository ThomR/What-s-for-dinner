import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(Preferences.Key.showsDayLabels, store: Preferences.defaults)
    private var showsDayLabels: Bool = false
    @AppStorage(Preferences.Key.autoAdvance, store: Preferences.defaults)
    private var autoAdvance: Bool = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(LocalizedStringKey("settings_header")).font(.subheadline)) {
                    Toggle(isOn: $showsDayLabels) {
                        Text(LocalizedStringKey("days_instead_of_numbers")).fontDesign(.rounded)
                    }

                    if showsDayLabels {
                        Toggle(isOn: $autoAdvance) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("auto_complete_daily")).fontDesign(.rounded)
                                Text(LocalizedStringKey("auto_complete_daily_hint"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                SharingSettingsView()

                Section {
                    NavigationLink {
                        LogboekView().environmentObject(store)
                    } label: {
                        Text(LocalizedStringKey("history")).fontDesign(.rounded)
                    }
                }

                Section {
                    Text("v \(appVersion)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .fontDesign(.rounded)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(LocalizedStringKey("settings_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("done")) { dismiss() }
                }
            }
            // De instellingen bepalen mee hoe de planning eruitziet, dus meteen
            // doorrekenen in plaats van wachten tot de app opnieuw opent.
            .onChange(of: showsDayLabels) { store.refresh() }
            .onChange(of: autoAdvance) { store.refresh() }
        }
    }
}
