# IntonavioLocal — Product Overview

## Vision

IntonavioLocal is a fully on-device singing practice app that transforms YouTube lyrics videos into interactive training sessions. By combining stem separation (via user-provided StemSplit API key), on-device pitch detection, and looping controls, singers can isolate vocals, practice difficult passages at reduced speed, and get visual feedback on their pitch accuracy — all using the vast library of lyrics videos already on YouTube.

Unlike the original Intonavio, this version has **no backend server**. All processing, storage, and session tracking happen locally on the device.

## Problem Statement

Singers who practice with YouTube lyrics videos lack tools to:

- **Isolate or remove vocals** from the backing track
- **Loop specific sections** (verse, chorus, bridge) without manual rewinding
- **See their pitch** compared to the reference vocal in real time
- **Track progress** across practice sessions

Existing karaoke apps use limited licensed catalogs. IntonavioLocal leverages YouTube's unlimited library and adds the missing practice tools — entirely on-device.

## Target Users

- Amateur and semi-professional singers practicing at home
- Vocal students preparing for lessons or auditions
- Choir members learning their part
- Hobbyist singers who want structured practice with their favorite songs

## Core Features

| Feature                        | Description                                                                                                                                       |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **YouTube Integration**        | Paste any YouTube lyrics video URL to start practicing                                                                                            |
| **Stem Separation**            | Split audio into up to 6 stems via StemSplit API (user provides their own API key)                                                                |
| **A-B Looping**                | Set loop markers on the video timeline, repeat sections at adjustable speed (0.25x-2.0x)                                                          |
| **Real-Time Pitch Detection**  | Detect the singer's pitch via microphone and display on an interactive piano roll (touch to pause, swipe to scrub, long-press to loop a phrase)   |
| **Pitch Comparison**           | Overlay detected pitch against the reference vocal pitch, color-coded by accuracy                                                                 |
| **Scoring**                    | Per-note and per-session accuracy scores with historical tracking, 3 difficulty levels (Beginner/Intermediate/Advanced) with separate best scores |
| **Practice Sessions**          | Save and review past sessions with timestamped pitch data                                                                                         |
| **Audio Mode Toggle**          | Switch between original audio, instrumental only, or vocals only during practice                                                                  |
| **Exercises**                  | Pre-built vocal exercises (scales, arpeggios, intervals, vibrato, breathing)                                                                      |
| **Toggleable Practice Layout** | Switch between lyrics-focused (video 65%, pitch 35%) and pitch-focused (video 25%, pitch 75%) modes                                               |
| **Guide Tone**                 | Play reference pitch as a guide tone during practice (configurable instrument)                                                                     |

## Platform Strategy

| Platform      | Technology                | Status                                               |
| ------------- | ------------------------- | ---------------------------------------------------- |
| **iOS**       | SwiftUI + AVAudioEngine   | Primary target — real-time pitch via native audio APIs |
| **macOS**     | SwiftUI (shared codebase) | Shared target from the iOS project                    |

**No authentication.** The app runs entirely on-device with no user accounts, sign-in, or server-side identity.

iOS is the primary target because:

- AVAudioEngine provides low-latency microphone access ideal for pitch detection
- WKWebView can embed YouTube videos with JavaScript bridge for looping control
- SwiftUI code shares well with a macOS target
- All data stays on-device via SwiftData and the Documents directory

## What IntonavioLocal Is Not

- Not a karaoke app with a licensed song catalog
- Not a music production tool (no editing, mixing, or export)
- Not a vocal lesson platform (no instructional content)
- Not a cloud/SaaS service — no backend, no accounts, no sync

IntonavioLocal is a **practice tool** — focused, personal, and built around the singer's workflow of picking a song, isolating parts, looping sections, and improving pitch accuracy over time. Everything runs on your device.
