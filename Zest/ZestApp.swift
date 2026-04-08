//
//  ZestApp.swift
//  Zest
//
//  Created by Fabio Antonucci on 05/04/26.
//

import SwiftUI
internal import CoreData

@main
struct ZestApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        configureTabBarAppearance()
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.dark)
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.04, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
