import AuxiliaryExecute
import FluidGradient
import Foundation
import MobileCoreServices
import SwiftUI
import UniformTypeIdentifiers

// UIActivityViewController wrapper for SwiftUI
struct ShareSheetView: UIViewControllerRepresentable {
    let filePath: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let fileURL = URL(fileURLWithPath: filePath)
        let activityViewController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        return activityViewController
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
        // Nothing to do here
    }
}

// Alternative File Picker View that looks like a TableView
struct AlternativeFilePicker: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var appState: AppState
    @State private var currentPath: String = "/"
    @State private var directoryContents: [FileItem] = []
    @State private var searchText: String = ""
    @State private var detectedDirectoryPath: String? = nil
    @State private var showingSortOptions = false
    @State private var sortOption: SortOption = .nameAscending
    var onFileSelected: (URL) -> Void

    // Sort options enum
    enum SortOption: String, CaseIterable, Identifiable {
        case nameAscending = "Name (A-Z)"
        case nameDescending = "Name (Z-A)"
        case dateNewest = "Date (Newest First)"
        case dateOldest = "Date (Oldest First)"
        case sizeSmallest = "Size (Smallest First)"
        case sizeLargest = "Size (Largest First)"

        var id: String { self.rawValue }

        // Always use a consistent icon regardless of sort option
        static let sortIcon = "arrow.up.arrow.down"

        // Convert from integer index for storage
        static func fromIndex(_ index: Int) -> SortOption {
            let allOptions = SortOption.allCases
            guard index >= 0 && index < allOptions.count else {
                return .nameAscending  // Default if out of range
            }
            return allOptions[index]
        }

        // Convert to integer index for storage
        var toIndex: Int {
            return SortOption.allCases.firstIndex(of: self) ?? 0
        }
    }

    struct FileItem: Identifiable {
        var name: String
        var path: String
        var isDirectory: Bool
        var modificationDate: Date?
        var size: Int64 = 0

        var id: String { path }

        var iconName: String {
            return isDirectory ? "folder.fill" : "doc.fill"
        }

        var color: Color {
            return isDirectory ? .cyan : .white
        }

        var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }

        var formattedDate: String {
            guard let date = modificationDate else { return "Unknown" }
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }

    // Computed property for filtered and sorted directory contents
    private var filteredContents: [FileItem] {
        let base: [FileItem] =
            searchText.isEmpty
            ? directoryContents
            : directoryContents.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        return base.sorted { (a: FileItem, b: FileItem) -> Bool in
            switch sortOption {
            case .nameAscending:
                return a.name.localizedStandardCompare(b.name)
                    == .orderedAscending
            case .nameDescending:
                return a.name.localizedStandardCompare(b.name)
                    == .orderedDescending
            case .dateNewest:
                guard let d1 = a.modificationDate, let d2 = b.modificationDate
                else {
                    return a.isDirectory && !b.isDirectory
                }
                return d1 > d2
            case .dateOldest:
                guard let d1 = a.modificationDate, let d2 = b.modificationDate
                else {
                    return a.isDirectory && !b.isDirectory
                }
                return d1 < d2
            case .sizeSmallest:
                if a.isDirectory && !b.isDirectory { return false }
                if !a.isDirectory && b.isDirectory { return true }
                return a.size < b.size
            case .sizeLargest:
                if a.isDirectory && !b.isDirectory { return false }
                if !a.isDirectory && b.isDirectory { return true }
                return a.size > b.size
            }
        }
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    pickerContent
                }
            } else {
                NavigationView {
                    pickerContent
                }
            }
        }
        .onAppear {
            // Initialize from saved preferences
            currentPath = appState.lastFilePickerPath
            sortOption = SortOption.fromIndex(appState.lastFilePickerSortOption)
            loadDirectoryContents()
        }
        // Add confirmation dialog for sort options
        .confirmationDialog(
            "Sort By",
            isPresented: $showingSortOptions,
            titleVisibility: .visible
        ) {
            Button("Cancel", role: .cancel) {}

            ForEach(SortOption.allCases) { option in
                Button(option.rawValue) {
                    sortOption = option
                    // Save the sort option
                    appState.lastFilePickerSortOption = option.toIndex
                    // Reload the directory contents with new sort option
                    loadDirectoryContents()
                }
            }
        }
    }

    private var pickerContent: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack {
                // Search field (now positioned first)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)

                    TextField(
                        "Search files or enter a path",
                        text: $searchText
                    )
                    .foregroundStyle(.white)
                    .tint(.white)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .onChange(of: searchText) { _ in
                        checkForDirectoryPath()
                    }
                    // Make placeholder text brighter
                    .placeholder(when: searchText.isEmpty) {
                        Text("Search files or enter a path")
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            detectedDirectoryPath = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                                .padding(2)
                        }
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 10)

                // Path jump button when a valid path is typed
                if let directoryPath = detectedDirectoryPath {
                    Button(action: {
                        navigateToDirectory(directoryPath)
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(.cyan)
                            Text("Go to \(directoryPath)")
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                    }
                    .padding(.top, 5)
                }

                // Breadcrumbs now below search bar with matching horizontal padding
                HStack {
                    // Display path components as separate tappable items
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            let pathComponents = currentPath.split(
                                separator: "/"
                            )

                            // Root directory
                            Text("/")
                                .foregroundStyle(.white)
                                .font(.system(size: 16))
                                .onTapGesture {
                                    navigateToDirectory("/")
                                }

                            // Other path components
                            ForEach(0..<pathComponents.count, id: \.self) {
                                index in
                                let component = pathComponents[index]
                                if !component.isEmpty {
                                    ZStack(alignment: .bottom) {
                                        Text("\(component)")
                                            .foregroundStyle(.white)
                                            .font(.system(size: 16))
                                            .lineLimit(1)
                                            .onTapGesture {
                                                // Calculate the path up to this component
                                                let pathToHere =
                                                    "/"
                                                    + pathComponents[
                                                        0...index
                                                    ].joined(
                                                        separator: "/"
                                                    )
                                                navigateToDirectory(
                                                    pathToHere
                                                )
                                            }

                                        // Custom underline compatible with iOS 15 and 16
                                        Rectangle()
                                            .frame(height: 2.0)
                                            .foregroundStyle(.white)
                                            .offset(y: 1)
                                    }

                                    if index < pathComponents.count - 1 {
                                        Text("/")
                                            .foregroundStyle(.white)
                                            .font(.system(size: 12))
                                    }
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 5)
                .padding(.bottom, 5)

                ZStack {
                    // This provides a solid black background behind the List
                    Color.black.ignoresSafeArea()

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredContents) { item in
                                HStack {
                                    Image(systemName: item.iconName)
                                        .foregroundStyle(item.color)
                                        .frame(width: 25)

                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .foregroundStyle(
                                                item.name.hasSuffix(".deb")
                                                    || item.isDirectory
                                                    ? .white : .gray
                                            )

                                        HStack {
                                            Text(item.formattedDate)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.gray)

                                            if !item.isDirectory {
                                                Text(item.formattedSize)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.gray)
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.black)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if item.isDirectory {
                                        navigateToDirectory(item.path)
                                    } else if item.name.hasSuffix(".deb") {
                                        // Auto-select file and dismiss picker
                                        onFileSelected(
                                            URL(fileURLWithPath: item.path)
                                        )
                                        isPresented = false
                                    }
                                }
                            }
                        }
                        .background(Color.black)
                    }
                    .background(Color.black)
                }
                .background(Color.black)
            }
            .background(Color.black)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white)
                        .padding()
                }
            }

            // Home button
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    navigateToDirectory("/")
                }) {
                    Image(systemName: "house.fill")
                        .foregroundStyle(.white)
                }
            }

            // Sort button
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showingSortOptions.toggle()
                }) {
                    Image(systemName: SortOption.sortIcon)
                        .foregroundStyle(.white)
                }
            }

            // Back button, only shown when not at root
            ToolbarItem(placement: .navigationBarLeading) {
                if currentPath != "/" {
                    Button(action: {
                        navigateUp()
                    }) {
                        Image(systemName: "arrowshape.turn.up.backward")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func loadDirectoryContents() {
        let fileManager = FileManager.default
        directoryContents.removeAll()

        do {
            let contents = try fileManager.contentsOfDirectory(
                atPath: currentPath
            )

            // Add all directory contents, including hidden files (those starting with ".")
            for item in contents.sorted() {
                // Skip "." (current directory) but show other hidden files/folders
                if item == "." {
                    continue
                }

                let fullPath = (currentPath as NSString).appendingPathComponent(
                    item
                )
                var isDir: ObjCBool = false

                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir)
                {
                    // Get file attributes to retrieve date and size information
                    let attributes = try? fileManager.attributesOfItem(
                        atPath: fullPath
                    )
                    let modificationDate =
                        attributes?[.modificationDate] as? Date
                    let fileSize = attributes?[.size] as? Int64 ?? 0

                    directoryContents.append(
                        FileItem(
                            name: item,
                            path: fullPath,
                            isDirectory: isDir.boolValue,
                            modificationDate: modificationDate,
                            size: fileSize
                        )
                    )
                }
            }
        } catch {
            print("Error reading directory: \(error)")
        }
    }

    private func navigateToDirectory(_ path: String) {
        currentPath = path
        // Save the current path
        appState.lastFilePickerPath = path
        // Clear search text when navigating to a new directory
        searchText = ""
        loadDirectoryContents()
    }

    private func navigateUp() {
        currentPath = (currentPath as NSString).deletingLastPathComponent
        if currentPath.isEmpty {
            currentPath = "/"
        }
        // Save the current path
        appState.lastFilePickerPath = currentPath
        // Clear search text when navigating up
        searchText = ""
        loadDirectoryContents()
    }

    private func isValidDirectoryPath(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: path,
            isDirectory: &isDir
        )
        return exists && isDir.boolValue
    }

    private func checkForDirectoryPath() {
        // First check if the search text is a valid path (starts with /)
        if searchText.hasPrefix("/") {
            // Check if it's a valid directory
            if isValidDirectoryPath(searchText) {
                detectedDirectoryPath = searchText
            } else {
                detectedDirectoryPath = nil
            }
        } else {
            detectedDirectoryPath = nil
        }
    }
}

