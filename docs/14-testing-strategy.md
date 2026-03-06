# IntonavioLocal — Testing Strategy

Goal: automate all verification except subjective audio/visual quality. Human QA is limited to stem audio quality spot-checks, piano roll visual feel, and new device/OS testing before major releases.

## Level 1: Unit Tests (every commit, <30s)

Cover the algorithmic core where bugs are hardest to spot manually.

### Pitch Detection (YINDetector)

- Feed known sine waves (440Hz, 261.63Hz, 329.63Hz) -> assert detected frequency within +/-1 Hz
- Test confidence threshold: noise input -> confidence < 0.8, clean tone -> confidence > 0.8
- Edge cases: silence -> no detection, very low pitch (100Hz) -> still detected with 2048 window

### Scoring Math (ScoringEngine)

- `(440, 440) -> 0 cents`, `(440, 466.16) -> 100 cents`, `(440, 220) -> -1200 cents`
- Frame arrays with known deviations -> assert score matches expected
- All unvoiced reference frames -> score excludes them (no division by zero)
- Transpose: octave up -> reference shifts to 880Hz, singing 880Hz -> excellent (100 score)
- Transpose: octave down -> reference shifts to 220Hz, singing 220Hz -> excellent
- Transpose: mismatch (440Hz detected vs 880Hz adjusted ref) -> poor accuracy
- Transpose: zero offset -> identical to no-transpose behavior
- Transpose: pitch log records adjusted reference Hz, not original

### Difficulty Levels

- Advanced boundary tests: +/-25c excellent, +/-40c good, +/-60c fair, >60c poor
- Intermediate boundary tests: +/-25c excellent, +/-50c good, +/-75c fair, >75c poor
- Beginner boundary tests: +/-150c excellent, +/-300c good, +/-450c fair, >450c poor
- Points vary by level: excellent always 100; good 75/60/50; fair 40/25/20
- `PitchAccuracy.classify(cents:difficulty:)` and `.points(difficulty:)` tested per level

### PitchAnalyzer (Batch Analysis)

- Known sine wave audio file -> correct frequency detected across all frames
- Silent audio -> all frames unvoiced
- RMS filtering: low-energy frames marked as unvoiced regardless of YIN result
- Phrase detection: contiguous voiced regions correctly identified
- Gap merging: gaps < 0.3s within a phrase are bridged
- Short phrase merging: phrases < 0.5s merged into nearest neighbor
- Output JSON format matches expected schema

### Exercise Pitch Generator

- `{midi: 60, duration: 1.0, tempo: 60}` -> assert 86 frames, all at 261.63 Hz
- Vibrato: `{midi: 60, vibrato: {cents: 30, rateHz: 5.5}}` -> frequency oscillates within +/-30 cents
- Rest periods -> unvoiced frames with `hz: null`
- Tempo scaling: double tempo -> half the frame count

### SwiftData Models

- `SongModel` status transitions: QUEUED -> SPLITTING -> DOWNLOADING -> ANALYZING -> READY
- `SongModel` unique `videoId` constraint enforced
- Cascade deletes: delete song -> stems and sessions removed
- `StemModel` local path resolution via `LocalStorageService`
- `SessionModel` pitch log encode/decode round-trip
- `ScoreRecord` personal best lookup by songId, phraseIndex, difficulty

### StemSplitService

- Job creation request format (URL, headers, body)
- Job status parsing (completed, failed, pending states)
- Stem URL extraction from job response
- Error handling: invalid API key, network timeout, malformed response
- Polling logic: correct interval, max attempts, timeout

### YouTubeMetadataService

- oEmbed response parsing (title, author, thumbnail)
- YouTube URL validation (various URL formats)
- Error handling: invalid URL, network failure

### KeychainService

- Save and retrieve API key round-trip
- `hasStemSplitAPIKey` returns correct state
- Delete API key

## Level 2: Integration Tests (manual or pre-release)

Test real interactions between components.

### Song Processing Pipeline

- Submit a YouTube URL -> verify full pipeline: metadata fetch -> StemSplit job (mocked) -> stem download (mocked) -> pitch analysis -> READY
- FAILED states: StemSplit timeout -> FAILED with error message, retry resets to QUEUED
- Deduplication: same videoId -> rejected

### Audio Pipeline

- Stem files load from Documents directory into AVAudioPlayerNode
- Audio mode switching: volumes change correctly for each mode (full, vocals, instrumental)
- Video-audio sync: drift detection and correction logic

### Practice Flow

- Load song -> load stems -> load reference pitch -> start practice -> detect pitch -> compute score -> save session
- Loop scoring: A-B loop -> per-pass score capture -> reset between passes

## Level 3: Contract Tests (periodic)

Catch breaking changes in external services. Cost: ~$0.46 per run (one StemSplit job).

- **StemSplit API**: hit real API with one test song, assert response shape, job completes, download URLs work
- **YouTube oEmbed**: fetch real endpoint, assert response contains title and author_name

## Level 4: UI Tests (before release)

XCUITest for critical paths. Keep count low.

| #   | Path                                                                                     | Asserts                           |
| --- | ---------------------------------------------------------------------------------------- | --------------------------------- |
| 1   | Launch -> Settings -> enter API key -> Library -> Add Song -> wait for READY              | Song in library with status READY |
| 2   | Open song -> play stems -> set A-B loop -> loop repeats                                  | Playback loops between markers    |
| 3   | Open song -> start practice -> sing -> see pitch on piano roll -> stop -> session saved   | Session in history with score > 0 |

**Note:** Inject pre-recorded audio via AVAudioEngine test mode instead of real microphone — deterministic and CI-compatible.

## What Remains Manual

| Check                         | When                                    | Why                              |
| ----------------------------- | --------------------------------------- | -------------------------------- |
| Stem audio quality spot-check | StemSplit config change or user reports  | Subjective quality               |
| Piano roll visual review      | After practice screen UI changes        | Animation/layout feel            |
| New device/OS testing         | Before major releases                   | Hardware-specific audio behavior |
| Echo cancellation quality     | After AudioEngine changes               | Requires real mic + speaker test |
