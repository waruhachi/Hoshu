import AuxiliaryExecute
import Foundation

final class DebConversionExecutor {
    private var isRunning = false
    private var didComplete = false
    private var outputHandler: (String) -> Void
    private var completionHandler: (Bool) -> Void
    private var convertedFilePath: String?
    private var onConvertedFileFound: ((String) -> Void)?
    private let convertedDirectory = "/tmp/moe.waru.hoshu/.converted/"
    private var conversionSucceeded = false
    var conversionSucceededValue: Bool { conversionSucceeded }

    init(
        outputHandler: @escaping (String) -> Void = { _ in },
        completionHandler: @escaping (Bool) -> Void,
        onConvertedFileFound: ((String) -> Void)? = nil
    ) {
        self.outputHandler = outputHandler
        self.completionHandler = completionHandler
        self.onConvertedFileFound = onConvertedFileFound
    }

    func start(withFilePath filePath: String) {
        if isRunning {
            return
        }

        isRunning = true
        didComplete = false

        outputHandler("[+] Loading file from \(filePath)...\n")

        let environmentPath: [String] =
            ProcessInfo.processInfo.environment["PATH"]?
            .components(separatedBy: ":")
            .compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { path in
                if path.hasPrefix("/var/jb/") {
                    return path
                } else {
                    return "/var/jb/" + path
                }
            } ?? []

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            AuxiliaryExecute.spawn(
                command: "/var/jb/usr/local/bin/rootless-patcher",
                args: [filePath],
                environment: ["PATH": environmentPath.joined(separator: ":")],
                timeout: 0,
                stdoutBlock: { [weak self] stdout in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.outputHandler(stdout)
                        self.captureConvertedPath(from: stdout)
                    }
                },
                stderrBlock: { [weak self] stderr in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.outputHandler("[+] Error: \(stderr)")
                    }
                }
            ) { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.outputHandler(
                        "\n[+] Job completed. You may close this window.\n"
                    )
                    if !self.conversionSucceeded {
                        self.outputHandler(
                            "\n[+] No converted file was produced. The conversion may have failed.\n"
                        )
                    }

                    self.isRunning = false
                    self.finish(success: self.conversionSucceeded)
                }
            }
        }
    }

    private func captureConvertedPath(from output: String) {
        guard output.contains("Done! New .deb path: ") else { return }

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            guard line.contains("Done! New .deb path: ") else { continue }
            guard let range = line.range(of: "Done! New .deb path: ") else {
                continue
            }

            let convertedPath = String(line[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: convertedDirectory) {
                do {
                    try fileManager.createDirectory(
                        atPath: convertedDirectory,
                        withIntermediateDirectories: true
                    )
                } catch {
                    continue
                }
            }

            let convertedFilename = URL(fileURLWithPath: convertedPath)
                .lastPathComponent
            let newPath = convertedDirectory + convertedFilename

            do {
                if fileManager.fileExists(atPath: newPath) {
                    try fileManager.removeItem(atPath: newPath)
                }

                try fileManager.moveItem(atPath: convertedPath, toPath: newPath)
                convertedFilePath = newPath
                onConvertedFileFound?(newPath)
                conversionSucceeded = true
            } catch {
                convertedFilePath = convertedPath
                if let convertedFilePath {
                    onConvertedFileFound?(convertedFilePath)
                    conversionSucceeded = true
                }
            }
        }
    }

    func stop() {
        isRunning = false
        finish(success: false)
    }

    private func finish(success: Bool) {
        if didComplete { return }
        didComplete = true
        completionHandler(success)
    }
}
