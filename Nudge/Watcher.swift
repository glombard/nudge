import Foundation
import Combine

protocol Watcher: AnyObject, ObservableObject, Identifiable {
    // MARK: - Properties
    var id: UUID { get }
    var name: String { get } // e.g., "GitHub Reviewer", "Pomodoro Timer"

    // Published properties for SwiftUI views to observe
    var state: WatcherState { get set }
    var lastErrorMessage: String? { get set }
    var nudges: [Nudge] { get set }
    var anyObjectWillChange: AnyPublisher<Void, Never> { get }
    var statePublisher: AnyPublisher<WatcherState, Never> { get }
    
    // MARK: - Lifecycle & Control Methods
    func start()
    func stop()
    func checkNow()

    // MARK: - Nudge Handling
    func acknowledgeNudge(id: UUID)
    func acknowledgeAllNudges()
}

// Default implementation for Identifiable based on id
extension Watcher {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    // Provide a default hashable conformance if Watcher instances need to be in Sets or Dictionary keys
    // This requires id to be Hashable, which UUID is.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 