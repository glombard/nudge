# Nudge: macOS Menu Bar Event Notifier

Nudge is a lightweight macOS menu-bar application designed to keep you informed about events that require your attention. It lives in your menu bar, showing a status icon that reflects the overall state of its active *watchers*.

## Key Features

*   **GitHub Pull Request Monitoring**: Nudge can be configured to periodically check GitHub for pull requests awaiting your review. When new PRs are found, the menu bar icon changes, and you can quickly access the PRs directly from the Nudge menu.
*   **Timer Watcher**: Includes a simple timer function (like a Pomodoro timer) to send you timed reminders.
*   **Configurable Watchers**: The application loads its configuration from `~/.config/nudge/config.json`, allowing you to define and enable different watchers (e.g., multiple GitHub repositories or timers).
*   **Dynamic Menu**: The menu bar provides controls for each active watcher, allowing you to start, stop, manually check, and acknowledge alerts.
*   **SwiftUI Native**: Built with SwiftUI for a modern macOS experience.

## How It Works

Nudge uses a `WatcherManager` to oversee various "watchers". Each watcher is responsible for monitoring a specific service or event type:
*   `GitHubWatcher`: Connects to the GitHub API to fetch PRs based on your configuration (PAT, username, repositories, custom queries).
*   `TimerWatcher`: Provides timed nudges.

The `WatcherManager` periodically instructs active watchers to check for updates. If a watcher detects an event (e.g., a new PR for review, or a timer completing), it enters a `nudgeAlert` state, and the main application icon changes to notify you. You can then interact with the specific watcher through the Nudge menu to view details or acknowledge the alert.

For GitHub PRs, acknowledging a nudge typically opens the PR in your web browser. For timers, it resets the timer.

## Configuration

Nudge looks for a `config.json` file in `~/.config/nudge/`. If it doesn't exist, a default configuration file will be created with examples for a Timer and a GitHub watcher. You'll need to edit this file to add your GitHub Personal Access Token (PAT), username, and target repositories to enable GitHub PR monitoring.
