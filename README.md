# Zest 🏃

> *Run it up.*

Zest is an iOS running companion that makes your music react to your body. The faster you run, the more the audio opens up. Stumble, stop suddenly, or break your stride — and the track distorts in real time.

Built with SwiftUI, AVAudioEngine, CoreMotion, and CoreLocation.

---

## The Idea

Most running apps treat music as a background afterthought. Zest treats it as the main event. Speed drives a low-pass filter that opens the frequency spectrum as you accelerate — at rest the track sounds muffled and closed, at full sprint it opens completely. When the accelerometer and gyroscope detect an anomaly in your gait pattern, a Shaperbox-style volume gate fires on the audio, creating a rhythmic stutter effect that snaps back off once your movement stabilises.

---

## Features

- **Adaptive audio filter** — low-pass cutoff interpolates from 400 Hz (still) to 20 kHz (full sprint) driven by live GPS speed
- **Scatter effect** — rapid volume gate triggered by gait anomalies (stumble, sudden stop, jolt), auto-recovers when normal rhythm resumes
- **Adaptive motion detection** — 60-second warm-up learns your personal gait pattern using accelerometer + gyroscope fusion; detection is relative to your baseline, not fixed thresholds
- **Energy ratio detection** — compares a 0.5s short window against a 5s long window; spike or drop in the ratio triggers scatter
- **Live GPS speedometer** — shows current speed, average speed, and distance; tap to toggle km/h ↔ m/s
- **Genre browser** — reads bundled tracks organised by genre folder
- **Custom import** — load any audio file from the Files app
- **Session history** — past runs saved via CoreData with track, genre, duration, date
- **Lock screen notification** — shows elapsed time and current track while running
- **WatchOS stub** — companion layout ready for a watchOS target

---

## Architecture

```
WorkoutManager  (EnvironmentObject)
├── AudioEngine        AVAudioEngine graph
│   ├── playerNode     AVAudioPlayerNode
│   ├── lowPassEQ      Speed-driven 400 Hz → 20 kHz
│   ├── reverbNode     Placeholder (dry)
│   └── delayNode      Placeholder (dry)
├── LocationManager    CLLocationManager → speed, averageSpeed, distance
└── MotionManager      CMDeviceMotion (acc + gyro) → isScatterTriggered
```

Data flow:

```
LocationManager.speed ──→ AudioEngine.updateSpeed()   (filter)
                     └──→ MotionManager.updateSpeed()  (decel detection)

MotionManager.isScatterTriggered ──→ AudioEngine.startScatter() / stopScatter()
                                └──→ WorkoutManager.scatterCount++
```

---

## Tech Stack

| Layer | Framework |
|---|---|
| UI | SwiftUI |
| Audio | AVAudioEngine |
| Motion | CoreMotion (CMDeviceMotion) |
| Location | CoreLocation |
| Persistence | CoreData (programmatic model) |
| Notifications | UserNotifications |
| Reactive glue | Combine |

---

## Project Structure

```
Zest/
├── ZestApp.swift
├── ContentView.swift
├── Extensions/
│   └── Color+Zest.swift
├── Managers/
│   ├── AudioEngine.swift
│   ├── LocationManager.swift
│   ├── MotionManager.swift
│   ├── NotificationManager.swift
│   └── WorkoutManager.swift
├── Persistence/
│   ├── PersistenceController.swift
│   └── WorkoutSession.swift
├── Views/
│   ├── HomeView.swift
│   ├── CurrentWorkoutView.swift
│   ├── SessionsView.swift
│   └── WatchStubView.swift        ← watchOS target (stub)
└── tracks/
    ├── blues/
    ├── electronic/
    ├── hip-hop/
    ├── jazz/
    ├── lofi/
    ├── pop/
    └── rock/
```

---

## Getting Started

### Requirements

- Xcode 15+
- iOS 17+ deployment target
- Physical device (CoreMotion and GPS do not work in Simulator)

### Setup

1. Clone the repo
2. Open `Zest.xcodeproj` in Xcode
3. Select your development team in **Signing & Capabilities**
4. Add your audio files inside the `tracks/` folder, organised by genre subfolder. The folder must be added to Xcode as a **blue folder reference** (Add Files → Create folder references)
5. Build and run on a physical device

### Info.plist keys required

| Key | Value |
|---|---|
| Privacy - Motion Usage Description | Used to detect gait anomalies and trigger audio effects |
| Privacy - Location When In Use Usage Description | Used to measure running speed in real time |
| Privacy - User Notifications Usage Description | Shows current track and elapsed time on the lock screen |
| Required background modes | `audio`, `location` |

---

## How Scatter Detection Works

On session start, Zest enters a **60-second warm-up** during which it learns your personal gait signature using the accelerometer and gyroscope. No scatter is triggered during this phase.

After warm-up, it continuously computes:

```
energyRatio = shortRMS (0.5s) / longRMS (5s)
```

| energyRatio | Meaning |
|---|---|
| ≈ 1.0 | Normal gait |
| > 2.2 | Spike — stumble or impact |
| < 0.25 | Drop — sudden stop |

When either threshold is crossed, scatter fires and the **long baseline freezes** so it cannot be corrupted by the anomaly. Scatter turns off automatically once an EMA-smoothed version of the ratio stabilises back inside the normal band for at least 1 second — meaning your new rhythm has been recognised.

GPS deceleration (≥ 1.5 m/s drop in 3 seconds) triggers scatter independently as a second detection path.

---


---

## License

MIT
