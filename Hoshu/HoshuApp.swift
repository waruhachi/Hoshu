//
//  HoshuApp.swift
//  Hoshu
//
//  Created by Анохин Юрий on 15.04.2023.
//

import SwiftUI

@main
struct HoshuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { (url) in
                    let fileManager = FileManager.default

                    guard fileManager.fileExists(atPath: url.path) else { return }

                    let destFolderURL = URL(fileURLWithPath: "/tmp/moe.waru.hoshu")

                    do {
                        try fileManager.createDirectory(
                            at: destFolderURL, withIntermediateDirectories: true, attributes: nil)
                    } catch {
                        print(error.localizedDescription)
                        return
                    }

                    let destFileURL = destFolderURL.appendingPathComponent(url.lastPathComponent)

                    do {
                        if fileManager.fileExists(atPath: destFileURL.path) {
                            try fileManager.removeItem(at: destFileURL)
                        }

                        try fileManager.copyItem(at: url, to: destFileURL)

                        NotificationCenter.default.post(
                            name: Notification.Name("hoshuFileOpen"), object: destFileURL)

                    } catch {
                        print(error.localizedDescription)
                    }

                }
        }
    }
}
