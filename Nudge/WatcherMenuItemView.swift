import SwiftUI

// This view displays the menu items for a single watcher.
// It observes the watcher directly to ensure UI updates when the watcher's state changes.
struct WatcherMenuItemView<W: Watcher>: View {
    @ObservedObject var watcher: W

    var body: some View {
        Section(header: Text(watcher.name).font(.headline)) {
            if watcher.state == .stopped {
                Button("Start") {
                    print("NudgeApp [WatcherMenuItemView]: Start clicked for \(watcher.name) (ID: \(watcher.id))")
                    watcher.start()
                }
            } else {
                Button("Stop") {
                    print("NudgeApp [WatcherMenuItemView]: Stop clicked for \(watcher.name) (ID: \(watcher.id))")
                    watcher.stop()
                }
            }

            Button("Check Now") {
                print("NudgeApp [WatcherMenuItemView]: Check Now clicked for \(watcher.name) (ID: \(watcher.id))")
                watcher.checkNow()
            }
            .disabled(watcher.state == .stopped)

            // Only show Acknowledge options if in nudgeAlert state AND there are nudges
            if watcher.state == .nudgeAlert && !watcher.nudges.isEmpty {
                ForEach(watcher.nudges) { nudge in
                    Button("Acknowledge: \(nudge.title)") {
                        print("NudgeApp [WatcherMenuItemView]: Acknowledge '\(nudge.title)' clicked for \(watcher.name)")
                        nudge.action() // This action should be defined in the Nudge struct itself
                    }
                }
            }
        }
    }
} 