import Foundation
import Combine
import SwiftUI // For @ObservedObject if AppViewModel is passed, or for Color, etc.

class WatcherManager: ObservableObject {
    @ObservedObject var appViewModel: AppViewModel // To update the global app icon
    private var configLoader = ConfigLoader()
    private var appConfig: AppConfig? // Loaded from config.json
    private var internalWatcherConfigs: [InternalWatcherConfig] = []

    @Published var watchers: [any Watcher] = []
    @Published var overallState: WatcherState = .stopped {
        didSet {
            if oldValue != overallState {
                DispatchQueue.main.async {
                    self.appViewModel.currentSystemImageName = self.overallState.systemImageName
                }
            }
        }
    }

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        loadConfiguration()
        // Note: Watcher instantiation will happen after config is loaded,
        // and possibly after specific watcher types are defined.
        // For now, this init sets up the basics.
        // self.setupWatchers()
        // self.startPeriodicChecks()
        
        if appConfig == nil {
            configLoader.ensureDefaultConfigExists() 
            // TODO(lombard): Consider trying to loadConfiguration() again immediately if ensureDefaultConfigExists created one.
            print("WatcherManager: Config not loaded. A default config may have been created at ~/.config/nudge/config.json. Please review it and restart the app.")
        }
    }

    private func loadConfiguration() {
        let result = configLoader.loadAppConfig()
        switch result {
        case .success(let loadedConfig):
            self.appConfig = loadedConfig
            self.internalWatcherConfigs = loadedConfig.watchers.map { InternalWatcherConfig(from: $0) }
            print("WatcherManager: Configuration loaded successfully. Watch interval: \(loadedConfig.watchIntervalSec)s. \(loadedConfig.watchers.count) watchers configured.")
            // Proceed to setup watchers based on this config
            self.setupWatchers()
            self.startPeriodicChecks()
        case .failure(let error):
            self.appConfig = nil
            self.internalWatcherConfigs = []
            print("WatcherManager: Failed to load configuration: \(error).")
            self.overallState = .error // Indicate a problem with loading config
            // TODO(lombard): Create a Nudge to inform about the config error.
        }
    }

    // Placeholder for now - will be implemented once we have concrete Watcher types
    private func setupWatchers() {
        // guard let config = appConfig else { return } // config is not used directly, internalWatcherConfigs implies appConfig was loaded.
        guard appConfig != nil else {
            print("WatcherManager: setupWatchers called before configuration was loaded. Skipping.")
            return
        }

        self.watchers.removeAll()
        cancellables.removeAll() // Clear old subscriptions

        for internalConfig in internalWatcherConfigs where internalConfig.isEnabled {
            var watcherToAdd: (any Watcher)? // Changed to var temporarily as it IS mutated now
            switch internalConfig.type {
            case .timer:
                print("WatcherManager: Creating TimerWatcher for config ID \(internalConfig.id)")
                watcherToAdd = TimerWatcher(config: internalConfig)
            case .github:
                print("WatcherManager: Creating GitHubWatcher for config ID \(internalConfig.id)")
                watcherToAdd = GitHubWatcher(config: internalConfig)
            case .unknown:
                 print("WatcherManager: Unknown watcher type: \(internalConfig.type.rawValue) for config ID \(internalConfig.id). Skipping.")
            }

            if let newWatcher = watcherToAdd {
                self.watchers.append(newWatcher)
                // Observe only the watcher's state for updating overallState
                newWatcher.statePublisher // Use the new protocol requirement
                    .sink { [weak self, weak newWatcher] newState in 
                        guard let self = self, let changedWatcher = newWatcher else { return }
                        let watcherName = changedWatcher.name // Capture name before dispatch
                        print("WatcherManager: Watcher '\(watcherName)' reported new state: \(newState).")
                        // Dispatch the overall state update to the main queue to ensure it runs 
                        // after the current cycle of state propagation has settled.
                        DispatchQueue.main.async {
                            // Signal that WatcherManager itself has changed.
                            self.objectWillChange.send()
                            // Force SwiftUI to see the watchers array as changed, to help update ForEach.
                            self.watchers = self.watchers
                            self.updateOverallState()
                        }
                    }
                    .store(in: &cancellables)
                
                // TODO(lombard): Consider if WatcherManager needs to react to nudge list changes directly (e.g., to maintain an aggregate list of all nudges).
            }
        }
        updateOverallState() // Initial state update after setting up all watchers
        print("WatcherManager: \(self.watchers.count) active watchers initialized.")

        // Ensure all configured and enabled watchers are started as per requirements.
        startAllWatchers()
    }

    func startAllWatchers() {
        print("WatcherManager: Starting all watchers.")
        watchers.forEach { $0.start() }
        updateOverallState()
    }

    func stopAllWatchers() {
        print("WatcherManager: Stopping all watchers.")
        watchers.forEach { $0.stop() }
        updateOverallState()
    }

    func checkAllWatchersNow() {
        print("WatcherManager: Forcing check on all watchers.")
        watchers.forEach { $0.checkNow() }
        // State update will happen via Combine when watchers publish changes
    }

    private func startPeriodicChecks() {
        guard let interval = appConfig?.watchIntervalSec, interval > 0 else {
            print("WatcherManager: Watch interval not configured or invalid. Periodic checks disabled.")
            return
        }
        print("WatcherManager: Starting periodic checks every \(interval) seconds.")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval),
                                     repeats: true) { [weak self] _ in
            print("WatcherManager: Periodic check triggered.")
            self?.checkAllWatchersNow()
        }
    }

    private func updateOverallState() {
        let watcherStates = watchers.map { "(\($0.name): \($0.state))" }.joined(separator: ", ")
        print("WatcherManager [updateOverallState]: Evaluating states: [\(watcherStates)]")

        let oldOverallState = self.overallState

        if watchers.contains(where: { $0.state == .error }) {
            overallState = .error
        } else if watchers.contains(where: { $0.state == .nudgeAlert }) {
            overallState = .nudgeAlert
        } else if watchers.contains(where: { $0.state == .runningChecking }) {
            overallState = .runningChecking
        } else if watchers.contains(where: { $0.state == .idleClear }) {
            overallState = .idleClear
        } else if !watchers.isEmpty { 
            overallState = .stopped
        } else { 
            overallState = .stopped 
        }
        
        if oldOverallState != overallState {
            print("WatcherManager [updateOverallState]: Overall state CHANGED from \(oldOverallState) to \(overallState) -> Icon: \(overallState.systemImageName)")
        } else {
            print("WatcherManager [updateOverallState]: Overall state REMAINS \(overallState)")
        }
    }
    
    deinit {
        timer?.invalidate()
    }
} 
