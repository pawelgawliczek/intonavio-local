# IntonavioLocal — Development Workflow

## Git Conventions

### Repository

- Default branch: `main`
- Branch naming: `feat/description`, `fix/description`, `spike/description`

### Commits

- Imperative mood, concise. `Add stem download endpoint`, not `Added` or `Adding`.
- One logical change per commit. Don't mix refactoring with feature work.

### Pull Requests

- All changes go through PRs — no direct pushes to `main`.
- PR descriptions must include what changed and how to test it.
- Squash merge to `main` for clean history.

---

## Project Setup

### Prerequisites

| Tool      | Install                    | Purpose                |
| --------- | -------------------------- | ---------------------- |
| Xcode     | Mac App Store              | IDE, build, test       |
| XcodeGen  | `brew install xcodegen`    | Project generation     |
| SwiftLint | `brew install swiftlint`   | Code quality           |

### First-Time Setup

```bash
# Clone the repository
git clone <repo-url>
cd IntonavioLocal

# Generate Xcode project
cd apps/ios
xcodegen generate

# Open in Xcode
open IntonavioLocal.xcodeproj
```

Select the `IntonavioLocal` scheme and `iPhone 17 Pro` simulator, then build and run.

---

## Daily Development Workflow

### 1. Pull latest changes

```bash
git checkout main
git pull
```

### 2. Regenerate project (if project.yml changed)

```bash
cd apps/ios
xcodegen generate
```

### 3. Create feature branch

```bash
git checkout -b feat/description
```

### 4. Build and test

Build from Xcode or command line:

```bash
# Build iOS
xcodebuild -project apps/ios/IntonavioLocal.xcodeproj \
  -scheme IntonavioLocal \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# Run tests
xcodebuild -project apps/ios/IntonavioLocal.xcodeproj \
  -scheme IntonavioLocalTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

### 5. Verify lint

SwiftLint runs as an Xcode build phase. Ensure zero warnings (warnings are errors).

### 6. Commit and push

```bash
git add -A
git commit -m "Add description of change"
git push -u origin feat/description
```

### 7. Create PR and merge

---

## Adding New Files

When adding or removing source files:

1. Create/delete the file in the `Intonavio/` directory
2. Regenerate the project: `xcodegen generate`
3. Open the regenerated `.xcodeproj` in Xcode

XcodeGen automatically includes all `.swift` files under the `Intonavio/` source directory. No manual file reference management needed.

---

## Adding a New Feature Module

1. Create a new directory under `Intonavio/Features/{ModuleName}/`
2. Add views, view models, and any module-specific types
3. Regenerate: `xcodegen generate`
4. Wire navigation from `ContentView` or parent views

Follow the architecture rules in `docs/02-architecture.md`:

- Views -> ViewModels -> Services -> Data
- ViewModels use `@Observable` macro
- Max 300 lines per file, 150 lines per View, 40 lines per function

---

## Building for macOS

```bash
xcodebuild -project apps/ios/IntonavioLocal.xcodeproj \
  -scheme IntonavioLocalMac \
  build
```

The macOS target shares the same source code with `#if os(iOS)` / `#if os(macOS)` conditionals where platform-specific behavior is needed (e.g., audio input device selection, navigation style).

---

## Debugging Tips

- **Console.app**: Filter by `com.intonaviolocal` subsystem to see all app logs
- **SwiftData SQL debug**: Add `-com.apple.CoreData.SQLDebug 1` to scheme launch arguments
- **Audio debugging**: Use Xcode Instruments (Time Profiler, Audio) to profile audio thread performance
- **Developer Tools**: In DEBUG builds, Settings -> Developer Tools provides diagnostic views

See `docs/13-observability.md` for detailed debugging guidance.

---

## Code Quality Checklist (Before PR)

- [ ] SwiftLint passes with zero warnings
- [ ] All files under 300 lines
- [ ] All functions under 40 lines
- [ ] All Views under 150 lines
- [ ] No `print()` — use `AppLogger`
- [ ] No hardcoded values — use constants or configuration
- [ ] Unit tests for any new algorithmic code
- [ ] SwiftUI previews for any new views
