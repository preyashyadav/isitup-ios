# isitup
`isitup` is a SwiftUI iOS app that monitors your HTTP endpoints and shows their current health status in real time.

## What It Does

- Monitors multiple configured services from one dashboard
- Runs endpoint checks and shows state: `Healthy`, `Degrading`, `Down`, `Error`
- Persists per-service history (status + latency samples)
- Sends smart local notifications (individual + grouped)
- Supports Siri/Shortcuts service checks
- Generates an on-device Daily Digest when Apple Intelligence is available
## Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/bf462081-0f9a-4948-b1c7-3629a54da2d5" width="180" />
  <img src="https://github.com/user-attachments/assets/84418595-4550-415a-9a3a-ce29d483cb9f" width="180" />
  <img src="https://github.com/user-attachments/assets/5763a8af-396c-4a9f-a755-f440b6f7a1c2" width="180" />
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/17dea20b-6766-4035-b3e4-cd501c3c83c0" width="180" />
  <img src="https://github.com/user-attachments/assets/8e90627d-163f-4142-86e5-fd824f826c90" width="180" />
  <img src="https://github.com/user-attachments/assets/7c951422-5c19-4ccf-b3e7-9ddeb719bc6a" width="180" />
</p>



## Baseline Technical Overview

- **Architecture:** SwiftUI + `HealthViewModel` (`@MainActor`) as the app orchestration layer
- **Networking:** `URLSession` with `HEAD` request and `GET` fallback (5s timeout)
- **Persistence:**
  - Service config in `UserDefaults`
  - Sample history in JSON file (Documents directory)
  - PIN in Keychain (`Security` framework)
- **Detection:** Statistical anomaly detection on response-time history to classify `Degrading`
- **Notifications:** `UserNotifications` with cooldown tracking and grouped outage alerts
- **Siri/Shortcuts:** `AppIntents` for “check all services” and “check single service”
- **On-device AI:** `FoundationModels` daily summary generation (iOS 26+ supported devices)

## Setup

1. Open `isitup.xcodeproj` in Xcode.
2. Select the `isitup` scheme.
3. Run on an iOS Simulator or a physical iPhone.
4. On first launch, allow notifications if you want outage/degrading alerts.
5. (Optional) Add Siri shortcuts from the app for voice checks.

## Notes

- Daily Digest appears only on devices where Apple Intelligence is available.
- Service status depends on real endpoint reachability from the running device/simulator.
