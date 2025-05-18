import Foundation

// TODO(lombard): Split out watcher-specific config

// Represents the configuration for a single watcher, directly matching JSON structure
struct WatcherConfig: Codable {
    let id: String? // Optional unique ID for a watcher instance
    let name: String? // Optional display name for the watcher instance
    let type: String
    let enabled: Bool
    
    // GitHub-specific settings (optional)
    let token: String?
    let repo: String? // e.g., "owner/repo"
    let user: String? // GitHub username for assignments/mentions
    let repositories: [String]? // Optional: list of repo names "owner/repo"
    let githubQuery: String? // Optional: allow advanced GitHub search query
    let githubPATFromEnv: String? // Optional: for PAT from environment variable.

    // Timer-specific settings (optional)
    let timerDurationSeconds: Int?
}

// Top-level structure matching the JSON root
struct AppConfig: Codable {
    let watchIntervalSec: Int
    let watchers: [WatcherConfig]
}

// --- Internal Representation ---

// Enum for known watcher types
enum WatcherType: String, Codable, CaseIterable {
    case timer
    case github
    case unknown // For types not recognized
}

// Internal model for a watcher's configuration
struct InternalWatcherConfig {
    let id: UUID // Unique ID for runtime use (e.g., lists, identification)
    let configID: String? // The original ID from the JSON config, if provided
    let name: String? // The original name from the JSON config, if provided
    let type: WatcherType
    var isEnabled: Bool // Mutable if we want to allow enabling/disabling at runtime
    
    // GitHub-specific parsed/validated data
    let githubToken: String?
    let githubUser: String?
    let githubRepositories: [String]? 
    let githubCustomQuery: String?
    // TODO(lombard): Handle githubPATFromEnv during GitHubService initialization or a dedicated loading step.

    // Timer-specific parsed/validated data
    let timerDuration: TimeInterval?

    // Initializer to convert from the decoded JSON structure
    init(from decodableConfig: WatcherConfig) {
        self.id = UUID() // Generate a runtime UUID
        self.configID = decodableConfig.id
        self.name = decodableConfig.name
        self.type = WatcherType(rawValue: decodableConfig.type) ?? .unknown
        self.isEnabled = decodableConfig.enabled
        
        self.githubToken = decodableConfig.token
        self.githubUser = decodableConfig.user
        self.githubRepositories = decodableConfig.repositories
        self.githubCustomQuery = decodableConfig.githubQuery
        
        if let duration = decodableConfig.timerDurationSeconds {
            self.timerDuration = TimeInterval(duration)
        } else {
            self.timerDuration = nil
        }
    }
} 