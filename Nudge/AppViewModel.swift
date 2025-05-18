import SwiftUI

class AppViewModel: ObservableObject {
    @Published var currentSystemImageName: String = "stop.circle"

    // Placeholder for future settings
    func openSettings() {
        print("Settings menu item clicked")
        // TODO(lombard): Open using SwiftUI's Settings scene
    }

    // Placeholder for future about information
    func openAbout() {
        print("About menu item clicked")
        // TODO(lombard): Configure Info.plist
        // TODO(lombard): Open a custom About window or use the standard macOS about panel?
        // NSApplication.shared.orderFrontStandardAboutPanel(options: [:])
    }
}
