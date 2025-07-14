import SwiftUI

struct SettingsView: View {
    @AppStorage("daysInsteadOfNumbers") private var daysInsteadOfNumbers: Bool = false
    @AppStorage("autoCompleteDish") private var autoCompleteDish: Bool = false // Nieuwe instelling
    @EnvironmentObject var viewModel: DishesViewModel
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text(LocalizedStringKey("settings_header")).font(.subheadline)) {
                        Toggle(isOn: $daysInsteadOfNumbers) {
                            Text(LocalizedStringKey("days_instead_of_numbers")).fontDesign(.rounded)
                        }

                        // 🔥 Nieuwe toggle die conditioneel wordt getoond
                        if daysInsteadOfNumbers {
                            Toggle(isOn: $autoCompleteDish) {
                                Text(LocalizedStringKey("auto_complete_daily")).fontDesign(.rounded)
                            }
                        }
                    }

                    Section {
                        NavigationLink(destination: LogboekView(viewModel: viewModel)) {
                            Text(LocalizedStringKey("history")).fontDesign(.rounded)
                        }
                    }
                }
                .navigationTitle(LocalizedStringKey("settings_title"))
                .navigationBarTitleDisplayMode(.inline)

                Text("v \(appVersion)")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
                    .fontDesign(.rounded)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(DishesViewModel())
    }
}
