import SwiftUI

@main
struct NudgeApp: App {
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var watcherManager: WatcherManager

    init() {
        let viewModel = AppViewModel()
        _appViewModel = StateObject(wrappedValue: viewModel)
        _watcherManager = StateObject(wrappedValue: WatcherManager(appViewModel: viewModel))
    }

    var body: some Scene {
        MenuBarExtra {
            if watcherManager.watchers.isEmpty {
                Text("No active watchers configured.")
                    .disabled(true)
            } else {
                ForEach(watcherManager.watchers, id: \.id) { watcher in
                    // TODO(lombard): Make watcher type handling in menu more robust if more Watcher types are added.
                    if let timerWatcher = watcher as? TimerWatcher {
                        WatcherMenuItemView(watcher: timerWatcher)
                    } else if let githubWatcher = watcher as? GitHubWatcher {
                        WatcherMenuItemView(watcher: githubWatcher)
                    } else {
                        Text("Unsupported watcher type: \(watcher.name)").disabled(true)
                    }
                    Divider()
                }
            }
            
            Button("Settings...") {
                appViewModel.openSettings()
            }
            Button("About Nudge") {
                appViewModel.openAbout()
            }
            Divider()
            Button("Quit Nudge") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: appViewModel.currentSystemImageName)
                .symbolRenderingMode(.palette)
        }
    }
}
/*
struct NudgeApp_Previews: PreviewProvider {
    static var previews: some View {
        NudgeApp()
    }
} 
*/ 