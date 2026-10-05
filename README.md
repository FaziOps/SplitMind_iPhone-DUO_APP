# SplitMind

A dual-pane reader and AI synthesis workspace for iPhone Duo, with a single-pane mode for standard iPhones. It implements Phase 1 of the SplitMind PRD (v1 + v2 merged).


```
SplitMind_DuoApp/
├── app/        Flutter iOS app (Clean Architecture + BLoC)
└── backend/    AI proxy (Node 22, no dependencies): holds the model key, enforces quotas
```

## Run it on macOS

Requirements: Flutter 3.44+, Xcode with an iOS Simulator runtime, Node 22.9+. CocoaPods is optional because the project resolves plugins with Swift Package Manager.

**1. Start the backend** (mock AI by default, so no API key is needed):

```bash
cd backend
cp .env.example .env      # optional; defaults work for local dev
npm start                 # http://localhost:8787
npm test                  # 11 tests
```

**2. Run the app** in another terminal:

```bash
cd app
flutter pub get
open -a Simulator         # or: xcrun simctl boot "iPhone Duo"
flutter run               # pick the iPhone Duo or a standard iPhone simulator
```

The app calls `http://localhost:8787` by default, which the iOS Simulator can reach. To point it somewhere else:

```bash
flutter run --dart-define=SPLITMIND_API_BASE_URL=https://api.example.com
```

On a **physical iPhone**, use your Mac's LAN address (for example `http://192.168.1.20:8787`) or an HTTPS tunnel, because `localhost` there is the phone. `Info.plist` allows local-network HTTP for development through `NSAllowsLocalNetworking`. Remove that setting for release builds.

**3. Tests and checks**


```bash
cd app && flutter analyze && flutter test     # 61 tests

# Optional: check the app's network stack against a running backend
SPLITMIND_BACKEND_URL=http://localhost:8787 flutter test test/integration
```

