//
//  Alert++.swift
//  Hoshu
//
//  Created by Анохин Юрий on 15.04.2023.
//

import UIKit

var currentUIAlertController: UIAlertController?

extension UIApplication {
    func dismissAlert(animated: Bool, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            currentUIAlertController?.dismiss(
                animated: animated, completion: completion)
        }
    }

    func alert(
        title: String, body: String, animated: Bool = true,
        withButton: Bool = true
    ) {
        DispatchQueue.main.async {
            currentUIAlertController = UIAlertController(
                title: title, message: body, preferredStyle: .alert)
            if withButton {
                currentUIAlertController?.addAction(
                    .init(title: "OK", style: .cancel))
            }
            self.present(alert: currentUIAlertController!)
        }
    }

    func confirmAlert(
        title: String, body: String, onOK: @escaping () -> Void, noCancel: Bool
    ) {
        DispatchQueue.main.async {
            currentUIAlertController = UIAlertController(
                title: title, message: body, preferredStyle: .alert)
            if !noCancel {
                currentUIAlertController?.addAction(
                    .init(title: "Cancel", style: .cancel))
            }
            currentUIAlertController?.addAction(
                .init(
                    title: "OK", style: noCancel ? .cancel : .default,
                    handler: { _ in
                        onOK()
                    }))
            self.present(alert: currentUIAlertController!)
        }
    }

    func change(title: String, body: String) {
        DispatchQueue.main.async {
            currentUIAlertController?.title = title
            currentUIAlertController?.message = body
        }
    }

    func present(alert: UIViewController, animated: Bool = true) {
        if let windowScene = UIApplication.shared.connectedScenes.first(where: {
            $0 is UIWindowScene
        }) as? UIWindowScene,
            var topController = windowScene.windows.first?.rootViewController
        {
            while let presentedViewController = topController
                .presentedViewController
            {
                topController = presentedViewController
            }

            topController.present(alert, animated: animated)
        }
    }
}
