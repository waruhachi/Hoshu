//
//  CreditsView.swift
//  Hoshu
//
//  Created by Анохин Юрий on 23.04.2023.
//

import FluidGradient
import SwiftUI

struct CreditsView: View {
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.backButtonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]

        // Set the back button image color
        let backButtonImage = UIImage(systemName: "chevron.left")?
            .withTintColor(
                .white, renderingMode: .alwaysOriginal)
        appearance.setBackIndicatorImage(
            backButtonImage, transitionMaskImage: backButtonImage)

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
    }

    var body: some View {
        ZStack(alignment: .center) {
            FluidGradient(
                blobs: [.black, .white],
                highlights: [.black, .white],
                speed: 0.5,
                blur: 0.80
            )
            .background(.black)
            .ignoresSafeArea()

            ScrollView {
                VStack {
                    creditView(
                        imageURL: URL(
                            string:
                                "https://avatars.githubusercontent.com/u/156133757"
                        ), name: "waruhachi", description: "Made Hoshu")
                    creditView(
                        imageURL: URL(
                            string:
                                "https://avatars.githubusercontent.com/u/81449663"
                        ), name: "NightwindDev",
                        description: "Made rootless-patcher")
                    creditView(
                        imageURL: URL(
                            string:
                                "https://avatars.githubusercontent.com/u/134120506"
                        ), name: "roothide",
                        description: "Made RoothidePatcher")
                    creditView(
                        imageURL: URL(
                            string:
                                "https://avatars.githubusercontent.com/u/85764897"
                        ), name: "haxi0", description: "Made Derootifier")
                }
                .padding()
            }
            .padding()
            .listStyle(.insetGrouped)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func creditView(imageURL: URL?, name: String, description: String)
        -> some View
    {
        HStack {
            AsyncImage(
                url: imageURL,
                content: { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 35, maxHeight: 35)
                        .cornerRadius(20)
                },
                placeholder: {
                    ProgressView()
                        .frame(maxWidth: 35, maxHeight: 35)
                })

            VStack(alignment: .leading) {
                Button(name) {
                    if let url = URL(string: "https://github.com/\(name)") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundColor(.white)
    }
}

struct CreditsView_Previews: PreviewProvider {
    static var previews: some View {
        CreditsView()
    }
}