// NotificationHandler class to handle notifications without capturing ContentView's self
class DebFileNotificationHandler {
    var onFileOpened: ((URL) -> Void)?
    private var notificationObserver: Any?

    init(onFileOpened: @escaping (URL) -> Void) {
        self.onFileOpened = onFileOpened
        setupNotificationObserver()
    }

    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("hoshuFileOpen"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            UIApplication.shared.connectedScenes
                .first(where: { $0 is UIWindowScene })
                .flatMap({ $0 as? UIWindowScene })?.windows.first?
                .rootViewController?
                .presentedViewController?.dismiss(animated: true)

            if let fileURL = notification.object as? URL,
                let onFileOpened = self?.onFileOpened
            {
                onFileOpened(fileURL)
            }
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// Helper to clean iOS 15 duplicate file number suffixes
extension String {
    func cleanIOSFileSuffix() -> String {
        // Match patterns like "-1.deb", "-2.deb", etc.
        let pattern = "-\\d+(\\.\\w+)$"

        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(self.startIndex..<self.endIndex, in: self)

            if let match = regex.firstMatch(in: self, options: [], range: range)
            {
                let fullRange = match.range
                let extensionRange = match.range(at: 1)

                if let extensionRange = Range(extensionRange, in: self),
                    let fullRange = Range(fullRange, in: self)
                {
                    let fileExtension = String(self[extensionRange])
                    let cleanedName = self.replacingCharacters(
                        in: fullRange,
                        with: fileExtension
                    )
                    return cleanedName
                }
            }
        }

        return self
    }
}

private struct DownloadErrorAlert: Identifiable {
    let id = UUID()
    let message: String
}

struct ContentView: View {
    @State private var isFilePickerPresented = false
    @State private var isAlternativeFilePickerPresented = false
    @State private var selectedFilePath: String?
    @State private var isTerminalViewPresented = false
    @State private var showSystemShareSheet = false
    @EnvironmentObject private var appState: AppState
    @State private var conversionCompleted = false
    @State private var controlData: Control? = nil
    @State private var showPackageInfoSheet = false
    @State private var notificationHandler: DebFileNotificationHandler?
    @State private var showRootlessAlert = false
    @State private var isSettingsPresented = false
    // URL import states
    @State private var showURLImportPrompt = false
    @State private var urlToImport: String = ""
    @State private var isDownloading = false
    @State private var downloadErrorAlert: DownloadErrorAlert? = nil
    @State private var downloadProgress: Double = 0.0  // 0.0 - 1.0
    @State private var isPreflighting = false
    @State private var downloadSpeedBytesPerSec: Double = 0
    @State private var downloadETASeconds: Double = 0
    @State private var activeDownloader: DebURLDownloader? = nil
    @State private var isUnknownSize: Bool = false
    @State private var downloadedBytes: Int64 = 0
    @State private var retryAttempt: Int = 0
    private let maxDownloadRetries: Int = 3
    @State private var cancelRequested: Bool = false

