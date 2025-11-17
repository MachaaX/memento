import SwiftUI

@main
struct MementoApp: App {
    // Simple login flag stored persistently
    @AppStorage("isLoggedIn") private var isLoggedIn = false

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                HomeView()          // root is home
            } else {
                AuthLandingView()   // signin / signup / Google buttons
            }
        }
    }
}
