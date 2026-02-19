# isitup

`isitup` is a SwiftUI iOS app that monitors your HTTP endpoints and shows their current health status in real time.

## What It Does

- Tracks multiple services from a configurable list
- Runs health checks and shows status (`Healthy`, `Degrading`, `Down`, `Error`)
- Stores check history and latency samples
- Sends local notifications for failures and degrading performance
- Supports Siri/Shortcuts intents for quick status checks
- Generates an on-device daily digest (when Apple Intelligence is available)

## Tech Stack

- Swift + SwiftUI
- App Intents (Siri/Shortcuts)
- UserNotifications
- Keychain (PIN security)
- FoundationModels (Apple Intelligence digest, iOS 26+)

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





## Run

1. Open `isitup.xcodeproj` in Xcode.
2. Select the `isitup` scheme.
3. Run on an iOS Simulator or device.

