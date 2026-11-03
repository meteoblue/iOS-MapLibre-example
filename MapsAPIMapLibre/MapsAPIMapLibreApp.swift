import SwiftUI

@main
struct MapsAPIMapLibreApp: App {
    var body: some Scene {
        WindowGroup {
            MapView()
                .ignoresSafeArea()
        }
    }
}
