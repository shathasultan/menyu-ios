//
//  MenuApp.swift
//  Menu
//
//  Created by shatha alsawilam on 27/03/1448 AH.
//

import SwiftUI
import GoogleSignIn

@main
struct MenuApp: App {
    init() {
        MFontRegistrar.registerBundledFonts()
        configureTabBarAppearance()
        // No static semanticContentAttribute default here on purpose: a
        // fixed `UIView.appearance()` value never updates again after
        // launch, so it would permanently pin every newly-created UIKit
        // view to whatever direction was set here — even after the user
        // switches the in-app language. ContentView owns this dynamically
        // instead; see `applyWindowDirection()`.
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.mSurface)
        appearance.shadowColor = UIColor(Color.mLine)

        let normal = appearance.stackedLayoutAppearance.normal
        normal.iconColor = UIColor(Color.mInkFaint)
        normal.titleTextAttributes = [.foregroundColor: UIColor(Color.mInkFaint)]

        let selected = appearance.stackedLayoutAppearance.selected
        selected.iconColor = UIColor(Color.mAccent)
        selected.titleTextAttributes = [.foregroundColor: UIColor(Color.mAccent)]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
