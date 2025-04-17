//
//  ContentView.swift
//  Hoshu
//
//  Created by Анохин Юрий on 15.04.2023.
//

import FluidGradient
import SwiftUI

struct ContentView: View {
    @State private var selectedFile: URL?
    @State private var showingSheet = false
    @State private var showFilterSheet = false
    @State private var showCreditsSheet = false
    @State private var showTerminalSheet = false
    @State private var terminalOutput = ""
    @State private var isProcessing = false
    @State private var filterType: FilterType = .all
    @State private var showDebugTerminal = false  // Added debug toggle state
    @State private var retroTerminal = false  // Added retro terminal toggle state

    // Store the observer to be able to remove it later
    @State private var terminalOutputObserver: NSObjectProtocol? = nil

    var body: some View {

        let _ = NotificationCenter.default.addObserver(
            forName: Notification.Name("hoshuFileOpen"), object: nil,
            queue: nil
        ) { noti in
            UIApplication.shared.connectedScenes
                .first(where: { $0 is UIWindowScene })
                .flatMap({ $0 as? UIWindowScene })?.windows.first?
                .rootViewController?
                .presentedViewController?.dismiss(animated: true)
            selectedFile = noti.object as? URL
        }

        NavigationView {
            VStack(spacing: 10) {
                ZStack {
                    if let debfile = selectedFile {
                        Text(debfile.lastPathComponent)
                            .foregroundColor(.white)
                    }
                }
                .frame(height: 50)

                Button(
                    selectedFile == nil ? "Select .deb file" : "Convert .deb"
                ) {
                    if selectedFile == nil {
                        UISelectionFeedbackGenerator().selectionChanged()
                        showingSheet.toggle()
                    } else {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)

                        DispatchQueue.global().async {
                            // Always assume we're converting rootful to rootless
                            // Get filename and always replace iphoneos-arm with iphoneos-arm64
                            let outputName = selectedFile!.deletingPathExtension()
                                .lastPathComponent.replacingOccurrences(
                                    of: "iphoneos-arm", with: "iphoneos-arm64"
                                )

                            let output = URL.init(
                                fileURLWithPath: "/var/mobile/Hoshu/\(outputName).deb"
                            )

                            DispatchQueue.main.async {
                                UIApplication.shared.isIdleTimerDisabled = true
                                // Clear previous output and show terminal sheet
                                self.terminalOutput = "Starting Script...\n"
                                self.isProcessing = true

                                // Only show terminal if debug mode is enabled
                                if self.showDebugTerminal {
                                    self.showTerminalSheet = true
                                } else {
                                    // Show loading alert
                                    let alert = UIAlertController(
                                        title: "Converting",
                                        message: "Please wait while the file is being converted...",
                                        preferredStyle: .alert)
                                    UIApplication.shared.present(alert: alert)
                                }
                            }

                            // Use rootlessPatcher function and capture output in real-time
                            let (exitCode, _) = rootlessPatcher(
                                debURL: selectedFile!
                            )

                            // Update processing state when completed
                            DispatchQueue.main.async {
                                self.isProcessing = false

                                // If we're not showing the terminal, dismiss the alert
                                if !self.showDebugTerminal {
                                    UIApplication.shared.dismiss()
                                }
                            }

                            DispatchQueue.main.async {
                                UIApplication.shared.isIdleTimerDisabled = false

                                if exitCode != 0 {
                                    // Keep terminal open to show error if debug is on
                                    DispatchQueue.main.async {
                                        self.terminalOutput +=
                                            "\n❌ Error: Script failed with exit code \(exitCode)\n"
                                        // Clear selected file on error too
                                        self.selectedFile = nil

                                        // Show error alert if terminal is not visible
                                        if !self.showDebugTerminal {
                                            let errorAlert = UIAlertController(
                                                title: "Error",
                                                message:
                                                    "Conversion failed with exit code \(exitCode)",
                                                preferredStyle: .alert)

                                            errorAlert.addAction(
                                                UIAlertAction(title: "OK", style: .default))
                                            UIApplication.shared.present(alert: errorAlert)
                                        }
                                    }
                                    return
                                }

                                // Save the output information for later use when terminal is dismissed
                                UserDefaults.standard.set(
                                    output.path, forKey: "lastConvertedFilePath")
                                UserDefaults.standard.set(true, forKey: "ScriptCompleted")

                                DispatchQueue.main.async {
                                    // If we're showing debug terminal, auto-dismiss it after delay
                                    if self.showDebugTerminal {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                            if self.showTerminalSheet {
                                                self.showTerminalSheet = false
                                            }
                                        }
                                    } else {
                                        // If we're not showing the terminal, trigger the share options directly
                                        self.handleScriptCompletion()
                                    }
                                }
                            }
                        }
                    }
                }
                .buttonStyle(TintedButton(color: .white, fullwidth: true))
                .padding(.horizontal, 30)
                .padding(.top, 30)
                .padding(.bottom, 20)

                // Container for toggles with fixed height to prevent UI shifting
                VStack(alignment: .leading, spacing: 5) {
                    // Debug toggle button
                    Toggle(isOn: $showDebugTerminal) {
                        Text("Debug")
                            .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .gray))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 5)
                    .onChange(of: showDebugTerminal) { newValue in
                        if !newValue {
                            // Reset retro terminal when debug is toggled off
                            retroTerminal = false
                        }
                    }

