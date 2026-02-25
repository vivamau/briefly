import SwiftUI
import SwiftData

@main
struct WhisperNotesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VoiceNote.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup(id: "mainWindow") {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