The iOS deployment target is 15.0, the minimum Xcode 27 supports. The app is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`).

### Known toolchain issue: `flutter build ios --simulator`

With Flutter 3.44.2 and Xcode 27, `flutter build ios --simulator` fails with *"Flutter.framework does not contain architectures arm64 x86_64"*. Xcode 27's `lipo -verify_arch` now takes only one architecture, but Flutter passes two for universal simulator builds. `flutter run` builds only the active architecture and works normally. Device builds (`flutter build ios`) are not affected. The fix belongs in a future Flutter release, so the project is left unchanged.

## Using real AI (Gemini)

Set these in `backend/.env`:

```
AI_PROVIDER=gemini
GEMINI_API_KEY=...           # server-side only; never ships in the app
GEMINI_MODEL=...             # confirm the current model id before shipping
TOKEN_SECRET=<32+ random bytes, hex>
```

Use a paid-tier key so prompts are not used for training. The in-app disclosure (NFR-7) promises this.

## Trying the features


| What | How |
|---|---|
| Dual pane (FR-1) | iPhone Duo simulator, or any window 600pt or wider |
| Single pane + slide-up notes (FR-1a) | Standard iPhone simulator. Tap **AI Notes**, or send text to AI and the panel opens itself |
| Laptop mode (FR-2) | Debug builds show a fold icon in the reader toolbar. Choose **Laptop mode (110°)** |
| Send to AI (FR-3a) | Select text, then use **Explain / Summarize / Flashcards** in the system menu, or any action in the bar under the page |
| More AI actions | **Simplify**, **Key terms** and **Quiz** in the selection bar and on the passage card. Type in **Ask about this passage**, or tap a suggested question |
| Study flashcards | Flashcard notes hide each answer until you tap the card. **Show all answers** reveals them all |
| Jump to source (FR-8) | Tap a note's underlined page citation, or choose **Go to page N** in its menu |
| Find notes | Filter chips above the notes list show one kind of note at a time |
| Undo delete | Delete a note from its menu, then tap **Undo** in the snackbar |
| Go to page | Tap **Page X of Y** in the reader toolbar |
| Drag and drop (FR-3) | In dual-pane mode, drag the excerpt chip from the selection bar onto the notes pane |
| Accessible path (NFR-6) | The toolbar's ✨ button sends the current page's text, so VoiceOver users don't need to select text |
| Error states (FR-11) | With the mock backend, include `[[safety]]` or `[[upstream]]` in a selection. Stop the backend to see the offline state |
| Offline cache (FR-6) | Force-quit and relaunch. The document reopens at the same page and notes are restored |

## Architecture

```
lib/
├── core/
│   ├── constants/      layout thresholds (600pt, 90°–135°), AI debounce and limits
│   ├── device/         FoldableDeviceAdapter (Adapter) + DevicePostureCubit
│   ├── error/          typed AI failures (one UI state each, FR-11)
│   ├── network/        BackendApiClient: anonymous auth, bearer token, error mapping
│   ├── storage/        AppSettings (Hive)
│   ├── theme/          Material 3, light/dark
│   └── utils/          debounce event transformer
├── features/
│   ├── workspace/      ActiveWorkspaceBloc (Mediator), layout resolver, WorkspaceScreen
│   ├── reader/         left pane: PDF (pdfrx), import, selection → mediator
│   ├── ai_notes/       right pane: AiNotesBloc, repository → backend proxy + Hive
│   └── onboarding/     FR-10 first-run flow with interactive demo + AI disclosure
├── injection_container.dart   get_it wiring (Factory Method / DI)
└── main.dart
```

**Data flow.** The reader turns a selection into a `Highlight` and sends `ReaderBloc` events to `ActiveWorkspaceBloc` (the Mediator). `AiNotesBloc` observes the mediator, calls `GenerateSynthesisUseCase`, which calls `NotesRepository`, which calls `BackendProxyDataSource` (`POST /v1/synthesize`), then caches the result in Hive. Neither pane imports the other.

**Design decisions that differ from the PRD's sample code:**

- **Highlighting never calls the AI.** The v1 `AiNotesBloc` fired a request on every highlight. Here a highlight only updates state, and a request needs an explicit action. Requests show as pending immediately (NFR-1), but dispatch is debounced by 600 ms so only the last request in a burst is sent (NFR-5).
- **The notes overlay is not a modal route.** It is a `DraggableScrollableSheet` inside the workspace `Stack`. The reader stays usable while it is open, and folding or unfolding never leaves an orphaned sheet on screen. `GlobalKey`s move each pane between layouts without rebuilding it.
- **Hive adapters are hand-written**, in the same binary format `hive_ce_generator` produces, so no `build_runner` step is needed. The schemas are documented in `note_model.dart` and `document_model.dart`. The app uses `hive_ce`, the maintained fork of `hive`.
- **PDFs are stored by file name**, not absolute path, because the iOS app container path changes on app updates.
- **DR-3.** PDFs whose permissions forbid copying can't be sent to AI.
- **FR-8.** Every note keeps its source text, document and page.

## Backend API

| Endpoint | Purpose |
|---|---|
| `POST /v1/auth/anonymous` | Issues a signed, device-scoped bearer token |
| `POST /v1/synthesize` | `{text, action: explain\|summarize\|flashcard\|simplify\|terms\|quiz\|ask, question?, docId?, page?}` → `{markdown, quota, …}`. `question` (up to 500 characters) is required for `ask` |
| `GET /v1/quota` | Remaining daily allowance |
| `GET /health` | Liveness check |

Cost controls (NFR-5): a daily per-user quota (`DAILY_QUOTA`, 200 by default), a minimum interval between requests, and de-duplication. Identical requests within `DEDUPE_WINDOW_MS` share one upstream call and aren't charged twice. Upstream failures are refunded. Error responses map one-to-one to app states: 401, 413, 422 `safety_blocked`, 429 `quota_exceeded` or `rate_limited`, 502, 504. Logs record sizes and latency only, never passage text.

Quota state is in memory, which is fine for a single instance. Move it to Redis or Firestore before running more than one.

## Open items before launch

- **Hinge angle on iPhone Duo.** `ios/Runner/AppDelegate.swift` has a stub where the hinge sensor plugs in. No public iOS hinge-angle API was known when this was written. Until one is wired up, the app picks its layout from screen width and Flutter `DisplayFeature`s.
- **Real sign-in** (Sign in with Apple and similar) to replace anonymous tokens. Quotas key off whatever user id `verifyToken()` returns.
- **Privacy policy, App Privacy label, and a legal review** of DR-3 (NFR-7).
- **Out of scope for Phase 1 per the PRD:** web links, EPUB/DOCX/OCR, Apple Pencil, export/Anki, cloud sync.
