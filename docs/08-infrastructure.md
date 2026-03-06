# IntonavioLocal — Build & Development Infrastructure

## Overview

IntonavioLocal is a fully on-device iOS/macOS app with no backend server. The build infrastructure consists of XcodeGen for project generation, Xcode for building and testing, and SwiftLint for code quality.

---

## Project Generation (XcodeGen)

The Xcode project is generated from `apps/ios/project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen). The `.xcodeproj` is not checked into source control — it is regenerated as needed.

### Generate Project

```bash
cd apps/ios
xcodegen generate
```

This produces `IntonavioLocal.xcodeproj` from the `project.yml` spec.

### When to Regenerate

- After adding or removing source files
- After modifying `project.yml` (targets, settings, entitlements)
- After pulling changes that modify project structure
- After resolving merge conflicts (regenerate rather than manually fixing `.xcodeproj`)

---

## Targets

Defined in `apps/ios/project.yml`:

| Target                | Type         | Platform | Bundle ID                       |
| --------------------- | ------------ | -------- | ------------------------------- |
| `IntonavioLocal`      | Application  | iOS      | `com.intonaviolocal.app`        |
| `IntonavioLocalMac`   | Application  | macOS    | `com.intonaviolocal.mac`        |
| `IntonavioLocalTests` | Unit Tests   | iOS      | `com.intonaviolocal.app.tests`  |

### Deployment Targets

| Platform | Minimum Version |
| -------- | --------------- |
| iOS      | 17.0            |
| macOS    | 14.0            |

### Build Settings

| Setting                    | Value                    |
| -------------------------- | ------------------------ |
| Swift version              | 5.9                      |
| Strict concurrency         | `complete`               |
| Code sign style            | Automatic                |
| Development team           | Set in `project.yml`     |

---

## Building

### iOS Simulator

```bash
xcodebuild -project apps/ios/IntonavioLocal.xcodeproj \
  -scheme IntonavioLocal \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Use `iPhone 17 Pro` as the simulator destination (iPhone 16 is not available).

### iOS Device

```bash
xcodebuild -project apps/ios/IntonavioLocal.xcodeproj \
  -scheme IntonavioLocal \
  -destination 'generic/platform=iOS' \
  build
```

Requires a valid provisioning profile and development team.

### macOS

```bash
xcodebuild -project apps/ios/IntonavioLocal.xcodeproj \
  -scheme IntonavioLocalMac \
  build
```

### Running Tests

```bash
xcodebuild -project apps/ios/IntonavioLocal.xcodeproj \
  -scheme IntonavioLocalTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

---

## Code Signing & Entitlements

### iOS Entitlements (`Intonavio/Intonavio.entitlements`)

| Entitlement                       | Value     | Purpose                    |
| --------------------------------- | --------- | -------------------------- |
| `com.apple.developer.applesignin` | `Default` | Sign in with Apple support |

### macOS Entitlements (`Intonavio/IntonavioMac.entitlements`)

| Entitlement                              | Value  | Purpose                        |
| ---------------------------------------- | ------ | ------------------------------ |
| `com.apple.security.app-sandbox`         | `true` | App Sandbox                    |
| `com.apple.security.network.client`      | `true` | Outgoing network connections   |
| `com.apple.security.network.server`      | `true` | Local NWListener for WKWebView |
| `com.apple.security.device.audio-input`  | `true` | Microphone access              |
| `com.apple.developer.applesignin`        | `Default` | Sign in with Apple support   |

### Info.plist Keys

| Key                             | Value                                                                 |
| ------------------------------- | --------------------------------------------------------------------- |
| `NSMicrophoneUsageDescription`  | IntonavioLocal needs microphone access to detect your singing pitch.  |
| `NSLocalNetworkUsageDescription`| IntonavioLocal uses a local server to load the YouTube player.        |

---

## SwiftData Container

SwiftData is initialized at app launch with the following models:

- `SongModel` — song metadata, processing status
- `StemModel` — stem type, local file path
- `SessionModel` — practice session data
- `ScoreRecord` — per-song and per-phrase score history

The SwiftData container is created with default configuration (on-disk SQLite in the app's Application Support directory). The `ModelContainer` is passed through the SwiftUI environment.

---

## File Storage Layout

Audio stems and pitch data are stored in the app's Documents directory:

```
Documents/
├── stems/
│   └── {songId}/
│       ├── vocals.mp3
│       ├── instrumental.mp3
│       └── ...
└── pitch/
    └── {songId}/
        └── reference.json
```

`LocalStorageService` manages all path resolution and directory creation.

---

## External Dependencies

IntonavioLocal has no package manager dependencies (no SPM, no CocoaPods). All functionality is built with Apple frameworks:

| Framework     | Purpose                                    |
| ------------- | ------------------------------------------ |
| SwiftUI       | UI                                         |
| SwiftData     | Structured data persistence                |
| AVFoundation  | Audio engine, stem playback, mic input     |
| Accelerate    | vDSP for YIN pitch detection               |
| WebKit        | WKWebView for YouTube IFrame player        |
| Network       | NWListener for local HTML serving          |
| Security      | Keychain API key storage                   |
| OSLog         | Structured logging via AppLogger           |

---

## SwiftLint

SwiftLint runs as an Xcode build phase. Configuration is in `apps/ios/.swiftlint.yml` with strict settings:

| Rule                      | Limit |
| ------------------------- | ----- |
| `file_length`             | 300   |
| `function_body_length`    | 40    |
| `type_body_length`        | 200   |
| `cyclomatic_complexity`   | 10    |
| `nesting`                 | 3     |

Warnings are treated as errors — no warnings allowed in committed code.

---

## Development Environment

| Tool      | Version     | Purpose                      |
| --------- | ----------- | ---------------------------- |
| Xcode     | 16+         | IDE, build, test, debug      |
| XcodeGen  | Latest      | Project generation           |
| SwiftLint | Latest      | Code quality enforcement     |
| macOS     | 15+ (Sequoia) | Development OS             |

### First-Time Setup

1. Install XcodeGen: `brew install xcodegen`
2. Install SwiftLint: `brew install swiftlint`
3. Generate project: `cd apps/ios && xcodegen generate`
4. Open `IntonavioLocal.xcodeproj` in Xcode
5. Select the `IntonavioLocal` scheme and an iOS simulator
6. Build and run
