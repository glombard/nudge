import Foundation
import Combine
import AppKit // For NSWorkspace

class GitHubWatcher: Watcher {
    let id = UUID()
    var name: String = "GitHub PRs" // Default name, can be overridden by config
    @Published var state: WatcherState = .stopped
    @Published var lastErrorMessage: String?
    @Published var nudges: [Nudge] = []

    private var internalConfig: InternalWatcherConfig
    private var githubService: GitHubService?

    // Combine publishers for Watcher protocol
    var anyObjectWillChange: AnyPublisher<Void, Never> {
        objectWillChange.eraseToAnyPublisher()
    }
    var statePublisher: AnyPublisher<WatcherState, Never> {
        $state.eraseToAnyPublisher()
    }
    var nudgesPublisher: AnyPublisher<[Nudge], Never> {
        $nudges.eraseToAnyPublisher()
    }
    var lastErrorMessagePublisher: AnyPublisher<String?, Never> {
        $lastErrorMessage.eraseToAnyPublisher()
    }


    init(config: InternalWatcherConfig) {
        self.internalConfig = config
        if let configName = config.name, !configName.isEmpty {
            self.name = configName
        }

        // Initialize GitHubService
        if let token = internalConfig.githubToken, !token.isEmpty {
            self.githubService = GitHubService(
                pat: token,
                username: internalConfig.githubUser,
                repositories: internalConfig.githubRepositories,
                customQuery: internalConfig.githubCustomQuery
            )
            print("GitHubWatcher [\(self.name)] initialized with GitHubService.")
        } else {
            self.githubService = nil
            let errorMessage = "GitHub Personal Access Token (PAT) is missing or empty in the configuration for watcher: \(self.name)."
            print("GitHubWatcher [\(self.name)] Error: \(errorMessage)")
            // Set state and error message directly here, as start() might not be called if WatcherManager filters disabled/errored watchers.
            self.state = .error
            self.lastErrorMessage = errorMessage
        }
    }

    func start() {
        print("GitHubWatcher [\(name)]: Start called")
        guard self.githubService != nil else {
            print("GitHubWatcher [\(name)]: Cannot start, GitHubService not initialized (likely PAT missing). State is \(self.state)")
            // Ensure state is .error if it wasn't set during init (e.g. if start is called manually)
            if self.state != .error {
                 self.state = .error
                 self.lastErrorMessage = "Cannot start: GitHubService not initialized (PAT missing)."
            }
            return
        }
        
        // Clear any previous error messages on a fresh start
        self.lastErrorMessage = nil
        // Nudges are cleared here to ensure a clean state upon starting the watcher.
        // If checkNow finds new nudges, it will populate them.
        // If checkNow results in .idleClear, nudges will remain empty.
        self.nudges.removeAll()

        // Transition to runningChecking and then immediately perform a check.
        // The checkNow() method will handle subsequent state transitions based on API results.
        self.state = .runningChecking // Set state before calling checkNow
        checkNow()
    }

    func stop() {
        print("GitHubWatcher [\(name)]: Stop called")
        self.state = .stopped
        self.nudges.removeAll()
        self.lastErrorMessage = nil
    }

    func checkNow() {
        print("GitHubWatcher [\(name)]: Check Now called")
        
        guard internalConfig.isEnabled else {
            print("GitHubWatcher [\(name)]: Check Now skipped, watcher is disabled.")
            // If it was somehow told to check while disabled, ensure it's in a stopped state.
            if self.state != .stopped {
                self.state = .stopped
            }
            return
        }

        guard let service = self.githubService else {
            print("GitHubWatcher [\(name)]: GitHubService not available. Cannot perform check.")
            self.state = .error
            self.lastErrorMessage = "GitHubService not available (Configuration error, PAT likely missing)."
            self.nudges.removeAll()
            return
        }

        self.state = .runningChecking

        service.fetchReviewRequests { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async { // Ensure UI updates are on the main thread
                switch result {
                case .success(let prInfos):
                    self.lastErrorMessage = nil
                    if prInfos.isEmpty {
                        print("GitHubWatcher [\(self.name)]: Check complete, no PRs found requiring review.")
                        self.nudges.removeAll()
                        self.state = .idleClear
                    } else {
                        print("GitHubWatcher [\(self.name)]: Check complete, found \(prInfos.count) PRs requiring review.")
                        self.nudges = prInfos.map { prInfo in
                            Nudge(
                                title: prInfo.title,
                                originatingWatcherName: self.name,
                                action: {
                                    if let url = URL(string: prInfo.html_url) {
                                        NSWorkspace.shared.open(url)
                                    } else {
                                        print("Error: Could not create URL from string: \(prInfo.html_url)")
                                        // TODO(lombard): Consider setting an error state or creating a non-actionable nudge if URL creation from prInfo.html_url fails.
                                    }
                                }
                            )
                        }
                        self.state = .nudgeAlert
                    }
                case .failure(let error):
                    print("GitHubWatcher [\(self.name)]: Check failed with error: \(error.localizedDescription)")
                    self.nudges.removeAll() // Clear nudges on error
                    self.state = .error
                    // Map GitHubServiceError to a user-friendly message.
                    switch error {
                    case .patMissing:
                        self.lastErrorMessage = "Error: GitHub Personal Access Token is missing."
                    case .invalidURL, .queryConstructionError:
                        self.lastErrorMessage = "Error: Failed to construct GitHub API request (URL/Query)."
                    case .requestFailed(let underlyingError):
                        self.lastErrorMessage = "Error: GitHub API request failed: \(underlyingError.localizedDescription)"
                    case .decodingError(let underlyingError):
                        self.lastErrorMessage = "Error: Failed to parse GitHub API response: \(underlyingError.localizedDescription)"
                    case .unexpectedResponse:
                        self.lastErrorMessage = "Error: Received an unexpected response from GitHub API."
                    }
                }
            }
        }
    }

    func acknowledgeNudge(id: UUID) {
        print("GitHubWatcher [\(name)]: Acknowledge Nudge \(id) called")
        self.nudges.removeAll { $0.id == id }
        if nudges.isEmpty && state == .nudgeAlert {
            self.state = .idleClear
        }
    }

    func acknowledgeAllNudges() {
        print("GitHubWatcher [\(name)]: Acknowledge All Nudges called")
        self.nudges.removeAll()
        if state == .nudgeAlert {
            self.state = .idleClear
        }
    }
} 