//
//  ContentView.swift
//  Zest
//
//  Created by Fabio Antonucci on 05/04/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            CurrentWorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "figure.run")
                }

            SessionsView()
                .tabItem {
                    Label("Sessions", systemImage: "list.bullet.clipboard")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .environmentObject(workoutManager)
        .tint(.zestGreen)
    }
}

#Preview {
    ContentView()
}