    // Temporary directory paths
    private let tempDirectory = "/tmp/moe.waru.hoshu/"
    private let stagingDirectory = "/tmp/moe.waru.hoshu/.staging/"
    private let importingDirectory = "/tmp/moe.waru.hoshu/.importing/"
    private let convertedDirectory = "/tmp/moe.waru.hoshu/.converted/"

    // Define a constant for the .deb UTType
    private let debUTType = UTType(filenameExtension: "deb")

    // Create the temporary directories if they don't exist
    private func ensureTempDirectoryExists() {
        let fileManager = FileManager.default
        // Check and create main temp directory
        if !fileManager.fileExists(atPath: tempDirectory) {
            do {
                try fileManager.createDirectory(
                    atPath: tempDirectory,
                    withIntermediateDirectories: true
                )
            } catch {
                NSLog(
                    "[Hoshu] Error creating directory: \(error.localizedDescription)"
                )
            }
        }

        // Check and create staging directory
        if !fileManager.fileExists(atPath: stagingDirectory) {
            do {
                try fileManager.createDirectory(
                    atPath: stagingDirectory,
                    withIntermediateDirectories: true
                )
            } catch {
                NSLog(
                    "[Hoshu] Error creating staging directory: \(error.localizedDescription)"
                )
            }
        }

        // Check and create importing directory
        if !fileManager.fileExists(atPath: importingDirectory) {
            do {
                try fileManager.createDirectory(
                    atPath: importingDirectory,
                    withIntermediateDirectories: true
                )
            } catch {
                NSLog(
                    "[Hoshu] Error creating importing directory: \(error.localizedDescription)"
                )
            }
        }

        // Check and create converted directory
        if !fileManager.fileExists(atPath: convertedDirectory) {
            do {
                try fileManager.createDirectory(
                    atPath: convertedDirectory,
                    withIntermediateDirectories: true
                )
            } catch {
                NSLog(
                    "[Hoshu] Error creating converted directory: \(error.localizedDescription)"
                )
            }
        }
    }

    // Clear the cache directory
    private func clearCache() {
        let fileManager = FileManager.default

        do {
            // Clear main temp directory
            let fileURLs = try fileManager.contentsOfDirectory(
                atPath: tempDirectory
            )

            // Delete each item (except the special directories)
            for file in fileURLs {
                if file != ".staging" && file != ".importing"
                    && file != ".converted"
                {
                    let filePath = tempDirectory + file
                    try fileManager.removeItem(atPath: filePath)
                    NSLog("[Hoshu] Deleted: \(file)")
                }
            }

            // Clear staging directory
            let stagingURLs = try fileManager.contentsOfDirectory(
                atPath: stagingDirectory
            )

            // Delete each item in staging
            for file in stagingURLs {
                let filePath = stagingDirectory + file
                try fileManager.removeItem(atPath: filePath)
                NSLog("[Hoshu] Deleted staging: \(file)")
            }

            // Clear importing directory
            let importingURLs = try fileManager.contentsOfDirectory(
                atPath: importingDirectory
            )

            // Delete each item in importing
            for file in importingURLs {
                let filePath = importingDirectory + file
                try fileManager.removeItem(atPath: filePath)
                NSLog("[Hoshu] Deleted importing: \(file)")
            }

            // Clear converted directory
            let convertedURLs = try fileManager.contentsOfDirectory(
                atPath: convertedDirectory
            )

            // Delete each item in converted
            for file in convertedURLs {
                let filePath = convertedDirectory + file
                try fileManager.removeItem(atPath: filePath)
                NSLog("[Hoshu] Deleted converted: \(file)")
            }

            // Clear rootless-patcher temp directory
            let rootlessPatcherPath = "/tmp/rootless-patcher"
            if fileManager.fileExists(atPath: rootlessPatcherPath) {
                let rootlessPatcherURLs = try fileManager.contentsOfDirectory(
                    atPath: rootlessPatcherPath
                )

                // Delete each item in rootless-patcher directory
                for file in rootlessPatcherURLs {
                    let filePath = rootlessPatcherPath + "/" + file
                    try fileManager.removeItem(atPath: filePath)
                    NSLog("[Hoshu] Deleted rootless-patcher: \(file)")
                }

                NSLog("[Hoshu] Cleaned rootless-patcher directory")
            }

            // Reset selected file path if it was in any of the cache directories
            if let selectedPath = selectedFilePath,
                selectedPath.hasPrefix(tempDirectory)
                    || selectedPath.hasPrefix(stagingDirectory)
                    || selectedPath.hasPrefix(importingDirectory)
                    || selectedPath.hasPrefix(convertedDirectory)
            {
                selectedFilePath = nil
                conversionCompleted = false
            }

            // Reset all states
            resetAllState()

        } catch {
            NSLog("[Hoshu] Error clearing cache: \(error.localizedDescription)")
        }
    }

