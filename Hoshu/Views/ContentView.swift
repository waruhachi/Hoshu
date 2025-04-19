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
    @State private var retroTerminal = false  // Restore retro terminal toggle
    @State private var isConverting = false  // Track converting state for button

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

                Button(action: {
                    if selectedFile == nil {
                        UISelectionFeedbackGenerator().selectionChanged()
                        showingSheet.toggle()
                    } else {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        if retroTerminal {
                            DispatchQueue.global().async {
                                let outputName = selectedFile!.deletingPathExtension()
                                    .lastPathComponent.replacingOccurrences(
                                        of: "iphoneos-arm", with: "iphoneos-arm64"
                                    )
                                let output = URL.init(
                                    fileURLWithPath:
                                        "/tmp/moe.waru.hoshu/\(outputName).deb")
                                DispatchQueue.main.async {
                                    UIApplication.shared.isIdleTimerDisabled = true
                                    self.terminalOutput = "Starting Script...\n"
                                    self.isProcessing = true
                                    self.showTerminalSheet = true
                                }
                                let (exitCode, _) = rootlessPatcher(
                                    debURL: selectedFile!
                                )
                                DispatchQueue.main.async {
                                    self.isProcessing = false
                                }
                                DispatchQueue.main.async {
                                    UIApplication.shared.isIdleTimerDisabled = false
                                    if exitCode != 0 {
                                        DispatchQueue.main.async {
                                            self.terminalOutput +=
                                                "\n❌ Error: Script failed with exit code \(exitCode)\n"
                                            self.selectedFile = nil
                                            let errorAlert = UIAlertController(
                                                title: "Error",
                                                message:
                                                    "Conversion failed with exit code \(exitCode)",
                                                preferredStyle: .alert)
                                            errorAlert.addAction(
                                                UIAlertAction(title: "OK", style: .default))
                                            UIApplication.shared.present(alert: errorAlert)
                                        }
                                        return
                                    }
                                    UserDefaults.standard.set(
                                        output.path, forKey: "lastConvertedFilePath")
                                    UserDefaults.standard.set(true, forKey: "ScriptCompleted")
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        if self.showTerminalSheet {
                                            self.showTerminalSheet = false
                                        }
                                    }
                                }
                            }
                        } else {
                            // Retro terminal is OFF: show "Converting" and then share
                            self.isConverting = true
                            self.terminalOutput = "Starting Script...\n"
                            DispatchQueue.global().async {
                                let outputName = selectedFile!.deletingPathExtension()
                                    .lastPathComponent.replacingOccurrences(
                                        of: "iphoneos-arm", with: "iphoneos-arm64"
                                    )
                                let output = URL.init(
                                    fileURLWithPath:
                                        "/tmp/moe.waru.hoshu/\(outputName).deb")
                                let (exitCode, _) = rootlessPatcher(
                                    debURL: selectedFile!
                                )
                                DispatchQueue.main.async {
                                    self.isConverting = false
                                    if exitCode != 0 {
                                        self.terminalOutput +=
                                            "\n❌ Error: Script failed with exit code \(exitCode)\n"
                                        self.selectedFile = nil
                                        let errorAlert = UIAlertController(
                                            title: "Error",
                                            message:
                                                "Conversion failed with exit code \(exitCode)",
                                            preferredStyle: .alert)
                                        errorAlert.addAction(
                                            UIAlertAction(title: "OK", style: .default))
                                        UIApplication.shared.present(alert: errorAlert)
                                        return
                                    }
                                    UserDefaults.standard.set(
                                        output.path, forKey: "lastConvertedFilePath")
                                    UserDefaults.standard.set(true, forKey: "ScriptCompleted")
                                    // Show share options immediately
                                    self.handleScriptCompletion()
                                    // Reset selected file and output
                                    self.selectedFile = nil
                                    self.terminalOutput = ""
                                }
                            }
                        }
                    }
                }) {
                    if selectedFile == nil {
                        Text("Select .deb file")
                    } else if isConverting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Converting")
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("Convert .deb")
                    }
                }
                .buttonStyle(TintedButton(color: .white, fullwidth: true))
                .padding(.horizontal, 30)
                .padding(.top, 30)
                .padding(.bottom, 20)
                .disabled(isConverting)

                // Retro Terminal toggle
                Toggle(isOn: $retroTerminal) {
                    Text("Retro Terminal")
                        .foregroundColor(.white)
                }
                .toggleStyle(SwitchToggleStyle(tint: .gray))
                .padding(.horizontal, 30)
                .padding(.vertical, 5)
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
                        // Show clear cache alert
                        let alert = UIAlertController(
                            title: "Clear Cache?",
                            message:
                                "Are you sure you want to clear all files from the cache? This cannot be undone.",
                            preferredStyle: .alert
                        )
                        alert.addAction(
                            UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                        alert.addAction(
                            UIAlertAction(
                                title: "Clear", style: .destructive,
                                handler: { _ in
                                    do {
                                        let fileManager = FileManager.default
                                        let cacheURL = URL(
                                            fileURLWithPath: "/tmp/moe.waru.hoshu")
                                        let fileURLs = try fileManager.contentsOfDirectory(
                                            at: cacheURL, includingPropertiesForKeys: nil)
                                        for fileURL in fileURLs {
                                            try? fileManager.removeItem(at: fileURL)
                                        }
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    } catch {
                                        UIApplication.shared.alert(
                                            title: "Error!",
                                            body: "Failed to clear cache.",
                                            withButton: false)
                                    }
                                }))
                        UIApplication.shared.present(alert: alert)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showCreditsSheet) {
                CreditsView()
                    .edgesIgnoringSafeArea(.all)
                    .modifier(SheetPresentationModifier())
            }
            .sheet(
                isPresented: $showTerminalSheet,
                onDismiss: {
                    // Check if Script completed successfully
                    if UserDefaults.standard.bool(forKey: "ScriptCompleted") {
                        handleScriptCompletion()
                    }
                }
            ) {
                TerminalView(
                    outputText: $terminalOutput, isProcessing: $isProcessing,
                    retroStyle: true  // Always retro when shown
                )
                .edgesIgnoringSafeArea(.all)
                .modifier(SheetPresentationModifier())
            }
        }
    }

    // Helper function to handle script completion
    private func handleScriptCompletion() {
        // Reset the flag
        UserDefaults.standard.set(false, forKey: "ScriptCompleted")

        // Get the output path
        if let outputPath = UserDefaults.standard.string(
            forKey: "lastConvertedFilePath")
        {
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
                                outputPath)
                        }))
            }

            if IsAppAvailable("xyz.willy.Zebra") {
                alert.addAction(
                    .init(
                        title: "Zebra", style: .default,
                        handler: { _ in
                            ShareFileToApp(
                                "xyz.willy.Zebra",
                                outputPath)
                        }))
            }

            if IsAppAvailable("com.roothide.patcher") {
                alert.addAction(
                    .init(
                        title: "RootHide Patcher", style: .default,
                        handler: { _ in
                            ShareFileToApp(
                                "com.roothide.patcher",
                                outputPath)
                        }))
            }

            if IsAppAvailable("com.tigisoftware.Filza") {
                alert.addAction(
                    .init(
                        title: "Filza", style: .default,
                        handler: { _ in
                            ShareFileToApp(
                                "com.tigisoftware.Filza",
                                outputPath)
                        }))
            }

            alert.addAction(
                .init(
                    title: "Share", style: .default,
                    handler: { _ in
                        UIImpactFeedbackGenerator(
                            style: .soft
                        ).impactOccurred()
                    }))

            // Ensure we present on the main thread after a slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                UIApplication.shared.present(alert: alert)
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
