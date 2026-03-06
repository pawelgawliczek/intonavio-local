# IntonavioLocal — Code Quality Standards

## Code Quality Thresholds

### Test Coverage

| Scope                   | Minimum             | Measured By                                              |
| ----------------------- | ------------------- | -------------------------------------------------------- |
| **Algorithmic modules** | 95% branch coverage | Pitch detection, scoring, exercise generator, cents math |
| **New code in PR**      | 80% line coverage   | PR review                                                |

Algorithmic modules (YIN detector, scoring calculator, exercise pitch generator, cents deviation) are the most critical — a silent regression here affects every user. 95% branch coverage ensures all code paths including edge cases (silence, NaN, zero division) are tested.

### File Size Limits

| Metric                            | Limit | Rationale                                           |
| --------------------------------- | ----- | --------------------------------------------------- |
| **Max lines per file**            | 300   | Forces decomposition into focused modules           |
| **Max lines per function/method** | 40    | Functions that do one thing stay short              |
| **Max lines per Swift View**      | 150   | Extract subviews and modifiers beyond this          |
| **Max lines per test file**       | 500   | Test files can be longer — readability over brevity |

### Code Complexity

| Metric                                 | Limit                                | Tool                                      |
| -------------------------------------- | ------------------------------------ | ----------------------------------------- |
| **Cyclomatic complexity per function** | ≤ 10                                | SwiftLint `cyclomatic_complexity`          |
| **Max nesting depth**                  | 3 levels                             | SwiftLint `nesting`                        |
| **Max function parameters**            | 4                                    | Beyond 4, use an options/config struct     |
| **Max dependencies per module**        | 8 imports from other project modules | If a module imports 8+ siblings, split it  |

### Linter Config

- **Swift**: SwiftLint with `strict` configuration (`.swiftlint.yml`)
- All linter rules run as an Xcode build phase. No warnings allowed — treat warnings as errors.

---

## Code Quality Rules

### General

- No hardcoded secrets, URLs, or environment-specific values. API key stored in Keychain, not in code.
- No disabled linter rules (`swiftlint:disable`) without a comment explaining why.
- No `print()` in committed code. Use `AppLogger` (OSLog wrapper).
- No dead code. Don't comment out code "for later" — delete it, git has history.
- Prefer `let` over `var`. Use `var` only when reassignment is needed.
- Prefer early returns over nested `if/else`.
- Functions do one thing. If a function name contains "and", split it.
- Max function length: ~40 lines. If longer, extract helpers.
- Name booleans as questions: `isReady`, `hasStems`, `canRetry`.
- Name functions as actions: `fetchSong`, `createSession`, `detectPitch`.

### SwiftUI & Swift

- MVVM architecture. Views are declarative, ViewModels hold state and logic.
- Use `@Observable` macro (iOS 17+), not `ObservableObject`.
- Use SwiftData `@Model` for persistent data.
- Views are declarative — no side effects in `body`.
- Extract subviews when a View exceeds 150 lines.
- `async/await` and `Task` for all async work. Cancel tasks when views disappear.
- Audio thread (`installTap` callback): no memory allocation, no locks, no UI updates. Dispatch results to main thread.
- Configure `AVAudioSession` once at app startup. Handle interruptions (phone calls, alarms).
- Use `Codable` structs for all data serialization. No manual JSON parsing.
- SwiftUI previews for every view with mock data.
- Use `AppLogger` for all logging (categorized: `.audio`, `.pitch`, `.library`, etc.).

### SwiftData

- `@Model` classes are `final`.
- Enum properties stored as `String` raw values (SwiftData limitation), with computed property for type-safe access.
- `@Attribute(.unique)` on `id` and natural keys (`videoId`).
- Cascade delete rules defined on all parent-child relationships.
- `ModelContext.save()` called explicitly after mutations.
- Fetch using `FetchDescriptor` with predicates — no unbounded fetches.

