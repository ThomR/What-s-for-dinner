import SwiftUI

struct SettingsView: View {
    @AppStorage("daysInsteadOfNumbers") private var daysInsteadOfNumbers: Bool = false
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text(LocalizedStringKey("settings_header"))) {
                        Toggle(isOn: $daysInsteadOfNumbers) {
                            Text(LocalizedStringKey("days_instead_of_numbers"))
                        }
                    }

                    Section {
                        NavigationLink(destination: LogboekView()) {
                            Text(LocalizedStringKey("history"))
                        }
                    }
                }

                Spacer()

                Text("v \(appVersion)")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
            }
            .navigationTitle(LocalizedStringKey("settings_title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
