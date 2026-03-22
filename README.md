# BibleMemorizeKit

`BibleMemorizeKit` is a Swift package foundation for an Apple Bible memorization app.

It includes:

- verse and review data models
- a spaced-repetition scheduler
- review session flow
- an observable store for SwiftUI apps
- a starter dashboard view with sample data

## Structure

- `Sources/BibleMemorizeKit/Models`: verse, review, card, and collection models
- `Sources/BibleMemorizeKit/Core`: scheduling, sessions, and app store logic
- `Sources/BibleMemorizeKit/UI`: SwiftUI-facing view model and starter dashboard
- `Sources/BibleMemorizeKit/Support`: seed data for previews and initial scaffolding

## Add To An Apple App

1. Create a new iOS app in Xcode with SwiftUI.
2. Add this folder as a local Swift package dependency.
3. Use `MemoryDashboardView()` as your starting screen.

Example app entry point:

```swift
import SwiftUI
import BibleMemorizeKit

@main
struct BibleMemorizeApp: App {
    var body: some Scene {
        WindowGroup {
            MemoryDashboardView()
        }
    }
}
```

## Next Build Steps

- replace sample data with persistent storage using SwiftData or CloudKit
- add verse import from a licensed Bible source
- build focused review screens for type-to-recall, fill-in-the-blank, and audio recitation
- add progress analytics, streaks, and collection goals
