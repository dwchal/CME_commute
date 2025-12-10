import SwiftUI

@main
struct CME_commuterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        CarPlayScene(delegate: CarPlaySceneDelegate())
    }
}
