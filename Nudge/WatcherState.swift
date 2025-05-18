import Foundation

enum WatcherState: CaseIterable {
    case stopped
    case runningChecking // Covers "running/checking"
    case idleClear     // Covers "idle/clear"
    case nudgeAlert    // Covers "nudge/alert"
    case error

    var systemImageName: String {
        switch self {
        case .stopped:
            return "stop.circle"
        case .runningChecking:
            return "arrow.triangle.2.circlepath"
        case .idleClear:
            return "checkmark.circle"
        case .nudgeAlert:
            return "bell.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
} 