//
//  FilterView.swift
//  Hoshu
//
//  Created by Waruha on 4/16/25.
//

import FluidGradient
import SwiftUI

struct FilterView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var filterType: FilterType
    @State private var availableFiles: [URL] = []
    @State private var isLoading = true
    @State private var showDeleteOptions = false

    init(filterType: Binding<FilterType>) {
        self._filterType = filterType

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
    }

    var body: some View {
        NavigationView {
            ZStack {
                FluidGradient(
                    blobs: [.black, .white],
                    highlights: [.black, .white],
                    speed: 0.5,
                    blur: 0.80
                )
                .background(.black)
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    Picker("Filter Type", selection: $filterType) {
                        Text("All").tag(FilterType.all)
                        Text("Rootful").tag(FilterType.rootful)
                        Text("Rootless").tag(FilterType.rootless)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)

                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Spacer()
                    } else if availableFiles.isEmpty {
                        Spacer()
                        Text("No .deb files found")
                            .foregroundColor(.white)
                            .padding()
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredFiles, id: \.self) { fileURL in
                                fileRow(fileURL: fileURL)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.clear)
                    }
                }
                .padding()
            }
            .navigationBarTitle(".DEB Files", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    showDeleteOptions.toggle()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
            .onAppear {
                loadFiles()
            }
            .actionSheet(isPresented: $showDeleteOptions) {
                ActionSheet(
                    title: Text("Delete Files"),
                    message: Text("Choose which files to delete"),
                    buttons: [
                        .destructive(Text("Delete All Rootful Files")) {
                            deleteFiles(type: .rootful)
                        },
                        .destructive(Text("Delete All Rootless Files")) {
                            deleteFiles(type: .rootless)
                        },
                        .destructive(Text("Delete All Files")) {
                            deleteFiles(type: .all)
                        },
                        .cancel(),
                    ]
                )
            }
        }
    }

    var filteredFiles: [URL] {
        switch filterType {
        case .all:
            return availableFiles
        case .rootful:
            return availableFiles.filter {
                $0.lastPathComponent.contains("iphoneos-arm")
                    && !$0.lastPathComponent.contains("iphoneos-arm64")
            }
        case .rootless:
            return availableFiles.filter {
                $0.lastPathComponent.contains("iphoneos-arm64")
            }
        }
    }

    func loadFiles() {
        isLoading = true

        DispatchQueue.global().async {
            let fileManager = FileManager.default
            let documentsDirectory = URL(fileURLWithPath: jbroot("/var/mobile/Hoshu"))

            do {
                let fileURLs = try fileManager.contentsOfDirectory(
                    at: documentsDirectory, includingPropertiesForKeys: nil)
                let debFiles = fileURLs.filter { $0.pathExtension.lowercased() == "deb" }

                DispatchQueue.main.async {
                    self.availableFiles = debFiles
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.availableFiles = []
                    self.isLoading = false

                    // Show error alert
                    UIApplication.shared.alert(
                        title: "Error",
                        body: "Failed to load files: \(error.localizedDescription)")
                }
            }
        }
    }

    func deleteFiles(type: FilterType) {
        // Show loading alert
        UIApplication.shared.alert(
            title: "Deleting...", body: "Please wait",
            withButton: false)

        DispatchQueue.global().async {
            let fileManager = FileManager.default
            let documentsDirectory = URL(fileURLWithPath: jbroot("/var/mobile/Hoshu"))

            do {
                let fileURLs = try fileManager.contentsOfDirectory(
                    at: documentsDirectory, includingPropertiesForKeys: nil)

                for fileURL in fileURLs {
                    if fileURL.pathExtension.lowercased() == "deb" {
                        let filename = fileURL.lastPathComponent

                        switch type {
                        case .rootful:
                            if filename.contains("iphoneos-arm")
                                && !filename.contains("iphoneos-arm64")
                            {
                                try fileManager.removeItem(at: fileURL)
                            }
                        case .rootless:
                            if filename.contains("iphoneos-arm64") {
                                try fileManager.removeItem(at: fileURL)
                            }
                        case .all:
                            try fileManager.removeItem(at: fileURL)
                        }
                    }
                }

                DispatchQueue.main.async {
                    UIApplication.shared.dismissAlert(animated: true) {
                        UIApplication.shared.alert(
                            title: "Success", body: "Files deleted successfully")
                        self.loadFiles()  // Refresh the file list
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.dismissAlert(animated: true) {
                        UIApplication.shared.alert(
                            title: "Error",
                            body: "Failed to delete files: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // File row with swipe actions
    private func fileRow(fileURL: URL) -> some View {
        fileRowContent(fileURL: fileURL)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .contextMenu {
                Button(action: {
                    deleteFile(at: fileURL)
                }) {
                    Label("Delete", systemImage: "trash")
                }

                Button(action: {
                    shareFile(at: fileURL)
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    shareFile(at: fileURL)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.blue)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    deleteFile(at: fileURL)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    private func fileRowContent(fileURL: URL) -> some View {
        HStack {
            Text(fileURL.lastPathComponent)
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding()
    }

    // Function to delete an individual file
    private func deleteFile(at url: URL) {
        // Show loading alert
        UIApplication.shared.alert(
            title: "Deleting...", body: "Please wait",
            withButton: false)

        DispatchQueue.global().async {
            do {
                try FileManager.default.removeItem(at: url)

                DispatchQueue.main.async {
                    // Remove the file from our list
                    if let index = self.availableFiles.firstIndex(of: url) {
                        self.availableFiles.remove(at: index)
                    }

                    UIApplication.shared.dismissAlert(animated: true) {
                        UIApplication.shared.alert(
                            title: "Success", body: "File deleted successfully")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.dismissAlert(animated: true) {
                        UIApplication.shared.alert(
                            title: "Error",
                            body: "Failed to delete file: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // Function to share a file
    private func shareFile(at url: URL) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        checkFileManagers(path: jbroot(url.path))
    }
}

struct FilterView_Previews: PreviewProvider {
    @State static var filterType: FilterType = .all

    static var previews: some View {
        FilterView(filterType: $filterType)
    }
}
