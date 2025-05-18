import Foundation
import Combine

class TimerWatcher: Watcher { // Watcher already conforms to ObservableObject & Identifiable
    // MARK: - Watcher Protocol Requirements
    let id = UUID()
    let name: String = "Timer" // TODO(lombard): Make name configurable if multiple timers are ever needed

    @Published var state: WatcherState = .stopped
    @Published var lastErrorMessage: String?
    @Published var nudges: [Nudge] = []

    var anyObjectWillChange: AnyPublisher<Void, Never> {
        objectWillChange.eraseToAnyPublisher()
    }

    var statePublisher: AnyPublisher<WatcherState, Never> {
        $state.eraseToAnyPublisher()
    }

    // MARK: - Timer-Specific Properties
    private var timer: Foundation.Timer? // Explicitly using Foundation.Timer
    private var countdownSeconds: Int = 10 // Default, can be made configurable later via InternalWatcherConfig
    private var currentCountdown: Int = 0
    private let internalConfig: InternalWatcherConfig

    // MARK: - Initialization
    init(config: InternalWatcherConfig) {
        self.internalConfig = config
        if let duration = config.timerDuration { // Use timerDuration from InternalWatcherConfig
            self.countdownSeconds = Int(duration)
        }
        // Default countdownSeconds is used if config.timerDuration is nil
        print("TimerWatcher [\(id)]: Initialized. Name: \(name). Effective countdown: \(countdownSeconds)s. Initial state: \(state)")
    }

    // MARK: - Watcher Protocol Methods (Implementation)
    func start() {
        print("TimerWatcher [\(id)]: Start requested. Current state: \(state)")
        // Prevent starting if already in a running or counting phase
        guard state != .runningChecking && state != .idleClear else {
            print("TimerWatcher [\(id)]: Already running or counting down (state: \(state)). Ignoring start request.")
            return
        }
        
        // 1. Transition to .runningChecking (briefly, simulating a quick check/setup)
        state = .runningChecking
        print("TimerWatcher [\(id)]: State changed to .runningChecking (simulating check).")

        // 2. Prepare for countdown
        currentCountdown = countdownSeconds
        nudges.removeAll() // Clear any previous nudges
        lastErrorMessage = nil // Clear any previous error
        
        // 3. Transition to .idleClear (running quietly in background, all OK)
        // This change should be picked up by WatcherManager before countdown visually begins
        state = .idleClear 
        print("TimerWatcher [\(id)]: State changed to .idleClear (countdown starting). Countdown set to \(currentCountdown)s.")

        // 4. Start the actual countdown timer
        startCountdownTimer()
    }

    func stop() {
        print("TimerWatcher [\(id)]: Stop requested. Current state: \(state)")
        timer?.invalidate()
        timer = nil
        state = .stopped
        nudges.removeAll()
        currentCountdown = 0 // Reset countdown
        print("TimerWatcher [\(id)]: Stopped. State changed to .stopped")
    }

    func checkNow() {
        // TODO(lombard): Use checkNow() to report current status or attempt recovery if in an error state.
        print("TimerWatcher [\(id)]: checkNow() called. Current state: \(state), Countdown: \(currentCountdown)s")
        // TODO(lombard): Consider if checkNow() should start the timer if not running, or if it's only for active watchers.
    }

    func acknowledgeNudge(id: UUID) {
        print("TimerWatcher [\(id)]: Acknowledge Nudge ID: \(id) requested. Current nudges: \(nudges.count)")
        if let index = nudges.firstIndex(where: { $0.id == id }) {
            let removedNudge = nudges.remove(at: index)
            print("TimerWatcher [\(id)]: Nudge '\(removedNudge.title)' (ID: \(id)) acknowledged and removed.")
            if nudges.isEmpty { // All nudges for this timer are cleared
                print("TimerWatcher [\(id)]: All nudges cleared. Restarting timer via start().")
                start() // Restart the countdown loop (will go through .runningChecking -> .idleClear)
            } else {
                 print("TimerWatcher [\(id)]: \(nudges.count) nudges remaining.")
            }
        } else {
            print("TimerWatcher [\(id)]: Nudge ID \(id) not found for acknowledgment.")
        }
    }
    
    func acknowledgeAllNudges() {
        print("TimerWatcher [\(id)]: Acknowledge All Nudges requested. Current nudges: \(nudges.count)")
        guard !nudges.isEmpty else {
            print("TimerWatcher [\(id)]: No nudges to acknowledge.")
            return
        }
        nudges.removeAll()
        print("TimerWatcher [\(id)]: All nudges acknowledged and removed. Restarting timer via start().")
        start() // Restart the countdown loop (will go through .runningChecking -> .idleClear)
    }

    // MARK: - Timer Logic
    private func startCountdownTimer() {
        timer?.invalidate()
        
        guard state == .idleClear else { 
            print("TimerWatcher [\(id)]: startCountdownTimer called but state is not .idleClear (it's \(state)). Aborting countdown timer creation.")
            return
        }

        print("TimerWatcher [\(id)]: Internal countdown timer actually starting for \(currentCountdown) seconds (from state .idleClear).")
        timer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if self.currentCountdown > 0 {
                self.currentCountdown -= 1
            } else {
                self.timer?.invalidate()
                self.timer = nil
                self.state = .nudgeAlert
                let newNudge = Nudge(title: "Timer Finished!", 
                                     originatingWatcherName: self.name,
                                     action: { 
                                        print("TimerWatcher [\(self.id)]: Nudge action (auto-acknowledge) triggered.")
                                        self.acknowledgeAllNudges() 
                                     }
                )
                self.nudges = [newNudge] // Replace with new nudge
                print("TimerWatcher [\(id)]: Countdown finished. State changed to .nudgeAlert. Nudge created: '\(newNudge.title)'")
            }
        }
    }
    
    deinit {
        print("TimerWatcher [\(id)]: Deinitialized.")
        timer?.invalidate()
    }
} 