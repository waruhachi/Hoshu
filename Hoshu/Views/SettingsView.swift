import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var activeAlert: ActiveAlert?

    var onClearCache: () -> Void

    enum ActiveAlert: Identifiable {
        case clearCache
        var id: Int { hashValue }
    }

    private let rulesetPath =
        "/var/jb/Library/Application%20Support/rootless-patcher/ConversionRuleset.json"

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    settingsContent
                }
            } else {
                NavigationView {
                    settingsContent
                }
            }
        }
    }

    private var settingsContent: some View {
        ZStack {
            Fluid {}
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("App Settings")
                            .font(.headline)
                            .foregroundColor(.white)
                        Toggle(
                            "Alternative File Picker",
                            isOn: $appState.showAlternativeFilePicker
                        )
                        .toggleStyle(SwitchToggleStyle(tint: .gray))
                        .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Maintenance")
                            .font(.headline)
                            .foregroundColor(.white)
                        Button {
                            activeAlert = .clearCache
                        } label: {
                            Label("Clear Cache", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CREDITS")
                            .font(.headline)
                            .foregroundColor(.white)
                        ForEach(Contributor.samples) { contributor in
                            ContributorView(
                                imageURL: contributor.imageURL,
                                name: contributor.name,
                                profileURL: contributor.profileURL,
                                contribution: contributor.contribution,
                                projectURL: contributor.projectURL
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .clearCache:
                    return Alert(
                        title: Text("Clear Cache"),
                        message: Text(
                            "Are you sure you want to clear the cache?"
                        ),
                        primaryButton: .destructive(Text("Clear")) {
                            onClearCache()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .tint(.white)
        }
    }
}
