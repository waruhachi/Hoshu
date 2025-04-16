//
//  ShellScript.swift
//  Hoshu
//
//  Created by Анохин Юрий on 15.04.2023.
//

import Foundation
import UIKit

func repackDeb(debURL: URL) -> (Int, String) {
    var output = ""
    let command = jbroot("/usr/local/bin/rootless-patcher")
    let env: [String: String] = [
        "PATH":
            "/usr/local/sbin:/var/jb/usr/local/sbin:/usr/local/bin:/var/jb/usr/local/bin:/usr/sbin:/var/jb/usr/sbin:/usr/bin:/var/jb/usr/bin:/sbin:/var/jb/sbin:/bin:/var/jb/bin:/usr/bin/X11:/var/jb/usr/bin/X11:/usr/games:/var/jb/usr/games:/var/jb/var/mobile/.local/bin"

    ]
    let args = [debURL.path]

    let receipt = AuxiliaryExecute.spawn(
        command: command,
        args: args,
        environment: env,
        output: { output += $0 }
    )

    // If the conversion was successful, set permissions and ownership on the output file
    if receipt.exitCode == 0 {
        let name = debURL.deletingPathExtension()
            .lastPathComponent.replacingOccurrences(
                of: "iphoneos-arm", with: "iphoneos-arm64"
            )

        let outputPath = jbroot("/var/mobile/Hoshu/\(name).deb")

        // Set file permissions to 0755
        _ = AuxiliaryExecute.spawn(
            command: jbroot("/usr/bin/chmod"),
            args: ["0755", outputPath],
            environment: env,
            output: { output += $0 }
        )

        // Set file ownership to 501:501
        _ = AuxiliaryExecute.spawn(
            command: jbroot("/usr/bin/chown"),
            args: ["501:501", outputPath],
            environment: env,
            output: { output += $0 }
        )
    }

    return (receipt.exitCode, output)
}

func folderCheck() {
    do {
        if FileManager.default.fileExists(
            atPath: jbroot("/var/mobile/Hoshu"))
        {
            print("We're good! :)")
        } else {
            try FileManager.default.createDirectory(
                atPath: jbroot("/var/mobile/Hoshu"),
                withIntermediateDirectories: true)
        }
    } catch {
        UIApplication.shared.alert(
            title: "Error!",
            body: "There was a problem with making the folder for the deb.",
            withButton: false)
    }
}

func checkFileManagers(path: String) {
    let activity = UIActivityViewController(
        activityItems: [URL(fileURLWithPath: path)],
        applicationActivities: nil)

    let window = UIApplication.shared.connectedScenes
        .first(where: { $0 is UIWindowScene })
        .flatMap({ $0 as? UIWindowScene })?.windows.first

    // don't touch this for ipad
    activity.popoverPresentationController?.sourceView = window
    activity.popoverPresentationController?.sourceRect = CGRect(
        x: window?.bounds.midX ?? 0, y: window?.bounds.height ?? 0, width: 0,
        height: 0)
    activity.popoverPresentationController?.permittedArrowDirections =
        UIPopoverArrowDirection.down

    UIApplication.shared.present(alert: activity)
}
