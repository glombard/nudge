import Foundation

class ConfigLoader {
    enum ConfigError: Error {
        case fileNotFound
        case directoryNotFound
        case cannotReadData
        case decodingError(Error)
    }

    static let defaultConfigDirectoryPath = "~/.config/nudge"
    static let defaultConfigFileName = "config.json"

    func loadAppConfig(from path: String = "\(defaultConfigDirectoryPath)/\(defaultConfigFileName)") -> Result<AppConfig, ConfigError> {
        let expandedPath = NSString(string: path).expandingTildeInPath
        
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            let dirPath = NSString(string: ConfigLoader.defaultConfigDirectoryPath).expandingTildeInPath
            if !FileManager.default.fileExists(atPath: dirPath) {
                return .failure(.directoryNotFound)
            }
            return .failure(.fileNotFound)
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: expandedPath)) else {
            return .failure(.cannotReadData)
        }

        let decoder = JSONDecoder()
        do {
            let appConfig = try decoder.decode(AppConfig.self, from: data)
            return .success(appConfig)
        } catch {
            return .failure(.decodingError(error))
        }
    }
    
    func ensureDefaultConfigExists() {
        let dirPath = NSString(string: ConfigLoader.defaultConfigDirectoryPath).expandingTildeInPath
        let filePath = "\(dirPath)/\(ConfigLoader.defaultConfigFileName)"

        if !FileManager.default.fileExists(atPath: filePath) {
            print("Config file not found at \(filePath). Creating a default one.")
            do {
                try FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: nil)
                
                let defaultTimerWatcher = WatcherConfig(
                    id: "default-timer",
                    name: "Default Timer",
                    type: "timer", 
                    enabled: true, 
                    token: nil, 
                    repo: nil, 
                    user: nil,
                    repositories: nil,
                    githubQuery: nil,
                    githubPATFromEnv: nil,
                    timerDurationSeconds: 600 // Default 10 minutes for timer
                )
                let defaultGithubWatcher = WatcherConfig(
                    id: "default-github",
                    name: "Default GitHub PRs",
                    type: "github", 
                    enabled: false, 
                    token: "YOUR_GITHUB_PAT_HERE", 
                    repo: "owner/repository", 
                    user: "your_github_username",
                    repositories: nil,
                    githubQuery: nil,
                    githubPATFromEnv: nil,
                    timerDurationSeconds: nil
                )
                let defaultConfig = AppConfig(watchIntervalSec: 60, watchers: [defaultTimerWatcher, defaultGithubWatcher])
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(defaultConfig)
                
                try jsonData.write(to: URL(fileURLWithPath: filePath))
                print("Default config.json created at \(filePath). Please review and edit it, especially the GitHub token and repository.")
            } catch {
                print("Error: Could not create default config directory or file: \(error.localizedDescription)")
            }
        }
    }
} 