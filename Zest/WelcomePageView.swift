//
//  WelcomePageView.swift
//  Zest
//
//  Created by Souha Aouididi on 08/04/26.
//

import SwiftUI

struct WelcomePageView: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // Background base
            
            VStack(spacing: 0) {
                Spacer()
                
        
                VStack(spacing: -5) {
                    Text("Welcome to").font(.system(size: 40, weight: .light))
                    Text("Zest !").font(.system(size: 60, weight: .bold))
                }
                .foregroundColor(.zestGreen)
                .shadow(color: .zestGreen.opacity(0.7), radius: 5)
                .padding(.top, 40)
                
                
                ZestWaveBackground()
                    .frame(height: 250) // Adjust height as needed
                    .padding(.vertical, 20)
             
                VStack(spacing: 5) {
                    Text("Your movement, composed.")
                    Text("Turn every stride into music")
                    Text("and every metric into a melody")
                }
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.zestGreen)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Start Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.8)) { isPresented = true }
                }) {
                    Text("Let’s get started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 20).padding(.horizontal, 40)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 60)
            }
        }
    }
}

struct ZestWaveBackground: View {
    var body: some View {
        ZStack {
            // Dot Grid Background for the wave area
            Canvas { context, size in
                for x in stride(from: 0, to: size.width, by: 20) {
                    for y in stride(from: 0, to: size.height, by: 20) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(0.1)))
                    }
                }
            }
            
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                WaveformShape(phase: now)
                    .fill(Color(red: 0.8, green: 0.95, blue: 1.0))
                    .shadow(color: Color.blue.opacity(0.4), radius: 12)
                    .padding(.horizontal, 10)
            }
        }
    }
}

struct WaveformShape: Shape {
    var phase: Double
    
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let barCount = 45
        let width = rect.width / CGFloat(barCount)
        
        for i in 0..<barCount {
            let x = CGFloat(i) * width + (width / 2)
            let normalize = CGFloat(i) / CGFloat(barCount)
            
            // Motion logic
            let variation = sin(phase * 1.5 + normalize * .pi * 4) * 0.1
            let peak1 = exp(-pow(normalize - 0.2, 2) / 0.01) * (0.4 + variation)
            let peak2 = exp(-pow(normalize - 0.5, 2) / 0.03) * (0.7 + variation)
            let peak3 = exp(-pow(normalize - 0.8, 2) / 0.01) * (0.3 + variation)
            
            let magnitude = max(0.05, max(peak1, peak2, peak3))
            let height = rect.height * magnitude
            
            let barRect = CGRect(x: x - (width * 0.15),
                                y: (rect.height - height) / 2,
                                width: width * 0.3,
                                height: height)
            path.addRoundedRect(in: barRect, cornerSize: CGSize(width: 2, height: 2))
        }
        return path
    }
}
