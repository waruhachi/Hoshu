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

                        // Show loading alert
                        UIApplication.shared.alert(
                            title: "Converting...", body: "Please wait",
                            withButton: false)

                        DispatchQueue.global().async {
                            let name = selectedFile!.deletingPathExtension()
                                .lastPathComponent.replacingOccurrences(
                                    of: "iphoneos-arm", with: "iphoneos-arm64"
                                )

                            let output = URL.init(
                                fileURLWithPath: "/var/mobile/Hoshu/\(name).deb"
                            )

                            DispatchQueue.main.async {
                                UIApplication.shared.isIdleTimerDisabled = true
                            }

                            let (exitCode, outputText) = repackDeb(
                                debURL: selectedFile!
                            )

                            DispatchQueue.main.async {
                                UIApplication.shared.isIdleTimerDisabled = false

                                // Dismiss the loading alert and show results
                                UIApplication.shared.dismissAlert(animated: true) {
                                    if exitCode != 0 {
                                        // Show error if conversion failed
                                        UIApplication.shared.alert(
                                            title: "Error(\(exitCode))",
                                            body: outputText)
                                        return
                                    }

                                    // Reset selected file
                                    selectedFile = nil

                                    // Show share options
                                    let alert = UIAlertController(
                                        title: "Done",
                                        message:
                                            "Your .deb file has been successfully converted. What would you like to do?",
                                        preferredStyle: .alert)

                                    if IsAppAvailable("org.coolstar.SileoStore") {
                                        alert.addAction(
                                            .init(
                                                title: "Sileo", style: .default,
                                                handler: { _ in
                                                    ShareFileToApp(
                                                        "org.coolstar.SileoStore",
                                                        jbroot(output.path))
                                                }))
                                    }

                                    if IsAppAvailable("xyz.willy.Zebra") {
                                        alert.addAction(
                                            .init(
                                                title: "Zebra", style: .default,
                                                handler: { _ in
                                                    ShareFileToApp(
                                                        "xyz.willy.Zebra",
                                                        jbroot(output.path))
                                                }))
                                    }

                                    if IsAppAvailable("com.tigisoftware.Filza") {
                                        alert.addAction(
                                            .init(
                                                title: "Filza", style: .default,
                                                handler: { _ in
                                                    ShareFileToApp(
                                                        "com.tigisoftware.Filza",
                                                        jbroot(output.path))
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
                                                    path: jbroot(output.path))
                                            }))

                                    UIApplication.shared.present(alert: alert)
                                }
                            }
                        }
                    }
                }
                .buttonStyle(TintedButton(color: .white, fullwidth: true))
                .padding(30)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                FluidGradient(
                    blobs: [.black, .white],
                    highlights: [.black, .white],
                    speed: 0.5,
                    blur: 0.80
                )
                .background(.black)
            )
            .ignoresSafeArea()
            .onAppear {
                folderCheck()
            }
            .sheet(isPresented: $showingSheet) {
                DocumentPicker(selectedFile: $selectedFile)
                    .edgesIgnoringSafeArea(.all)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: CreditsView()) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white)
                    }
                }
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
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
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
