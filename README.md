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

<!-- Add screenshots below -->

![Monitor Screen](./docs/screenshots/monitor.png)
![Service Detail](./docs/screenshots/service-detail.png)
![Settings](./docs/screenshots/settings.png)
![Daily Digest](./docs/screenshots/digest.png)

## Run

1. Open `isitup.xcodeproj` in Xcode.
2. Select the `isitup` scheme.
3. Run on an iOS Simulator or device.

