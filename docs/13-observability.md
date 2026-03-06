# IntonavioLocal — Observability & Debugging

## Overview

IntonavioLocal runs entirely on-device. All observability is through local logging (OSLog via `AppLogger`), Xcode debugging tools, and debug artifacts that can be exported for analysis.

---

## Logging

All logging uses `AppLogger`, a wrapper around `os.Logger` with categorized subsystems. No `print()` in committed code.

### Log Categories

| Category     | Subsystem                    | Usage                                        |
| ------------ | ---------------------------- | -------------------------------------------- |
| `.audio`     | `com.intonaviolocal.audio`   | Audio engine, stem playback, route changes   |
| `.pitch`     | `com.intonaviolocal.pitch`   | Real-time pitch detection, YIN results       |
| `.library`   | `com.intonaviolocal.library` | Song processing, StemSplit API calls         |
| `.sessions`  | `com.intonaviolocal.sessions`| Session save/load, score recording           |
| `.network`   | `com.intonaviolocal.network` | API requests, downloads                      |
| `.youtube`   | `com.intonaviolocal.youtube` | YouTube player events, JS bridge             |

### Log Levels

| Level    | When to Use                                            |
| -------- | ------------------------------------------------------ |
| `debug`  | Detailed diagnostic info (only visible in Console.app) |
| `info`   | Normal operations worth recording                      |
| `error`  | Recoverable errors (API timeout, retry)                |
| `fault`  | Unrecoverable errors (corrupted data, assertion)       |

### Viewing Logs

- **Xcode console**: Shows logs during debug sessions
- **Console.app**: Filter by subsystem `com.intonaviolocal.*` to see logs from device or simulator
- **Terminal**: `log stream --predicate 'subsystem BEGINSWITH "com.intonaviolocal"'`

---

## iOS Client Debugging

### Pitch Detection Debug Mode

Available via Developer Tools in Settings (DEBUG builds only). When enabled:

- Records raw mic input audio buffer alongside detected frequencies
- Records reference pitch lookup results at each timestamp
- Exports a debug file that can be used to reproduce scoring issues offline

When a user reports "scoring feels wrong", this debug artifact allows feeding the exact audio into YIN unit tests for analysis.

### YouTube Sync Drift Log

Every sync correction (drift > 300ms) is logged with:

- `ytTime` — YouTube player's reported time
- `stemTime` — Stem player's current position
- `correction` — Amount of drift corrected

In debug builds, every drift sample (corrected or not) is logged. This reveals patterns like consistent drift on specific videos or audio routes.

### Audio Route Change Log

When AirPods or other audio devices connect/disconnect:

- The route change reason is logged
- Stems are re-synced (stop, re-apply volumes, restart from YouTube time)
- Look for "Audio route changed" and "Re-synced stems after audio route change" entries

### StemSplit API Request Log

In debug builds, all StemSplit API calls are logged with:

- Request URL, method, status code
- Response duration
- Error details on failure

### Song Processing Pipeline Log

Each step of `SongProcessingService` logs its progress:

- Metadata fetch (title, artist, duration)
- StemSplit job creation (job ID)
- Polling status (attempt count, current status)
- Stem downloads (file sizes, durations)
- Pitch analysis (frame count, voiced percentage, duration)
- Final status transition

---

## Debug Reproducibility

For the hardest bugs, ensure reproduction outside the live app:

| Problem               | Debug Artifact                                 | How to Reproduce                                  |
| --------------------- | ---------------------------------------------- | ------------------------------------------------- |
| Wrong pitch detection | Raw audio recording + detected frequencies log | Feed recording into YIN unit test, compare output |
| Wrong scoring         | Session `pitchLog` JSON                        | Re-run scoring function on the saved pitchLog     |
| Bad reference pitch   | Vocal stem file + PitchAnalyzer params         | Run PitchAnalyzer on the stem, inspect output     |
| YouTube sync drift    | Drift correction log                           | Analyze timing pattern, check if video-specific   |
| StemSplit failure     | API request/response log                       | Replay the exact API call with same parameters    |

---

## Xcode Instruments Profiling

Key performance areas to profile:

| Area                   | Instrument        | What to Watch                                    |
| ---------------------- | ----------------- | ------------------------------------------------ |
| Audio thread           | Time Profiler     | YIN detection must complete in <1ms per callback |
| Piano roll rendering   | Core Animation    | Should maintain ~43 FPS during practice          |
| Pitch analysis (batch) | Time Profiler     | Full song analysis time (target: <30s)           |
| Memory                 | Allocations       | No leaks in audio buffers or stem data           |
| Disk I/O               | File Activity     | Stem download write performance                  |

---

## SwiftData Debugging

- Use Xcode's SwiftData debugging: `Arguments Passed On Launch` -> `-com.apple.CoreData.SQLDebug 1`
- Inspect the SQLite database directly at the app's Application Support directory
- `ModelContext.save()` is called explicitly after mutations — watch for missed saves

---

## Common Issues & Solutions

| Symptom                              | Likely Cause                                    | Fix                                              |
| ------------------------------------ | ----------------------------------------------- | ------------------------------------------------ |
| No pitch detection                   | Microphone permission not granted               | Check `AVAudioSession` permissions               |
| Pitch follows the music, not voice   | AEC not working (separate engines)              | Ensure single shared `AudioEngine`               |
| Stems out of sync with video         | Drift threshold too tight or too loose          | Check drift log, adjust 300ms threshold          |
| Song stuck in SPLITTING              | StemSplit API timeout or invalid API key         | Check API key in Settings, check network         |
| Pitch analysis produces all unvoiced | Vocal stem is silent or corrupted               | Re-download stems, check stem file size          |
| Audio stops after AirPods disconnect | Engine not restarted after route change          | Check `ensureEngineRunning()` in AudioEngine     |
