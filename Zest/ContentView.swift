//
//  ContentView.swift
//  Zest
//
//  Created by Fabio Antonucci on 05/04/26.
//

import SwiftUI

struct ContentView: View {
    // 1. PERSISTENT STORAGE
    // This lives in the phone's memory. It starts as 'false'.
    // Once the user clicks "Get Started", it becomes 'true' forever.
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
    
    // 2. STATE MANAGEMENT
    // Initializing your workout logic here so it's ready behind the scenes.
    @StateObject private var workoutManager = WorkoutManager()

    var body: some View {
        ZStack {
            // LAYER 1: THE MAIN APP (The Bottom Layer)
            // This is always here, even when hidden by the welcome screen.
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
            
            // LAYER 2: THE WELCOME OVERLAY (The Top Layer)
            // We use an 'if' statement to conditionally render this view.
            if !hasSeenWelcome {
                WelcomePageView(isPresented: $hasSeenWelcome)
                    .transition(.opacity) // Smooth fade-out when dismissed
                    .zIndex(1)            // Ensures this stays on top during the fade
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