                    // Fixed space for Retro Terminal toggle
                    ZStack(alignment: .leading) {
                        // Empty view to maintain spacing when toggle is hidden
                        Color.clear
                            .frame(height: 44)  // Approximate height of a toggle

                        // Retro Terminal toggle button - only show when debug is enabled
                        if showDebugTerminal {
                            Toggle(isOn: $retroTerminal) {
                                Text("Retro Terminal")
                                    .foregroundColor(.white)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .gray))
                            .padding(.horizontal, 30)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                FluidGradient(
                    blobs: [.black],
                    highlights: [Color(red: 36 / 255, green: 36 / 255, blue: 36 / 255)],
                    speed: 0.5,
                    blur: 0.80
                )
                .background(.black)
            )
            .ignoresSafeArea()
            .onAppear {
                folderCheck()

                // Add terminal output observer when view appears (only if not already set up)
                if terminalOutputObserver == nil {
                    terminalOutputObserver = NotificationCenter.default.addObserver(
                        forName: Notification.Name("terminalOutputUpdate"),
                        object: nil,
                        queue: .main
                    ) { noti in
                        if let outputLine = noti.object as? String {
                            self.terminalOutput += outputLine
                        }
                    }
                }
            }
            .onDisappear {
                // Remove observer when view disappears to prevent multiple registrations
                if let observer = terminalOutputObserver {
                    NotificationCenter.default.removeObserver(observer)
                    terminalOutputObserver = nil
                }
            }
            .sheet(isPresented: $showingSheet) {
                DocumentPicker(selectedFile: $selectedFile)
                    .edgesIgnoringSafeArea(.all)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showCreditsSheet.toggle()
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Show filter sheet
                        showFilterSheet.toggle()
                    }) {
                        Image(systemName: "folder")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterView(filterType: $filterType)
                    .edgesIgnoringSafeArea(.all)
                    .modifier(SheetPresentationModifier())
            }
            .sheet(isPresented: $showCreditsSheet) {
                CreditsView()
                    .edgesIgnoringSafeArea(.all)
                    .modifier(SheetPresentationModifier())
            }
            .sheet(
                isPresented: $showTerminalSheet,
                onDismiss: {
                    NSLog("[Hoshu] Terminal sheet dismissed")
                    // Check if Script completed successfully
                    if UserDefaults.standard.bool(forKey: "ScriptCompleted") {
                        handleScriptCompletion()
                    }
                }
            ) {
                TerminalView(
                    outputText: $terminalOutput, isProcessing: $isProcessing,
                    retroStyle: retroTerminal
                )
                .edgesIgnoringSafeArea(.all)
                .modifier(SheetPresentationModifier())
            }
        }
    }

    // Helper function to handle script completion
    private func handleScriptCompletion() {
        NSLog("[Hoshu] Script completed flag found")
        // Reset the flag
        UserDefaults.standard.set(false, forKey: "ScriptCompleted")

        // Get the output path
        if let outputPath = UserDefaults.standard.string(
            forKey: "lastConvertedFilePath")
        {
            NSLog("[Hoshu] Output path found: \(outputPath)")
            // Reset selected file
            selectedFile = nil

            // Show share options immediately
            let alert = UIAlertController(
                title: "Done",
                message:
                    "Your .deb file has been successfully converted to rootless format. What would you like to do?",
                preferredStyle: .alert)

            if IsAppAvailable("org.coolstar.SileoStore") {
                alert.addAction(
                    .init(
                        title: "Sileo", style: .default,
                        handler: { _ in
                            ShareFileToApp(
                                "org.coolstar.SileoStore",
                                jbroot(outputPath))
                        }))
            }

            if IsAppAvailable("xyz.willy.Zebra") {
                alert.addAction(
                    .init(
                        title: "Zebra", style: .default,
                        handler: { _ in
                            ShareFileToApp(
                                "xyz.willy.Zebra",
                                jbroot(outputPath))
                        }))
            }

            if IsAppAvailable("com.tigisoftware.Filza") {
                alert.addAction(
                    .init(
                        title: "Filza", style: .default,
                        handler: { _ in
                            ShareFileToApp(
                                "com.tigisoftware.Filza",
                                jbroot(outputPath))
                        }))
            }

            alert.addAction(
                .init(
                    title: "Share", style: .default,
                    handler: { _ in
                        UIImpactFeedbackGenerator(
                            style: .soft
                        ).impactOccurred()
                        checkFileManagers(
                            path: jbroot(outputPath))
                    }))

            NSLog("[Hoshu] Presenting share alert")
            // Ensure we present on the main thread after a slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                UIApplication.shared.present(alert: alert)
                NSLog("[Hoshu] Share alert presented")
            }
        }
    }
}

// iOS version compatibility modifiers
struct SheetPresentationModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents([.large])
            // .interactiveDismissDisabled()
        } else {
            content
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

enum FilterType {
    case all, rootful, rootless
}

// Extensions for UIApplication to handle alerts
extension UIApplication {
    func present(alert: UIAlertController) {
        DispatchQueue.main.async {
            self.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .filter { $0.isKeyWindow }
                .first?
                .rootViewController?
                .present(alert, animated: true)
        }
    }

    func dismiss() {
        DispatchQueue.main.async {
            self.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .filter { $0.isKeyWindow }
                .first?
                .rootViewController?
                .dismiss(animated: true)
        }
    }
}
