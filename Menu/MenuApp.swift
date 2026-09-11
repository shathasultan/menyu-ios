//
//  MenuApp.swift
//  Menu
//
//  Created by shatha alsawilam on 27/03/1448 AH.
//

import SwiftUI

@main
struct MenuApp: App {
    init() {
        MFontRegistrar.registerBundledFonts()
        configureTabBarAppearance()
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
        }
    }
}
