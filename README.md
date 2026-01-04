# isitup v1.0 (iOS)

**isitup** is a lightweight iOS app for monitoring the health of web services.  
It allows users to track service availability, visualize system state, and receive local notifications when a service goes down.

Built using **SwiftUI**, **async/await**, **Charts**, and native iOS system APIs.

---

## Features

- Monitor multiple web services (HTTP/HTTPS)
- Health states: **Healthy, Down, Error, Checking**
- Dashboard with visual summary
- Local notifications on service failures
- PIN-based app security
- Background/foreground–aware locking

---

## Screenshots

### Home + Dashboard View
<p align="center">
  <img width="250" alt="image" src="https://github.com/user-attachments/assets/38d33891-5291-4537-8941-31d2669d5f3a"/>
  <img width="250" alt="image" src="https://github.com/user-attachments/assets/f3647752-77b7-4e3c-a55d-3113bcf4b658" />
  <img width="250" alt="image" src="https://github.com/user-attachments/assets/8311507d-1860-479b-8b7f-ddd1b4246c70" />
</p>

## PIN Lock + PIN Set Up View
<p align ="center">
    <img width="250" alt="Simulator Screenshot - iPhone 17 Pro - 2026-01-04 at 08 38 29" src="https://github.com/user-attachments/assets/ccd0f9ff-dffc-4813-b6fb-989d4fce6f6b" />
    <img width="250"  alt="image" src="https://github.com/user-attachments/assets/9fc1eeec-fb81-4368-a91b-0126101aa3ac" />
    <img width="250" alt="image" src="https://github.com/user-attachments/assets/bbc37d05-f979-411e-8db4-6fd451fba05e" />
</p>

## Edit + Notification View
<p align="center">
  <img width="250"  alt="image" src="https://github.com/user-attachments/assets/e553825c-8497-41e2-8865-5167a2ebab79" />
  <img width="250" alt="image" src="https://github.com/user-attachments/assets/2c8a50c6-fb7a-4fe4-abca-11db7a4874d2" />
  <img width="250" alt="image" src="https://github.com/user-attachments/assets/1dfcf511-4123-48dc-837d-587bb9c7cb87" />
</p>
---

## Architecture
- **SwiftUI** for UI
- **MVVM** structure
- **async/await** for network checks
- **UserNotifications** for alerts



---

## Setup

### Requirements
- macOS with Xcode 15+
- iOS 17+ (recommended)

### Run locally
1. Clone the repository
2. Open `isitup.xcodeproj` in Xcode
3. Select an iOS simulator or device
4. Press **Run**

---

## Notifications

The app can notify you when a monitored service transitions to a **Down** or **Error** state.
---

## Security

- Optional 4-digit PIN lock
- App locks automatically when backgrounded
- Local-only storage (no data leaves the device)

## License

This project is for educational and demonstration purposes.
