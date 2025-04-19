//
//  ShellScript.swift
//  Hoshu
//
//  Created by Анохин Юрий on 15.04.2023.
//

import Foundation
import UIKit

func rootlessPatcher(debURL: URL) -> (Int, String) {
    let environmentPath =
        ProcessInfo
        .processInfo
        .environment["PATH"]?
        .components(separatedBy: ":")
        .compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        ?? []

    var output = ""
    let command = "/var/jb/usr/local/bin/rootless-patcher"
    let env: [String: String] = ["PATH": environmentPath.joined(separator: ":")]
    let args = [debURL.path]

    let receipt = AuxiliaryExecute.spawn(
        command: command,
        args: args,
        environment: env,
        output: { outputLine in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("terminalOutputUpdate"),
                    object: outputLine
                )
            }

            output += outputLine
        }
    )

    return (receipt.exitCode, output)
}

func folderCheck() {
    do {
        if !FileManager.default.fileExists(
            atPath: "/tmp/moe.waru.hoshu")
        {
            try FileManager.default.createDirectory(
                atPath: "/tmp/moe.waru.hoshu",
                withIntermediateDirectories: true)
        }
    } catch {
        UIApplication.shared.alert(
            title: "Error!",
            body: "There was a problem with making the folder for the deb.",
            withButton: false)
    }
}