    // This function resets both app state and local view state
    private func resetAllState() {
        // Reset AppState
        appState.resetState()

        // Reset local ContentView state
        selectedFilePath = nil
        conversionCompleted = false
        controlData = nil
    }

    // Initialize and make sure temp directory exists
    init() {
        ensureTempDirectoryExists()
    }

    // Helper method to handle opened files
    private func handleOpenedFile(fileURL: URL) {
        selectedFilePath = fileURL.path
        extractDebFile(filePath: fileURL.path)
    }

    // Extract .deb file to staging directory using AuxiliaryExecute to run dpkg-deb commands
    private func extractDebFile(filePath: String) {
        guard FileManager.default.fileExists(atPath: filePath) else {
            NSLog("[Hoshu] File does not exist at path: \(filePath)")
            DispatchQueue.main.async {
                self.appState.isParsingDeb = false
            }
            return
        }

        // Set parsing state to true
        DispatchQueue.main.async {
            self.appState.isParsingDeb = true
        }

        // Perform extraction in background to prevent UI freezing
        DispatchQueue.global(qos: .userInitiated).async {
            // Get filename without extension
            let fileURL = URL(fileURLWithPath: filePath)
            let filename = fileURL.deletingPathExtension().lastPathComponent

            // Create a directory in staging for this file
            let extractionDir = self.stagingDirectory + filename

            // Ensure directory exists
            let fileManager = FileManager.default
            do {
                // Create directory if it doesn't exist
                if fileManager.fileExists(atPath: extractionDir) {
                    try fileManager.removeItem(atPath: extractionDir)
                }

                try fileManager.createDirectory(
                    atPath: extractionDir,
                    withIntermediateDirectories: true
                )

                let environmentPath: [String] =
                    ProcessInfo
                    .processInfo
                    .environment["PATH"]?
                    .components(separatedBy: ":")
                    .compactMap {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    .map { path in
                        if path.hasPrefix("/var/jb/") {
                            return path
                        } else {
                            return "/var/jb/" + path
                        }
                    }
                    ?? []

                // Use AuxiliaryExecute to extract the data files (content)
                let dataResult = AuxiliaryExecute.spawn(
                    command: "/var/jb/usr/bin/dpkg-deb",
                    args: ["-R", filePath, extractionDir],
                    environment: [
                        "PATH": environmentPath.joined(separator: ":")
                    ]
                )

                NSLog(
                    "[Hoshu] Data extraction stderr: \(dataResult.stderr), exit code: \(dataResult.exitCode)"
                )

                NSLog(
                    "[Hoshu] Successfully extracted \(filename) to \(extractionDir)"
                )

                // Parse the control file - still in background thread
                self.parseControlFile(extractionDir: extractionDir)

            } catch {
                NSLog(
                    "[Hoshu] Error extracting .deb: \(error.localizedDescription)"
                )
                DispatchQueue.main.async {
                    self.appState.isParsingDeb = false
                }
                return
            }

            // Set parsing state back to false when complete
            DispatchQueue.main.async {
                self.appState.isParsingDeb = false
            }
        }
    }

    // Parse the control file from the extracted .deb
    private func parseControlFile(extractionDir: String) {
        let controlFilePath = extractionDir + "/DEBIAN/control"
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: controlFilePath) else {
            NSLog(
                "[Hoshu] Control file does not exist at path: \(controlFilePath)"
            )
            DispatchQueue.main.async {
                self.appState.isParsingDeb = false
            }
            return
        }

        do {
            // Read the control file
            let controlFileContents = try String(
                contentsOfFile: controlFilePath,
                encoding: .utf8
            )
            let lines = controlFileContents.components(separatedBy: .newlines)

            var fields: [String: String] = [:]
            var currentKey = ""
            var currentValue = ""

            // Parse each line
            for line in lines {
                if line.isEmpty { continue }

                // Check if this is a continuation of a multi-line value
                if line.first == " " || line.first == "\t" {
                    currentValue +=
                        "\n" + line.trimmingCharacters(in: .whitespaces)
                    fields[currentKey] = currentValue
                    continue
                }

                // If we have a key-value pair from previous iterations, save it
                if !currentKey.isEmpty && !currentValue.isEmpty {
                    fields[currentKey] = currentValue
                    currentKey = ""
                    currentValue = ""
                }

                // Split the line into key and value
                let components = line.split(
                    separator: ":",
                    maxSplits: 1,
                    omittingEmptySubsequences: false
                )
                if components.count == 2 {
                    currentKey = String(components[0]).trimmingCharacters(
                        in: .whitespaces
                    )
                    currentValue = String(components[1]).trimmingCharacters(
                        in: .whitespaces
                    )
                }
            }

            // Handle the last key-value pair
            if !currentKey.isEmpty && !currentValue.isEmpty {
                fields[currentKey] = currentValue
            }

            // Now build the Control struct from the fields dictionary
            // Provide sensible defaults for missing fields
            let id = UUID()
            let package = fields["Package"] ?? ""
            let name = fields["Name"] ?? package
            let version = fields["Version"] ?? ""
            let architecture = fields["Architecture"] ?? ""
            let packageDescription = fields["Description"] ?? ""
            let maintainer = fields["Maintainer"] ?? ""
            let author = fields["Author"] ?? maintainer
            let section = fields["Section"] ?? ""
            let depends =
                fields["Depends"]?.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces)
                } ?? []
            let conflicts =
                fields["Conflicts"]?.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces)
                } ?? []
            let icon = fields["Icon"] ?? ""
            let depiction = fields["Depiction"] ?? ""
            let homepage = fields["Homepage"].flatMap { URL(string: $0) }
            let installedSize = Int(fields["Installed-Size"] ?? "0") ?? 0

            // Check if the package is already rootless
            let filename = URL(fileURLWithPath: extractionDir).lastPathComponent
            let isRootlessFilename = filename.lowercased().contains("arm64")
            let isRootlessArchitecture = architecture.lowercased().contains(
                "arm64"
            )
            let isDetectedAsRootless =
                isRootlessFilename || isRootlessArchitecture

            let control = Control(
                id: id,
                package: package,
                name: name,
                version: version,
                architecture: architecture,
                packageDescription: packageDescription,
                maintainer: maintainer,
                author: author,
                section: section,
                depends: depends,
                conflicts: conflicts,
                icon: icon,
                depiction: depiction,
                homepage: homepage,
                installedSize: installedSize,
                isDetectedAsRootless: isDetectedAsRootless
            )

            if isDetectedAsRootless {
                DispatchQueue.main.async {
                    self.showRootlessAlert = true
                }
            }

            // Update the state with the parsed control data
            DispatchQueue.main.async {
                self.controlData = control
            }

        } catch {
            NSLog(
                "[Hoshu] Error reading control file: \(error.localizedDescription)"
            )
            DispatchQueue.main.async {
                self.appState.isParsingDeb = false
            }
        }
    }

    // Start the conversion process
    private func startConversion() {
        guard selectedFilePath != nil else { return }

        appState.isProcessing = true
        isTerminalViewPresented = true
    }

    var body: some View {
        let gradientStyle = FluidGradient(
            blobs: [.gray],
            highlights: [.black],
            speed: 0.25,
            blur: 0.75
        ).background(.black)

        gradientStyle
            .ignoresSafeArea()
            .overlay(
                ZStack {
                    // Top buttons
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                isSettingsPresented = true
                            }) {
                                Image(systemName: "gear")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 24))
                                    .padding()
                            }
                        }
                        Spacer()
                    }

                    // Center button in a fixed position
                    VStack {
                        Spacer()

                        // File name area with fixed height that opens package info when tapped
                        ZStack {
                            if let selectedPath = selectedFilePath {
                                HStack {
                                    // Left spacer to center the text
                                    Spacer()

                                    // Center: Filename + info icon
                                    Text(
                                        URL(fileURLWithPath: selectedPath)
                                            .lastPathComponent
                                            .cleanIOSFileSuffix()
                                    )
                                    .foregroundStyle(.white)

                                    Image(systemName: "info.circle")
                                        .foregroundStyle(.gray)
                                        .font(.system(size: 14))

                                    // Right spacer with equal weight
                                    Spacer()
                                }
                                .contentShape(Rectangle())  // Make entire area tappable
                                .onTapGesture {
                                    NSLog(
                                        "[Hoshu] File name tapped, controlData: \(controlData != nil), isParsingDeb: \(appState.isParsingDeb)"
                                    )
                                    showPackageInfoSheet = true
                                }
                            }
                        }
                        .frame(height: 30)  // Fixed height reserved for filename
                        .padding(.bottom, 10)

                        // Convert button
                        Button(action: {
                            if selectedFilePath == nil {
                                // Use the appropriate file picker based on the toggle setting
                                if appState.showAlternativeFilePicker {
                                    isAlternativeFilePickerPresented = true
                                } else {
                                    isFilePickerPresented = true
                                }
                            } else {
                                startConversion()
                            }
                        }) {
                            if appState.isProcessing {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(
                                            CircularProgressViewStyle(
                                                tint: .white
                                            )
                                        )
                                        .scaleEffect(0.8)
                                    Text("Converting...")
                                        .foregroundStyle(.white)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if appState.isParsingDeb {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(
                                            CircularProgressViewStyle(
                                                tint: .white
                                            )
                                        )
                                        .scaleEffect(0.8)
                                    Text("Parsing...")
                                        .foregroundStyle(.white)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if conversionCompleted {
                                Text("Conversion Complete!")
                                    .foregroundStyle(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(.ultraThinMaterial)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 8)
                                    )
                            } else {
                                Text(
                                    selectedFilePath == nil
                                        ? "Select .deb File"
                                        : "Convert .deb File"
                                )
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .fileImporter(
                            isPresented: $isFilePickerPresented,
                            allowedContentTypes: debUTType != nil
                                ? [debUTType!] : [],
                            allowsMultipleSelection: false
                        ) { result in
                            switch result {
                            case .success(let files):
                                guard let selectedFile = files.first else {
                                    return
                                }
                                ensureTempDirectoryExists()
                                let originalFileName = selectedFile
                                    .lastPathComponent
                                self.appState.isParsingDeb = true
                                do {
                                    let fileManager = FileManager.default
                                    let cleanedFileName =
                                        originalFileName.cleanIOSFileSuffix()
                                    let destinationPath =
                                        importingDirectory + cleanedFileName
                                    if fileManager.fileExists(
                                        atPath: destinationPath
                                    ) {
                                        try fileManager.removeItem(
                                            atPath: destinationPath
                                        )
                                    }
                                    try fileManager.copyItem(
                                        at: selectedFile,
                                        to: URL(
                                            fileURLWithPath: destinationPath
                                        )
                                    )
                                    selectedFilePath = destinationPath
                                    extractDebFile(filePath: destinationPath)
                                } catch {
                                    self.appState.isParsingDeb = false
                                    NSLog(
                                        "Error copying file: \(error.localizedDescription)"
                                    )
                                }
                            case .failure(let error):
                                NSLog(
                                    "Error selecting file: \(error.localizedDescription)"
                                )
                            }
                        }
                        .disabled(
                            (appState.isProcessing && selectedFilePath != nil)
                                || appState.isParsingDeb
                        )  // Disable during processing or parsing if a file is selected
                        .padding(.horizontal, 20)
                        // Import from URL section (only show when no file selected and not busy with conversion)
                        if selectedFilePath == nil && !appState.isProcessing {
                            VStack(spacing: 8) {
                                Button(action: {
                                    guard !isDownloading && !isPreflighting
                                    else { return }
                                    urlToImport = ""
                                    showURLImportPrompt = true
                                }) {
                                    let label: String = {
                                        if isPreflighting {
                                            return "Checking URL..."
                                        }
                                        if isDownloading {
                                            if isUnknownSize {
                                                var parts: [String] = [
                                                    "Downloading"
                                                ]
                                                if downloadedBytes > 0 {
                                                    parts.append(
                                                        formatBytes(
                                                            Double(
                                                                downloadedBytes
                                                            )
                                                        )
                                                    )
                                                }
                                                if downloadSpeedBytesPerSec > 0
                                                {
                                                    parts.append(
                                                        formatBytes(
                                                            downloadSpeedBytesPerSec
                                                        ) + "/s"
                                                    )
                                                }
                                                if retryAttempt > 0 {
                                                    parts.append(
                                                        "(retry \(retryAttempt)/\(maxDownloadRetries))"
                                                    )
                                                }
                                                return parts.joined(
                                                    separator: " • "
                                                )
                                            } else if downloadSpeedBytesPerSec
                                                > 0
                                                && downloadETASeconds > 0
                                            {
                                                let pct = String(
                                                    format: "%.0f%%",
                                                    downloadProgress * 100
                                                )
                                                let speed =
                                                    formatBytes(
                                                        downloadSpeedBytesPerSec
                                                    ) + "/s"
                                                let eta = formatETA(
                                                    downloadETASeconds
                                                )
                                                var parts = [
                                                    "Downloading", pct, speed,
                                                    eta,
                                                ]
                                                if retryAttempt > 0 {
                                                    parts.append(
                                                        "(retry \(retryAttempt)/\(maxDownloadRetries))"
                                                    )
                                                }
                                                return parts.joined(
                                                    separator: " • "
                                                )
                                            } else {
                                                let pct = String(
                                                    format: "%.0f%%",
                                                    downloadProgress * 100
                                                )
                                                var parts = [
                                                    "Downloading", pct,
                                                ]
                                                if retryAttempt > 0 {
                                                    parts.append(
                                                        "(retry \(retryAttempt)/\(maxDownloadRetries))"
                                                    )
                                                }
                                                return parts.joined(
                                                    separator: " • "
                                                )
                                            }
                                        }
                                        return "Import from URL"
                                    }()
                                    Text(label)
                                        .foregroundStyle(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(.ultraThinMaterial)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 8)
                                        )
                                }
                                .disabled(isPreflighting)

                                if isDownloading || isPreflighting {
                                    Button(role: .cancel) {
                                        cancelDownload()
                                    } label: {
                                        Text("Cancel Download")
                                            .foregroundStyle(.red)
                                            .padding(8)
                                            .frame(maxWidth: .infinity)
                                            .background(Color.red.opacity(0.15))
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: 8
                                                )
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        Spacer()
                    }
                }
                .padding()
            )
            .fullScreenCover(isPresented: $isTerminalViewPresented) {
                if let filePath = selectedFilePath {
                    TerminalView(
                        filePath: filePath,
                        isPresented: $isTerminalViewPresented
                    )
                }
            }
            .sheet(isPresented: $showPackageInfoSheet) {
                if let data = controlData {
                    PackageView(controlData: data)
                }
            }
            // Use alert with package manager options
            .alert("Success", isPresented: $appState.showShareSheet) {
                if isAppAvailable("org.coolstar.SileoStore") {
                    Button("Sileo") {
                        if let filePath = appState.convertedFilePath {
                            shareFileToApp(
                                "org.coolstar.SileoStore",
                                filePath
                            )
                        }
                        appState.showShareSheet = false
                        resetAllState()
                    }
                }

                if isAppAvailable("xyz.willy.Zebra") {
                    Button("Zebra") {
                        if let filePath = appState.convertedFilePath {
                            shareFileToApp(
                                "xyz.willy.Zebra",
                                filePath
                            )
                        }
                        appState.showShareSheet = false
                        resetAllState()
                    }
                }

                if isAppAvailable("com.tigisoftware.Filza") {
                    Button("Filza") {
                        if let filePath = appState.convertedFilePath {
                            shareFileToApp(
                                "com.tigisoftware.Filza",
                                filePath
                            )
                        }
                        appState.showShareSheet = false
                        resetAllState()
                    }
                }

                Button("Share") {
                    showSystemShareSheet = true
                    appState.showShareSheet = false
                    resetAllState()
                }

                Button("Cancel", role: .cancel) {
                    resetAllState()
                    appState.showShareSheet = false
                }
            } message: {
                Text("Choose where to share the converted package")
            }
            .sheet(
                isPresented: $showSystemShareSheet,
                onDismiss: {
                    // Reset app state after the system share sheet is dismissed
                    appState.resetState()
                }
            ) {
                if let filePath = appState.convertedFilePath {
                    ShareSheetView(filePath: filePath)
                }
            }
            .fullScreenCover(isPresented: $isAlternativeFilePickerPresented) {
                // Show our custom alternative file picker when requested
                AlternativeFilePicker(
                    isPresented: $isAlternativeFilePickerPresented
                ) { fileURL in
                    // Ensure temp directory exists
                    ensureTempDirectoryExists()

                    // Get the filename from the URL
                    let originalFileName = fileURL
                        .lastPathComponent

                    // Set parsing flag to true before starting the process
                    self.appState.isParsingDeb = true

                    // Copy the file to the importing directory
                    do {
                        // Remove existing file if it exists
                        let fileManager = FileManager.default

                        // Clean the filename from iOS 15 numeric suffixes
                        let cleanedFileName =
                            originalFileName.cleanIOSFileSuffix()
                        let destinationPath =
                            importingDirectory + cleanedFileName

                        if fileManager.fileExists(atPath: destinationPath) {
                            try fileManager.removeItem(atPath: destinationPath)
                        }

                        try fileManager.copyItem(
                            at: fileURL,
                            to: URL(fileURLWithPath: destinationPath)
                        )

                        // Update the selected file path to point to the copied file
                        selectedFilePath = destinationPath

                        // Automatically start parsing the file
                        extractDebFile(filePath: destinationPath)
                    } catch {
                        // Reset parsing flag if there's an error
                        self.appState.isParsingDeb = false
                        NSLog(
                            "Error copying file: \(error.localizedDescription)"
                        )
                    }
                }
            }
            .fullScreenCover(isPresented: $isSettingsPresented) {
                SettingsView(onClearCache: clearCache)
            }
            .onAppear {
                // Initialize the notification handler here
                if notificationHandler == nil {
                    notificationHandler = DebFileNotificationHandler {
                        fileURL in
                        self.handleOpenedFile(fileURL: fileURL)
                    }
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("hoshuclearSelectedFile")
                )
            ) { _ in
                selectedFilePath = nil
                conversionCompleted = false
                controlData = nil
            }
            .alert("Rootless Package Detected", isPresented: $showRootlessAlert)
        {
            Button("Proceed Anyway") {
                // Allow the user to proceed with the rootless package
                showRootlessAlert = false
            }
            Button("Cancel", role: .cancel) {
                // Clear the state and reset as before
                resetAllState()
                showRootlessAlert = false
            }
        } message: {
            Text(
                "This package was detected to be already rootless (arm64). You can still proceed if you'd like to convert it again."
            )
        }
            // URL entry prompt
            .alert("Import .deb from URL", isPresented: $showURLImportPrompt) {
                TextField(
                    "URL",
                    text: $urlToImport
                )
                .autocapitalization(.none)
                .disableAutocorrection(true)
                Button("Cancel", role: .cancel) {}
                Button("Download") { startURLPreflight() }
                    .disabled(!isPotentiallyValidURL(urlToImport))
            } message: {
                Text("Enter a URL. We'll verify and download the .deb.")
            }
            // Download error alert
            .alert(item: $downloadErrorAlert) { alert in
                Alert(
                    title: Text("Download Failed"),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
}

// View extension for placeholder text with custom color
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// ScrollContentBackgroundModifier to handle iOS version compatibility
// Removed unused ScrollContentBackgroundModifier

// MARK: - URL Import Helpers
extension ContentView {
    private func isPotentiallyValidURL(_ text: String) -> Bool {
        guard
            let url = URL(
                string: text.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        else {
            return false
        }
        return url.scheme == "http" || url.scheme == "https"
    }

    private func formatBytes(_ bytesPerSec: Double) -> String {
        if bytesPerSec <= 0 { return "0 B" }
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = bytesPerSec
        var idx = 0
        while value > 1024 && idx < units.count - 1 {
            value /= 1024
            idx += 1
        }
        return String(
            format: idx == 0 ? "%.0f %@" : "%.1f %@",
            value,
            units[idx]
        )
    }

    private func formatETA(_ seconds: Double) -> String {
        if seconds.isNaN || seconds.isInfinite || seconds <= 0 {
            return "ETA --"
        }
        if seconds < 60 { return String(format: "ETA %.0fs", seconds) }
        let mins = Int(seconds / 60)
        let secs = Int(seconds) % 60
        if mins < 60 { return String(format: "ETA %dm %02ds", mins, secs) }
        let hours = mins / 60
        let remMins = mins % 60
        return String(format: "ETA %dh %dm", hours, remMins)
    }

    private func startURLPreflight() {
        let raw = urlToImport.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isPotentiallyValidURL(raw), let url = URL(string: raw) else {
            return
        }
        showURLImportPrompt = false
        isPreflighting = true
        downloadProgress = 0
        downloadErrorAlert = nil
        downloadedBytes = 0
        downloadSpeedBytesPerSec = 0
        downloadETASeconds = 0
        isUnknownSize = false
        retryAttempt = 0
        cancelRequested = false
        ensureTempDirectoryExists()

        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"

        let headTask = URLSession.shared.dataTask(with: headRequest) {
            _,
            response,
            error in
            if cancelRequested { return }
            if error != nil {
                DispatchQueue.main.async {
                    if !cancelRequested {
                        isPreflighting = false
                        startDownloadWithRetry(
                            url: url,
                            resolvedFilename: url.lastPathComponent
                        )
                    }
                }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    if !cancelRequested {
                        isPreflighting = false
                        startDownloadWithRetry(
                            url: url,
                            resolvedFilename: url.lastPathComponent
                        )
                    }
                }
                return
            }
            if http.statusCode == 405 {
                DispatchQueue.main.async {
                    if !cancelRequested {
                        isPreflighting = false
                        startDownloadWithRetry(
                            url: url,
                            resolvedFilename: url.lastPathComponent
                        )
                    }
                }
                return
            }
            guard (200..<400).contains(http.statusCode) else {
                DispatchQueue.main.async {
                    if !cancelRequested {
                        isPreflighting = false
                        handleDownloadError("HEAD status \(http.statusCode)")
                    }
                }
                return
            }
            let contentDisp = http.value(
                forHTTPHeaderField: "Content-Disposition"
            )
            let resolvedName = resolveFilename(
                originalURL: url,
                contentDisposition: contentDisp
            )
            DispatchQueue.main.async {
                if !cancelRequested {
                    isPreflighting = false
                    startDownloadWithRetry(
                        url: url,
                        resolvedFilename: resolvedName
                    )
                }
            }
        }
        headTask.resume()
    }

    private func startDownloadWithRetry(url: URL, resolvedFilename: String) {
        retryAttempt = 0
        attemptDownload(
            url: url,
            resolvedFilename: resolvedFilename,
            attempt: 1
        )
    }

    private func attemptDownload(
        url: URL,
        resolvedFilename: String,
        attempt: Int
    ) {
        if cancelRequested { return }
        retryAttempt = attempt - 1
        beginDownload(
            url: url,
            resolvedFilename: resolvedFilename,
            attempt: attempt
        )
    }

    private func beginDownload(url: URL, resolvedFilename: String, attempt: Int)
    {
        isDownloading = true
        appState.isParsingDeb = true
        let downloader = DebURLDownloader(
            progressHandler: { progress, bytesWritten, totalBytes, startedAt in
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                    self.downloadedBytes = bytesWritten
                    if totalBytes > 0 {
                        let elapsed = Date().timeIntervalSince(startedAt)
                        if elapsed > 0 {
                            self.downloadSpeedBytesPerSec =
                                Double(bytesWritten) / elapsed
                            let remainingBytes = Double(
                                totalBytes - bytesWritten
                            )
                            if self.downloadSpeedBytesPerSec > 0 {
                                self.downloadETASeconds =
                                    remainingBytes
                                    / self.downloadSpeedBytesPerSec
                            }
                        }
                        self.isUnknownSize = false
                    } else {
                        self.isUnknownSize = true
                    }
                }
            },
            completion: { tempURL, error in
                if let error = error {
                    DispatchQueue.main.async {
                        if cancelRequested { return }
                        if isTransientError(error)
                            && attempt < maxDownloadRetries
                        {
                            let delay = pow(2.0, Double(attempt - 1))
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + delay
                            ) {
                                attemptDownload(
                                    url: url,
                                    resolvedFilename: resolvedFilename,
                                    attempt: attempt + 1
                                )
                            }
                        } else {
                            handleDownloadError(error.localizedDescription)
                        }
                    }
                    return
                }
                guard let tempURL else {
                    DispatchQueue.main.async { handleDownloadError("No data") }
                    return
                }
                finalizeDownload(tempURL: tempURL, filename: resolvedFilename)
            }
        )
        activeDownloader = downloader
        downloader.start(url: url)
    }

    private func finalizeDownload(tempURL: URL, filename: String) {
        let fileManager = FileManager.default
        let cleanedName = filename.cleanIOSFileSuffix()
        let destinationPath = importingDirectory + cleanedName
        do {
            if fileManager.fileExists(atPath: destinationPath) {
                try fileManager.removeItem(atPath: destinationPath)
            }
            try fileManager.copyItem(
                at: tempURL,
                to: URL(fileURLWithPath: destinationPath)
            )
            selectedFilePath = destinationPath
            isDownloading = false
            appState.isParsingDeb = true  // keep parsing flag until extraction done
            extractDebFile(filePath: destinationPath)
        } catch {
            handleDownloadError(error.localizedDescription)
        }
    }

    private func handleDownloadError(_ message: String) {
        downloadErrorAlert = DownloadErrorAlert(message: message)
        isDownloading = false
        isPreflighting = false
        appState.isParsingDeb = false
        downloadProgress = 0
        downloadSpeedBytesPerSec = 0
        downloadETASeconds = 0
        downloadedBytes = 0
        isUnknownSize = false
    }

    private func resolveFilename(originalURL: URL, contentDisposition: String?)
        -> String
    {
        if let cd = contentDisposition {
            // Look for filename="..."
            if let range = cd.range(of: "filename=") {
                let after = cd[range.upperBound...]
                let trimmed = after.trimmingCharacters(
                    in: CharacterSet(charactersIn: "\"' ;")
                )
                let components =
                    trimmed.components(separatedBy: ";").first ?? trimmed
                if !components.isEmpty { return components }
            }
        }
        return originalURL.lastPathComponent
    }
}

// Downloader with progress via delegate
private class DebURLDownloader: NSObject, URLSessionDownloadDelegate {
    private var progressHandler: (Double, Int64, Int64, Date) -> Void
    private var completion: (URL?, Error?) -> Void
    private var session: URLSession!
    private var startTime = Date()

    init(
        progressHandler: @escaping (Double, Int64, Int64, Date) -> Void,
        completion: @escaping (URL?, Error?) -> Void
    ) {
        self.progressHandler = progressHandler
        self.completion = completion
        super.init()
        let config = URLSessionConfiguration.ephemeral
        session = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
    }

    func start(url: URL) {
        let task = session.downloadTask(with: url)
        task.resume()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesExpectedToWrite > 0 {
            let progress =
                Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            progressHandler(
                progress,
                totalBytesWritten,
                totalBytesExpectedToWrite,
                startTime
            )
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        completion(location, nil)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error { completion(nil, error) }
    }
}

extension DebURLDownloader {
    func cancel() {
        session.invalidateAndCancel()
    }
}

// MARK: - Cancellation & Transient Error Helpers
extension ContentView {
    private func cancelDownload() {
        cancelRequested = true
        activeDownloader?.cancel()
        activeDownloader = nil
        isDownloading = false
        isPreflighting = false
        appState.isParsingDeb = false
        downloadProgress = 0
        downloadSpeedBytesPerSec = 0
        downloadETASeconds = 0
        downloadedBytes = 0
        isUnknownSize = false
    }

    fileprivate func isTransientError(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return false }
        let transientCodes: Set<Int> = [
            NSURLErrorTimedOut,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorDNSLookupFailed,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorResourceUnavailable,
            NSURLErrorInternationalRoamingOff,
            NSURLErrorCallIsActive,
            NSURLErrorDataNotAllowed,
            NSURLErrorSecureConnectionFailed,
            NSURLErrorCannotLoadFromNetwork,
        ]
        return transientCodes.contains(ns.code)
    }
}
