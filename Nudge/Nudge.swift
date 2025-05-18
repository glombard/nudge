import Foundation

struct Nudge: Identifiable {
    let id = UUID()
    let title: String      // e.g. "Review #3728"
    let originatingWatcherName: String // e.g. "GitHub" or "Timer"
    let action: () -> Void // e.g. open PR, copy URL

    // To make Nudge Equatable if needed, especially for UI updates or state management.
    // We only compare by id as title and action might be complex or closures.
    static func == (lhs: Nudge, rhs: Nudge) -> Bool {
        lhs.id == rhs.id
    }
} 