### Audio Thread Safety

- Audio tap callbacks run on a real-time thread. Rules:
  - No memory allocation (`malloc`, `Array.append`, etc.)
  - No locks (`NSLock`, `DispatchSemaphore`, etc.)
  - No Objective-C message dispatch (avoid `@objc` calls)
  - No UI updates
  - Copy data into a pre-allocated ring buffer, process on main thread
- `YINDetector` uses pre-allocated `UnsafeMutableBufferPointer` for all intermediate buffers.
- `PitchDetector` dispatches results to `@MainActor` after detection.

### File Storage

- Consistent path naming: `stems/{songId}/{stemtype}.mp3` (lowercase), `pitch/{songId}/reference.json`.
- All file operations go through `LocalStorageService` — no direct `FileManager` calls in ViewModels or Views.
- `ensureDirectory(at:)` before any write operation.
- Cleanup: `deleteSongFiles(songId:)` removes both stem and pitch directories.

### Keychain

- API key stored via `KeychainService` with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Never log or display the full API key. Settings UI shows masked version.
- `hasStemSplitAPIKey` computed property for quick existence checks.

### External API Calls

- All external API calls go through dedicated service enums (`StemSplitService`, `YouTubeMetadataService`).
- Error types are `LocalizedError` with descriptive `errorDescription`.
- No scattered URLSession calls in ViewModels or Views.
- API key read from Keychain per request — never cached in memory.
- Cancellation: check `Task.isCancelled` / `Task.checkCancellation()` between pipeline steps.

#### Split Spectrum Design Language

The app uses a dark-mode-only "Voice Cockpit" aesthetic. All colors are defined in `App/DesignSystem.swift`.

**Color palette** (use these instead of system colors):

| Token                          | Hex             | Usage                                                |
| ------------------------------ | --------------- | ---------------------------------------------------- |
| `Color.intonavioBackground`    | `#0E0F12`       | Deep Charcoal — primary backgrounds                  |
| `Color.intonavioSurface`       | `#1C1E24`       | Lighter Charcoal — cards, surfaces, secondary panels |
| `Color.intonavioMagenta`       | `#D946EF`       | Gradient start — branding                            |
| `Color.intonavioAmber`         | `#F59E0B`       | Gradient end — branding                              |
| `Color.intonavioIce`           | `#E6F6FF`       | Ice — playheads, selected states, icons              |
| `Color.intonavioTextPrimary`   | `#FFFFFF`       | Primary text                                         |
| `Color.intonavioTextSecondary` | `#A1A1AA`       | Secondary text / metadata                            |
| `LinearGradient.intonavio`     | Magenta -> Amber | CTA buttons, branding elements                       |

**Rules:**

- **Dark mode only.** `preferredColorScheme(.dark)` is forced at the root. No theme picker.
- **Backgrounds:** Use `Color.intonavioBackground`, never `Color(.systemBackground)`.
- **Surfaces/cards:** Use `Color.intonavioSurface`, never `Color(.systemGroupedBackground)`.
- **CTA buttons:** Use `PrimaryButtonStyle()` (gradient capsule) for primary actions (Add Song, Try Again).
- **Secondary buttons:** Use `SecondaryButtonStyle()` (Ice border capsule).
- **Selected states:** Use `Color.intonavioIce` for selected controls, playheads, active toggles.
- **Inactive controls:** Use `Color.intonavioTextSecondary` foreground on `Color.intonavioSurface` background.
- **Functional accuracy colors are preserved:** Green, yellow, orange, red for pitch accuracy, score indicators, loop markers, and status badges. Do not replace these with design system colors.
- **Text:** Use `.white` or `Color.intonavioTextPrimary` for primary text, `Color.intonavioTextSecondary` for labels/metadata. Avoid `.secondary`/`.tertiary` semantic colors.
- **Toast/overlay backgrounds:** Use `Color.intonavioSurface` instead of `.ultraThinMaterial`.
