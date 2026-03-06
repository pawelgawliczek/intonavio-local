# IntonavioLocal — Project Instructions

## Project Overview

IntonavioLocal is a fully on-device singing practice app for iOS and macOS. It uses YouTube lyrics videos, stem separation (StemSplit API — user provides their own API key), and real-time pitch detection to help singers improve. Unlike the original Intonavio, this version runs 100% on-device with no backend server — all pitch analysis, data storage, and session tracking happen locally.

## Tech Stack

- **iOS/macOS**: SwiftUI, AVAudioEngine, WKWebView, SwiftData
- **Pitch Analysis**: On-device batch YIN (Accelerate/vDSP)
- **Storage**: SwiftData (structured data), Documents directory (stems + pitch data), Keychain (API key)
- **External**: StemSplit API (stem separation, user-provided API key), YouTube oEmbed (metadata)
- **Build**: XcodeGen (`project.yml`)

## Architecture

```
iOS App (SwiftUI)
    ├── SwiftData (songs, stems, sessions)
    ├── Documents/ (stem audio files, pitch reference JSON)
    ├── Keychain (StemSplit API key)
    ├── StemSplit API (direct URLSession calls)
    ├── YouTube oEmbed (metadata)
    └── On-device YIN pitch analysis (Accelerate)
```

**No backend server.** The app calls the StemSplit API directly, downloads stems to local storage, analyzes pitch on-device using the YIN algorithm, and stores all data in SwiftData.

## Critical Coding Rules

### Absolute Prohibitions

- No hardcoded secrets, URLs, or environment-specific values.
- No dead code — don't comment out code "for later", delete it.
- No `var` — use `let`, or `var` only when reassignment is needed.

### Naming & Style

- Booleans as questions: `isReady`, `hasStems`, `canRetry`.
- Functions as actions: `fetchSong`, `createSession`, `detectPitch`.
- Prefer early returns over nested `if/else`.
- Functions do one thing. If a function name contains "and", split it.

### Size Limits

- Max 300 lines per file, 40 lines per function, 150 lines per View/component.
- Max 4 function parameters — beyond that, use an options object/struct.
- Max nesting depth: 3 levels.

### SwiftUI & Swift

- Use `@Observable` for view models, not `ObservableObject`.
- Use SwiftData `@Model` for persistent data.
- Views are declarative — no side effects in `body`.
- Extract subviews when a view exceeds 150 lines.
- Use `AppLogger` (OSLog) for logging, never `print()`.

### Git

- Imperative mood commits: `Add stem download endpoint`.
- One logical change per commit. All changes via PRs to `main`.

## Key Architecture Decisions

### Data Flow

1. User pastes YouTube URL
2. `SongProcessingService` orchestrates the pipeline:
   - Fetches metadata via YouTube oEmbed
   - Creates `SongModel` in SwiftData (status: queued)
   - Calls StemSplit API to create job (status: splitting)
   - Polls job status every 15s (max 10 min)
   - Downloads stems in parallel (status: downloading)
   - Saves stems to `Documents/stems/{songId}/`
   - Runs on-device pitch analysis (status: analyzing)
   - Saves pitch data to `Documents/pitch/{songId}/reference.json`
   - Sets status to ready

### Models (SwiftData)

- `SongModel` — song metadata, status, relationships to stems/sessions
- `StemModel` — stem type, local file path, file size
- `SessionModel` — practice session with score, pitch log, duration

### Services

- `SongProcessingService` — orchestrates the full song pipeline
- `StemSplitService` — direct URLSession calls to StemSplit API
- `YouTubeMetadataService` — YouTube oEmbed + thumbnail resolution
- `PitchAnalyzer` — batch YIN pitch analysis on vocal stem
- `LocalStorageService` — file path management for Documents directory
- `KeychainService` — secure API key storage

## iOS Build

- When building for iOS Simulator, use `iPhone 17 Pro` as the destination.
- Generate project: `cd apps/ios && xcodegen generate`
- Build: `xcodebuild -project apps/ios/IntonavioLocal.xcodeproj -scheme IntonavioLocal -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

## Project Structure

```
IntonavioLocal/
├── apps/
│   └── ios/
│       ├── project.yml              # XcodeGen project definition
│       └── Intonavio/
│           ├── App/                  # App entry point, AppState, ContentView
│           ├── Audio/                # AudioEngine, StemPlayer, pitch detection
│           │   └── Pitch/            # YINDetector, PitchDetector, ScoringEngine
│           ├── Data/                 # SwiftData models (Song, Stem, Session)
│           ├── Features/
│           │   ├── Library/          # Song library, add song
│           │   ├── Practice/         # Song & exercise practice, piano roll
│           │   ├── Progress/         # Score tracking
│           │   ├── Sessions/         # Session history
│           │   └── Settings/         # Settings, API key, developer tools
│           ├── Services/             # StemSplit, YouTube, PitchAnalyzer, storage
│           ├── YouTube/              # WKWebView YouTube player
│           └── Utilities/            # Logging, extensions
├── docs/                             # Architecture & design docs
└── screenshots/                      # App screenshots
```
