# IntonavioLocal

A fully on-device singing practice app that turns any YouTube song into a pitch trainer. Paste a URL, get the vocals separated from the music, and see your pitch plotted against the original singer in real time.

This is the local-only version of [Intonavio](https://github.com/pawelgawliczek/intonavio). No backend server required — all pitch analysis, data storage, and session tracking happen on-device. The only external dependency is the StemSplit API for stem separation (you provide your own API key).

**[Read the blog post](https://pawelgawliczek.cloud/blog/i-built-a-singing-practice-app-because-my-ear-wasnt-ready)** · **[App page](https://pawelgawliczek.cloud/apps/intonavio)**

## Screenshots

<p align="center">
  <img src="screenshots/library.png" alt="Song library" width="230" />
  &nbsp;&nbsp;
  <img src="screenshots/practice.png" alt="Practice mode with pitch detection" width="230" />
  &nbsp;&nbsp;
  <img src="screenshots/scores.png" alt="Phrase-by-phrase scores" width="230" />
</p>

## Features

- **Any YouTube song** - Paste a lyrics video URL. The app extracts audio and prepares it for practice.
- **AI stem separation** - Vocals and instrumental get split automatically using the StemSplit API, so you can karaoke any song or isolate the singer to study their technique.
- **Real-time pitch detection** - Sing into the mic and see your pitch on a piano roll, overlaid on the reference vocalist. Color-coded: green when you're close, red when you're off.
- **Synced lyrics** - The lyrics video plays at the top of the practice screen, scrolling in time with the music.
- **A-B looping** - Set markers on any section, slow it down, repeat until it clicks. Speed goes from 0.25x to 4x.
- **Phrase-by-phrase scoring** - Every phrase gets its own accuracy score so you know exactly which parts need work.
- **Three difficulty levels** - Beginner gives you wide tolerance. Advanced expects you to be almost spot on.
- **Vocal exercises** - Scales, arpeggios, intervals, vibrato. Same pitch detection and scoring as song practice.
- **Karaoke mode** - Play just the instrumental and sing over it. Works with any YouTube song.
- **100% on-device** - No backend server. Pitch analysis runs locally using the YIN algorithm with Accelerate/vDSP. All data stored in SwiftData and local files.

## How it works

1. You paste a YouTube URL
2. The app fetches metadata via YouTube oEmbed
3. Audio is sent to StemSplit API for stem separation
4. Stems are downloaded and stored locally on your device
5. The app analyzes the vocal stem on-device with YIN pitch detection to build a reference pitch graph
6. During practice, the app plays the song, listens to your mic, and scores you in real time

```
iOS/macOS App (SwiftUI)
    ├── SwiftData (songs, stems, sessions)
    ├── Documents/ (stem audio files, pitch reference JSON)
    ├── Keychain (StemSplit API key)
    ├── StemSplit API (stem separation)
    └── YouTube oEmbed (metadata)
```

## Tech stack

| Layer          | Technology                                      |
| -------------- | ----------------------------------------------- |
| iOS/macOS      | SwiftUI, AVAudioEngine, WKWebView, SwiftData    |
| Pitch analysis | On-device YIN algorithm (Accelerate/vDSP)       |
| Storage        | SwiftData, Documents directory, Keychain        |
| External API   | StemSplit (stem separation), YouTube oEmbed      |
| Build          | XcodeGen                                        |

## Project structure

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

## Getting started

### Prerequisites

- Xcode 16+
- XcodeGen (`brew install xcodegen`)
- A StemSplit API key ([stemsplit.io](https://stemsplit.io))

### Setup

```bash
git clone https://github.com/pawelgawliczek/intonavio-local.git
cd intonavio-local

# Generate Xcode project
cd apps/ios
xcodegen generate
open IntonavioLocal.xcodeproj
```

Build and run on a simulator or device. On first launch, go to Settings and enter your StemSplit API key.

### Running tests

```bash
xcodebuild -project apps/ios/IntonavioLocal.xcodeproj -scheme IntonavioLocal \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## External services

| Service                           | Purpose               | Required |
| --------------------------------- | --------------------- | -------- |
| [StemSplit](https://stemsplit.io) | Audio stem separation | Yes      |

## License

[MIT](LICENSE)
